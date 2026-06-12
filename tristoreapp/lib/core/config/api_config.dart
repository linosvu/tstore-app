/// Base URL API TStore.
///
/// Mặc định: backend production.
/// Ghi đè khi dev local: `flutter run --dart-define=API_BASE_URL=http://...`
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://bk.blwsmartware.net',
  );
}
