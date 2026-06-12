import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/delivery_provider.dart';
import '../providers/preparation_provider.dart';
import '../widgets/navigation/primary_bottom_nav.dart';
import 'delivery/delivery_screen.dart';
import 'main_shell_tabs.dart';
import 'orders/orders_list_screen.dart';
import 'delivery/fulfillment_tab_launch_args.dart';
import 'orders/orders_tab_launch_args.dart';
import 'profile/profile_screen.dart';
import 'tristore/tristore_dashboard_screen.dart';

/// Holds the active primary tab. Shared via Provider so any descendant
/// (e.g. bottom nav, in-screen "home" button) can switch tabs without
/// tearing down the screen via [Navigator.pushReplacementNamed].
class MainShellController extends ChangeNotifier {
  /// See [MainShellTab].
  int _index = 0;
  int get index => _index;

  /// Consumed by [OrdersListScreen] on next build.
  OrdersTabLaunchArgs? pendingOrdersLaunch;

  /// Consumed by [OrderFulfillmentHubScreen] on next build.
  FulfillmentTabLaunchArgs? pendingFulfillmentLaunch;

  void setIndex(int value) {
    if (value == _index) return;
    _index = value;
    notifyListeners();
  }

  /// Navigate to Orders tab with optional filter applied.
  void launchOrdersTab({String? status, bool useListAll = true}) {
    pendingOrdersLaunch = OrdersTabLaunchArgs(
      status: status,
      useListAll: useListAll,
    );
    setIndex(MainShellTab.orders);
  }

  /// Navigate to Fulfillment/Delivery tab with optional filter applied.
  void launchFulfillmentTab({
    String? outcome,
    String? expectedDelivery,
    String? scope,
  }) {
    pendingFulfillmentLaunch = FulfillmentTabLaunchArgs(
      outcome: outcome,
      expectedDelivery: expectedDelivery,
      scope: scope,
    );
    setIndex(MainShellTab.delivery);
  }

  /// Convenience for screens that previously called `pushReplacementNamed('/home')`.
  void goHome() => setIndex(0);

  static MainShellController? maybeOf(BuildContext context, {bool listen = false}) {
    try {
      return Provider.of<MainShellController>(context, listen: listen);
    } catch (_) {
      return null;
    }
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final MainShellController _controller = MainShellController();

  /// Built lazily so opening Home doesn't pay the cost for every tab,
  /// then kept alive once instantiated.
  final List<Widget?> _pages = List<Widget?>.filled(MainShellTab.count, null);

  final List<Timer> _prewarmTimers = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTabChanged);
    // Sau khi Home đã vẽ xong: dựng dần các tab còn lại trên các frame khác nhau
    // để lần đầu user chuyển tab không phải trả hết chi phí trong một frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      const stagger = Duration(milliseconds: 120);
      for (var i = 1; i < MainShellTab.count; i++) {
        final idx = i;
        _prewarmTimers.add(
          Timer(stagger * idx, () {
            if (!mounted || _pages[idx] != null) return;
            setState(() => _buildPage(idx));
          }),
        );
      }
    });
  }

  void _onTabChanged() {
    if (!mounted) return;
    if (_controller.index == MainShellTab.delivery) {
      context.read<PreparationProvider>().refresh();
      context.read<DeliveryProvider>().refresh();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTabChanged);
    for (final t in _prewarmTimers) {
      t.cancel();
    }
    _prewarmTimers.clear();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildPage(int index) {
    return _pages[index] ??= switch (index) {
      MainShellTab.home => const TristoreDashboardScreen(),
      MainShellTab.orders => const OrdersListScreen(),
      MainShellTab.delivery => const DeliveryScreen(),
      MainShellTab.profile => const ProfileScreen(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MainShellController>.value(
      value: _controller,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final current = _controller.index;
          // Đảm bảo tab hiện tại và Home đã có widget trước khi vào IndexedStack.
          for (var i = 0; i < _pages.length; i++) {
            if (i == current || (i == 0 && _pages[0] == null)) {
              _buildPage(i);
            }
          }
          return Scaffold(
            body: IndexedStack(
              index: current,
              sizing: StackFit.expand,
              children: List.generate(_pages.length, (i) {
                final child = _pages[i] ?? const SizedBox.shrink();
                // Cô lập repaint giữa các tab; không đổi logic hiển thị.
                return RepaintBoundary(
                  child: child,
                );
              }),
            ),
            bottomNavigationBar: RepaintBoundary(
              child: PrimaryBottomNav(
                currentIndex: current,
              ),
            ),
          );
        },
      ),
    );
  }
}
