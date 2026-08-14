import 'package:flutter/material.dart';

/// Ẩn bàn phím (iOS multiline không có nút Done).
void dismissAppKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
}

/// Dùng cho `TextField.onTapOutside`.
void dismissKeyboardOnTapOutside(PointerDownEvent _) => dismissAppKeyboard();
