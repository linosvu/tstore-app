import 'package:flutter/material.dart';

import '../../core/constants/routes.dart';
import '../../core/navigation/deprecated_route_redirect.dart';

/// Deep link `/profile` → chuyển sang Cài đặt (hồ sơ đã gộp vào đó).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DeprecatedRouteRedirect(targetRoute: AppRoutes.settings);
  }
}
