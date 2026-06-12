import 'dart:async';

import 'package:flutter/material.dart';

/// Thông báo toast — hiển thị từ phía trên màn hình (rơi xuống).
///
/// Giữ API tương thích với code cũ (`showSnackBar(context, SnackBar(...))`)
/// nhưng KHÔNG dùng `ScaffoldMessenger` (vốn neo cố định xuống đáy). Thay vào
/// đó dùng `Overlay` để đặt toast ngay dưới status bar.
abstract final class AppMessenger {
  static OverlayEntry? _current;
  static Timer? _dismissTimer;
  static _ToastControllerState? _controller;

  /// Tiện ích cho message dạng chuỗi đơn giản.
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
  }) {
    showSnackBar(
      context,
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: backgroundColor,
      ),
    );
  }

  /// Hiển thị 1 [SnackBar] dưới dạng overlay-top. Chỉ dùng các field thường
  /// gặp (`content`, `backgroundColor`, `duration`, `action`); các tùy chọn
  /// còn lại của SnackBar bị bỏ qua.
  static void showSnackBar(BuildContext context, SnackBar snackBar) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final duration = snackBar.duration;
    final bg = snackBar.backgroundColor;
    final action = snackBar.action;
    final content = snackBar.content;

    // Đang có toast: thay nội dung mới, reset timer (mượt hơn dismiss + insert).
    if (_current != null && _controller != null && _controller!.mounted) {
      _controller!.replace(
        content: content,
        backgroundColor: bg,
        action: action,
      );
      _dismissTimer?.cancel();
      _dismissTimer = Timer(duration, _dismissCurrent);
      return;
    }

    _dismissCurrent();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TopToast(
        key: const ValueKey('app-messenger-toast'),
        content: content,
        backgroundColor: bg,
        action: action,
        onRegister: (state) => _controller = state,
        onDismiss: () {
          if (_current == entry) _dismissCurrent();
        },
      ),
    );

    _current = entry;
    overlay.insert(entry);
    _dismissTimer = Timer(duration, _dismissCurrent);
  }

  static void _dismissCurrent() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    final controller = _controller;
    final entry = _current;
    _controller = null;
    _current = null;
    if (controller != null && controller.mounted) {
      // Chạy animation đóng rồi remove (dispose trong widget).
      controller.dismiss(() {
        if (entry != null && entry.mounted) entry.remove();
      });
    } else if (entry != null && entry.mounted) {
      entry.remove();
    }
  }
}

class _TopToast extends StatefulWidget {
  const _TopToast({
    super.key,
    required this.content,
    required this.onDismiss,
    required this.onRegister,
    this.backgroundColor,
    this.action,
  });

  final Widget content;
  final Color? backgroundColor;
  final SnackBarAction? action;
  final VoidCallback onDismiss;
  final ValueChanged<_ToastControllerState> onRegister;

  @override
  State<_TopToast> createState() => _ToastControllerState();
}

class _ToastControllerState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;
  Widget _content = const SizedBox.shrink();
  Color? _bg;
  SnackBarAction? _action;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _content = widget.content;
    _bg = widget.backgroundColor;
    _action = widget.action;
    widget.onRegister(this);
    _ctrl.forward();
  }

  void replace({
    required Widget content,
    Color? backgroundColor,
    SnackBarAction? action,
  }) {
    if (!mounted) return;
    setState(() {
      _content = content;
      _bg = backgroundColor;
      _action = action;
      _closing = false;
    });
    if (_ctrl.status != AnimationStatus.forward &&
        _ctrl.status != AnimationStatus.completed) {
      _ctrl.forward();
    }
  }

  Future<void> dismiss(VoidCallback onDone) async {
    if (_closing) return;
    _closing = true;
    try {
      if (mounted) await _ctrl.reverse();
    } catch (_) {
      // ignore animation interruption
    }
    if (!mounted) return;
    onDone();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snackTheme = theme.snackBarTheme;
    final bg = _bg ??
        snackTheme.backgroundColor ??
        const Color(0xFF1E293B);
    final textStyle = snackTheme.contentTextStyle ??
        const TextStyle(color: Colors.white, fontSize: 14);

    return Positioned(
      top: mq.padding.top + 8,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Material(
              color: Colors.transparent,
              child: Dismissible(
                key: const ValueKey('app-toast-dismissible'),
                direction: DismissDirection.up,
                onDismissed: (_) => widget.onDismiss(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onDismiss,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: DefaultTextStyle.merge(
                            style: textStyle,
                            child: _content,
                          ),
                        ),
                        if (_action != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              _action!.onPressed();
                              widget.onDismiss();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  _action!.textColor ?? scheme.inversePrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: const Size(40, 32),
                            ),
                            child: Text(_action!.label),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
