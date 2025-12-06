import 'package:flutter/foundation.dart';
import '../models/daily_log.dart';
import '../models/schedule_config.dart';
import '../services/firebase_service.dart';
import '../services/api_service.dart';

class AutomationProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final ApiService _apiService = ApiService();

  DailyLog? _todayLog;
  ScheduleConfig? _scheduleConfig;
  List<DailyLog> _recentLogs = [];
  bool _isLoading = false;

  DailyLog? get todayLog => _todayLog;
  ScheduleConfig? get scheduleConfig => _scheduleConfig;
  List<DailyLog> get recentLogs => _recentLogs;
  bool get isLoading => _isLoading;

  Future<void> loadTodayLog() async {
    _isLoading = true;
    notifyListeners();

    try {
      _todayLog = await _firebaseService.getTodayLog();
    } catch (e) {
      debugPrint('Error loading today log: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadScheduleConfig() async {
    try {
      _scheduleConfig = await _firebaseService.getScheduleConfig();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading schedule config: $e');
    }
  }

  Future<void> loadRecentLogs({int days = 7}) async {
    try {
      _recentLogs = await _firebaseService.getDailyLogs(days: days);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading recent logs: $e');
    }
  }

  Future<void> refresh() async {
    await Future.wait([
      loadTodayLog(),
      loadScheduleConfig(),
      loadRecentLogs(),
    ]);
  }
}



