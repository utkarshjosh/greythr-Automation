import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Backend API base URL
  static String get baseUrl {
    return dotenv.env['API_BASE_URL'] ?? 'https://utkarshjoshi.com/.hidden-api';
  }

  // API Key for authentication
  static String get apiKey {
    return dotenv.env['HTTP_X_API_KEY'] ?? '';
  }

  // API Token for trigger endpoints
  static String get apiToken {
    return dotenv.env['X_TRIGGER_TOKEN'] ?? '';
  }

  // Geolocation configuration
  static double get latitude {
    return double.tryParse(dotenv.env['GEOLOCATION_LATITUDE'] ?? '28.5355') ??
        28.5355;
  }

  static double get longitude {
    return double.tryParse(dotenv.env['GEOLOCATION_LONGITUDE'] ?? '77.391') ??
        77.391;
  }

  static double get geolocationAccuracy {
    return double.tryParse(dotenv.env['GEOLOCATION_ACCURACY'] ?? '100') ?? 100;
  }

  static bool get geolocationEnabled {
    final value = dotenv.env['GEOLOCATION_ENABLED'] ?? 'true';
    return value.toLowerCase() == 'true';
  }

  // Firebase notification topic
  static const String notificationTopic = 'greyt-automation';

  // API endpoints
  static String get healthEndpoint => '$baseUrl/health';
  static String get statusEndpoint => '$baseUrl/status';
  static String get configEndpoint => '$baseUrl/config';
  static String get triggerEndpoint => '$baseUrl/trigger';

  // Helper to build trigger URL with query params
  static String buildTriggerUrl({bool force = false}) {
    final uri = Uri.parse(triggerEndpoint);
    return uri
        .replace(
          queryParameters: {
            if (apiToken.isNotEmpty) 'token': apiToken,
            if (force) 'force': 'true',
          },
        )
        .toString();
  }

  // Get headers for API requests
  static Map<String, String> getApiHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};

    // if (apiKey.isNotEmpty) {
    //   headers['http_x_api_key'] = apiKey;
    // }

    // if (apiToken.isNotEmpty) {
    //   headers['x-trigger-token'] = apiToken;
    // }

    return headers;
  }
}
