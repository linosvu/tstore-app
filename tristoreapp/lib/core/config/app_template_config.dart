/// Central template / white-label hooks for the next system (API, tenant, branding).
class AppTemplateConfig {
  AppTemplateConfig._();

  /// Shown in [MaterialApp.title], splash, and where a short app label is needed.
  static const String appDisplayName = 'TStore';

  /// Semantic version of this template build (bump when shipping new template).
  static const String templateVersion = '1.0.0';

  /// Base URL for future REST/GraphQL; empty until backend is wired.
  /// Đồng bộ với [ApiConfig.baseUrl] (dart-define `API_BASE_URL`).
  static const String apiBaseUrl = '';

  /// Tenant / org label for UI placeholders (e.g. profile card).
  static const String organizationLabel = '';
}
