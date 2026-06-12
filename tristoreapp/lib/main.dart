import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/config/app_template_config.dart';
import 'core/constants/routes.dart';
import 'core/navigation/app_navigator.dart';
import 'core/services/api_client.dart';
import 'core/services/storage_service.dart';
import 'core/themes/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/delivery_provider.dart';
import 'providers/preparation_provider.dart';
import 'providers/repair_orders_provider.dart';
import 'providers/tasks_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await StorageService.instance.init();
  await StorageService.instance.remove('is_dark_mode');

  final api = ApiClient();
  final auth = AuthProvider(api: api);
  api.onUnauthorized = () {
    auth.logout();
    rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (_) => false,
    );
  };

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(MyApp(auth: auth));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.auth});

  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider(
          create: (ctx) => DeliveryProvider(api: ctx.read<AuthProvider>().api),
        ),
        ChangeNotifierProvider(
          create: (ctx) => PreparationProvider(api: ctx.read<AuthProvider>().api),
        ),
        ChangeNotifierProvider(
          create: (ctx) => RepairOrdersProvider(api: ctx.read<AuthProvider>().api),
        ),
        ChangeNotifierProvider(
          create: (ctx) => TasksProvider(api: ctx.read<AuthProvider>().api),
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
        home: const SplashScreen(),
        routes: AppRoutes.routes,
      ),
    );
  }
}
