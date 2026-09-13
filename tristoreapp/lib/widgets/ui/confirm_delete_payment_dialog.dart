import 'package:flutter/material.dart';

/// Popup xác nhận xóa ghi nhận thanh toán (Có / Không).
Future<bool> confirmDeletePaymentRecord(BuildContext context) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: const Text('Xóa thanh toán'),
        content: const Text(
          'Bạn có muốn xóa thanh toán này không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Có'),
          ),
        ],
      );
    },
  );
  return go == true;
}
