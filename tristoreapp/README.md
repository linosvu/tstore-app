# TStore (Flutter)

## API backend

Mặc định app luôn trỏ **production**:

`https://bk.blwsmartware.net`

Cấu hình tại `lib/core/config/api_config.dart`. Chỉ cần `--dart-define=API_BASE_URL=...` khi muốn trỏ backend khác (vd. dev local).

## Chạy app

```bash
cd MobileApp/tristoreapp
flutter pub get
flutter devices
flutter run
```

Chọn thiết bị cụ thể:

```bash
flutter run -d <device_id>
```

Android emulator / iOS simulator cũng dùng production mặc định.

## Build release

**APK:**

```bash
cd MobileApp/tristoreapp
flutter pub get
flutter build apk
```

File output: `build/app/outputs/flutter-apk/app-release.apk`

**iOS:**

```bash
flutter build ipa
```