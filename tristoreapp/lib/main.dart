import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/config/app_template_config.dart';
import 'core/constants/routes.dart';
import 'core/navigation/app_navigator.dart';
import 'core/services/api_client.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/storage_service.dart';
import 'core/themes/app_theme.dart';
import 'core/utils/keyboard_utils.dart';
import 'providers/address_catalog_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/delivery_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/preparation_provider.dart';
import 'providers/service_requests_provider.dart';
import 'providers/tasks_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await StorageService.instance.init();
  await StorageService.instance.remove('is_dark_mode');

  // Firebase init — chỉ chạy khi Android/iOS đã có file cấu hình Firebase.
  try {
    await Firebase.initializeApp();
    await PushNotificationService.instance.init();
  } catch (e) {
    debugPrint('[Firebase] init skipped/failed: $e');
  }

  final api = ApiClient();
  final auth = AuthProvider(api: api);
  api.onUnauthorized = () {
    unawaited(_handleUnauthorized(auth));
  };

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(MyApp(auth: auth, api: api));
}

Future<void> _handleUnauthorized(AuthProvider auth) async {
  await auth.forceLocalLogout();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _navigateToLoginIfNeeded();
  });
}

void _navigateToLoginIfNeeded() {
  final nav = rootNavigatorKey.currentState;
  if (nav == null) return;
  final route = ModalRoute.of(nav.context);
  final name = route?.settings.name;
  if (name == AppRoutes.login) return;
  // Splash = một route duy nhất, chưa đặt tên — để SplashScreen tự điều hướng.
  // Màn chi tiết (push không tên) vẫn canPop → vẫn về login.
  if (!nav.canPop() &&
      (name == null || name == Navigator.defaultRouteName)) {
    return;
  }
  nav.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.auth, required this.api});

  final AuthProvider auth;
  final ApiClient api;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.instance.handleInitialMessage();
    });
    widget.auth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (widget.auth.isAuthenticated) {
      widget.api.resetUnauthorizedGuard();
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) {
        unawaited(ctx.read<AddressCatalogProvider>().ensureLoaded());
      }
      return;
    }
    if (widget.auth.status != AuthStatus.unauthenticated) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToLoginIfNeeded();
    });
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) {
        ctx.read<NotificationProvider>().syncFromNotificationCenter();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: widget.auth),
        ChangeNotifierProvider(
          create: (ctx) =>
              AddressCatalogProvider(api: ctx.read<AuthProvider>().api),
        ),
        ChangeNotifierProvider(
          create: (ctx) => DeliveryProvider(api: ctx.read<AuthProvider>().api),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              PreparationProvider(api: ctx.read<AuthProvider>().api),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              ServiceRequestsProvider(api: ctx.read<AuthProvider>().api),
        ),
        ChangeNotifierProvider(
          create: (ctx) => TasksProvider(api: ctx.read<AuthProvider>().api),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = NotificationProvider();
            final push = PushNotificationService.instance;
            push.onForegroundMessage = provider.addFromRemoteMessage;
            push.onNotificationOpened = provider.markReadFromRemoteMessage;
            push.onPayloadOpened = provider.markReadFromPayload;
            provider.load();
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        title: AppTemplateConfig.appDisplayName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          return GestureDetector(
            onTap: dismissAppKeyboard,
            behavior: HitTestBehavior.translucent,
            child: child,
          );
        },
        home: const SplashScreen(),
        routes: AppRoutes.routes,
      ),
    );
  }
}
