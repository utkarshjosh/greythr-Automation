import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/api_response.dart';
import '../models/daily_log.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<ApiResponse<Map<String, dynamic>>> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.healthEndpoint),
        headers: AppConfig.getApiHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(data);
      } else {
        return ApiResponse.error('Health check failed: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  Future<ApiResponse<DailyLog>> getStatus() async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.statusEndpoint),
        headers: AppConfig.getApiHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final date = data['date'] as String? ?? _getTodayDateString();
        final logData = data['data'] as Map<String, dynamic>?;
        final log = DailyLog.fromMap(date, logData);
        return ApiResponse.success(log, message: data['message'] as String?);
      } else {
        return ApiResponse.error('Failed to get status: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getConfig() async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.configEndpoint),
        headers: AppConfig.getApiHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(data);
      } else {
        return ApiResponse.error('Failed to get config: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> triggerAutomation({
    bool force = false,
  }) async {
    try {
      final url = AppConfig.buildTriggerUrl(force: force);
      final headers = Map<String, String>.from(AppConfig.getApiHeaders());
      if (force) {
        headers['x-force'] = 'true';
      }

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode({
          if (AppConfig.apiToken.isNotEmpty) 'token': AppConfig.apiToken,
          'force': force,
        }),
      ).timeout(const Duration(seconds: 60)); // Longer timeout for automation

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(data, message: data['message'] as String?);
      } else if (response.statusCode == 403) {
        return ApiResponse.error('Authentication failed: Invalid token');
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>?;
        final errorMsg = errorData?['error'] as String? ?? 'Failed to trigger automation';
        return ApiResponse.error('$errorMsg (${response.statusCode})');
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

