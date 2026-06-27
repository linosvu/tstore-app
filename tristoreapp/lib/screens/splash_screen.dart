import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/app_template_config.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/routes.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _backgroundController;
  late AnimationController _textController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoSlide;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  static const Color primaryColor = AppColors.primary;
  static const Color secondaryColor = AppColors.secondary;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeInOut),
      ),
    );

    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic));

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic));

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _backgroundController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _textController.forward();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 1400)),
      auth.tryRestore(),
    ]);

    if (!mounted) return;
    final next =
        auth.isAuthenticated ? AppRoutes.home : AppRoutes.login;
    Navigator.of(context).pushReplacementNamed(next);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _backgroundController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    const Color(0xFF0A1628),
                    primaryColor,
                    _backgroundController.value * 0.85,
                  )!,
                  Color.lerp(
                    const Color(0xFF0F2D6B),
                    secondaryColor,
                    _backgroundController.value * 0.9,
                  )!,
                  Color.lerp(
                    Colors.white,
                    const Color(0xFFF0F4FA),
                    _backgroundController.value,
                  )!,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _logoController,
                      builder: (context, child) {
                        return SlideTransition(
                          position: _logoSlide,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: FadeTransition(
                              opacity: _logoOpacity,
                              child: Container(
                                width: 112,
                                height: 112,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: AppColors.softShadow,
                                ),
                                child: const Icon(
                                  Icons.storefront_rounded,
                                  size: 56,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 36),
                    AnimatedBuilder(
                      animation: _textController,
                      builder: (context, child) {
                        return SlideTransition(
                          position: _textSlide,
                          child: FadeTransition(
                            opacity: _textOpacity,
                            child: Column(
                              children: [
                                Text(
                                  AppTemplateConfig.appDisplayName,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Cửa hàng điện máy',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Đang khởi tạo…',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
