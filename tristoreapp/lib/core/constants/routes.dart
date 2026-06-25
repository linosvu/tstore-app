import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../navigation/deprecated_route_redirect.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/delivery/delivery_screen.dart';
import '../../screens/main_shell.dart';
import '../../screens/orders/orders_list_screen.dart';
import '../../screens/products/products_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/dev/design_system_gallery_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/settings/settings_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String products = '/products';

  /// @deprecated Use [delivery] (Order Fulfillment hub). Kept for deep links.
  static const String preparation = '/preparation';

  static const String orders = '/orders';
  static const String delivery = '/delivery';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String settings = '/settings';

  /// Debug-only design system gallery.
  static const String designSystemGallery = '/dev/design-system';

  static Map<String, WidgetBuilder> get routes {
    return {
      login: (context) => const LoginScreen(),
      home: (context) => const MainShell(),
      products: (context) => const ProductsScreen(),
      preparation: (context) => const DeprecatedRouteRedirect(
            targetRoute: delivery,
          ),
      orders: (context) => const OrdersListScreen(),
      delivery: (context) => const DeliveryScreen(),
      profile: (context) => const ProfileScreen(),
      notifications: (context) => const NotificationsScreen(),
      settings: (context) => const SettingsScreen(),
      if (kDebugMode)
        designSystemGallery: (context) => const DesignSystemGalleryScreen(),
    };
  }
}
