import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/schedule_config.dart';
import '../models/daily_log.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Initial date - logs before this date should be marked as PENDING
  static const String initialDate = '2025-11-20'; // November 20, 2025

  // Check if a date string (YYYY-MM-DD) is before the initial date
  bool _isBeforeInitialDate(String dateString) {
    return dateString.compareTo(initialDate) < 0;
  }

  FirebaseFirestore? _firestore;
  bool _isInitialized = false;

  FirebaseFirestore get firestore {
    if (!_isInitialized) {
      try {
        _firestore = FirebaseFirestore.instance;
        _isInitialized = true;
      } catch (e) {
        print('Firebase not initialized: $e');
        throw Exception('Firebase is not initialized. Please check your configuration.');
      }
    }
    return _firestore!;
  }

  bool get isInitialized {
    try {
      _firestore ??= FirebaseFirestore.instance;
      _isInitialized = true;
      return true;
    } catch (e) {
      print('Firebase check failed: $e');
      return false;
    }
  }

  // Schedule Config
  Future<ScheduleConfig?> getScheduleConfig() async {
    try {
      final doc = await firestore.collection('config').doc('schedule').get();
      if (doc.exists) {
        return ScheduleConfig.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting schedule config: $e');
      return null;
    }
  }

  Stream<ScheduleConfig?> watchScheduleConfig() {
    try {
      return firestore
          .collection('config')
          .doc('schedule')
          .snapshots()
          .map((snapshot) {
        if (snapshot.exists) {
          try {
            return ScheduleConfig.fromMap(snapshot.data()!);
          } catch (e) {
            print('Error parsing schedule config: $e');
            return null;
          }
        }
        return null;
      }).handleError((error) {
        print('Error in schedule config stream: $error');
      });
    } catch (e) {
      print('Error creating schedule config stream: $e');
      return Stream.value(null);
    }
  }

  Future<bool> updateScheduleConfig(ScheduleConfig config) async {
    try {
      final data = config.toMap();
      data['updatedAt'] = DateTime.now().toIso8601String();
      await firestore.collection('config').doc('schedule').set(data);
      return true;
    } catch (e) {
      print('Error updating schedule config: $e');
      return false;
    }
  }

  // General Config
  Future<Map<String, dynamic>?> getGeneralConfig() async {
    try {
      final doc = await firestore.collection('config').doc('general').get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting general config: $e');
      return null;
    }
  }

  Stream<Map<String, dynamic>?> watchGeneralConfig() {
    try {
      return firestore
          .collection('config')
          .doc('general')
          .snapshots()
          .map((snapshot) {
        if (snapshot.exists) {
          return snapshot.data();
        }
        return null;
      }).handleError((error) {
        print('Error in general config stream: $error');
      });
    } catch (e) {
      print('Error creating general config stream: $e');
      return Stream.value(null);
    }
  }

  Future<bool> updateGeneralConfig(Map<String, dynamic> config) async {
    try {
      final data = Map<String, dynamic>.from(config);
      data['updatedAt'] = DateTime.now().toIso8601String();
      await firestore.collection('config').doc('general').set(data);
      return true;
    } catch (e) {
      print('Error updating general config: $e');
      return false;
    }
  }

  // Location Config
  Future<Map<String, dynamic>?> getLocationConfig() async {
    try {
      final doc = await firestore.collection('config').doc('location').get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting location config: $e');
      return null;
    }
  }

  Stream<Map<String, dynamic>?> watchLocationConfig() {
    try {
      return firestore
          .collection('config')
          .doc('location')
          .snapshots()
          .map((snapshot) {
        if (snapshot.exists) {
          return snapshot.data();
        }
        return null;
      }).handleError((error) {
        print('Error in location config stream: $error');
      });
    } catch (e) {
      print('Error creating location config stream: $e');
      return Stream.value(null);
    }
  }

  Future<bool> updateLocationConfig(Map<String, dynamic> config) async {
    try {
      final data = Map<String, dynamic>.from(config);
      data['updatedAt'] = DateTime.now().toIso8601String();
      await firestore.collection('config').doc('location').set(data);
      return true;
    } catch (e) {
      print('Error updating location config: $e');
      return false;
    }
  }

  // Work Location Config
  Future<Map<String, dynamic>?> getWorkLocationConfig() async {
    try {
      final doc = await firestore.collection('config').doc('work_location').get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting work location config: $e');
      return null;
    }
  }

  Stream<Map<String, dynamic>?> watchWorkLocationConfig() {
    try {
      return firestore
          .collection('config')
          .doc('work_location')
          .snapshots()
          .map((snapshot) {
        if (snapshot.exists) {
          return snapshot.data();
        }
        return null;
      }).handleError((error) {
        print('Error in work location config stream: $error');
      });
    } catch (e) {
      print('Error creating work location config stream: $e');
      return Stream.value(null);
    }
  }

  Future<bool> updateWorkLocationConfig(Map<String, dynamic> config) async {
    try {
      final data = Map<String, dynamic>.from(config);
      data['updatedAt'] = DateTime.now().toIso8601String();
      await firestore.collection('config').doc('work_location').set(data);
      return true;
    } catch (e) {
      print('Error updating work location config: $e');
      return false;
    }
  }

  // Daily Logs
  Future<DailyLog?> getTodayLog() async {
    try {
      final today = _getTodayDateString();
      
      // Check if date is before initial date
      if (_isBeforeInitialDate(today)) {
        return DailyLog(
          date: today,
          status: LogStatus.pending,
          message: 'Data not available - date is before initial day (November 20, 2025)',
        );
      }
      
      final doc = await firestore.collection('daily_logs').doc(today).get();
      if (doc.exists) {
        return DailyLog.fromMap(today, doc.data());
      }
      return DailyLog(date: today, status: LogStatus.pending);
    } catch (e) {
      print('Error getting today log: $e');
      return null;
    }
  }

  Stream<DailyLog> watchTodayLog() {
    final today = _getTodayDateString();
    
    // Check if date is before initial date
    if (_isBeforeInitialDate(today)) {
      return Stream.value(DailyLog(
        date: today,
        status: LogStatus.pending,
        message: 'Data not available - date is before initial day (November 20, 2025)',
      ));
    }
    
    return firestore
        .collection('daily_logs')
        .doc(today)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return DailyLog.fromMap(today, snapshot.data());
      }
      return DailyLog(date: today, status: LogStatus.pending);
    });
  }

  Future<List<DailyLog>> getDailyLogs({int days = 7}) async {
    try {
      final logs = <DailyLog>[];
      final now = DateTime.now();

      for (int i = 0; i < days; i++) {
        final date = now.subtract(Duration(days: i));
        final dateString = _formatDate(date);
        
        // Check if date is before initial date
        if (_isBeforeInitialDate(dateString)) {
          logs.add(DailyLog(
            date: dateString,
            status: LogStatus.pending,
            message: 'Data not available - date is before initial day (November 20, 2025)',
          ));
          continue;
        }
        
        final doc = await firestore
            .collection('daily_logs')
            .doc(dateString)
            .get();

        if (doc.exists) {
          logs.add(DailyLog.fromMap(dateString, doc.data()));
        } else {
          logs.add(DailyLog(date: dateString, status: LogStatus.pending));
        }
      }

      return logs;
    } catch (e) {
      print('Error getting daily logs: $e');
      return [];
    }
  }

  Stream<List<DailyLog>> watchDailyLogs({int days = 30}) {
    try {
      final now = DateTime.now();
      final dates = List.generate(days, (i) {
        final date = now.subtract(Duration(days: i));
        return _formatDate(date);
      });

      // Firestore whereIn has a limit of 10, so we need to handle larger queries differently
      // For now, we'll listen to the entire collection and filter
      return firestore
          .collection('daily_logs')
          .snapshots()
          .map((snapshot) {
        try {
          final logs = <DailyLog>[];
          final existingDates = <String>{};

          // Process existing documents
          for (var doc in snapshot.docs) {
            if (dates.contains(doc.id)) {
              existingDates.add(doc.id);
              try {
                // Check if date is before initial date
                if (_isBeforeInitialDate(doc.id)) {
                  logs.add(DailyLog(
                    date: doc.id,
                    status: LogStatus.pending,
                    message: 'Data not available - date is before initial day (November 20, 2025)',
                  ));
                } else {
                  logs.add(DailyLog.fromMap(doc.id, doc.data()));
                }
              } catch (e) {
                print('Error parsing log ${doc.id}: $e');
              }
            }
          }

          // Add missing dates as pending
          for (var date in dates) {
            if (!existingDates.contains(date)) {
              // Check if date is before initial date
              if (_isBeforeInitialDate(date)) {
                logs.add(DailyLog(
                  date: date,
                  status: LogStatus.pending,
                  message: 'Data not available - date is before initial day (November 20, 2025)',
                ));
              } else {
                logs.add(DailyLog(date: date, status: LogStatus.pending));
              }
            }
          }

          // Sort by date descending
          logs.sort((a, b) => b.date.compareTo(a.date));
          return logs;
        } catch (e) {
          print('Error processing daily logs: $e');
          return <DailyLog>[];
        }
      }).handleError((error) {
        print('Error in daily logs stream: $error');
      });
    } catch (e) {
      print('Error creating daily logs stream: $e');
      return Stream.value(<DailyLog>[]);
    }
  }

  Future<bool> updateTodayStatus(LogStatus status, {String? swipeTime}) async {
    try {
      final today = _getTodayDateString();
      final data = {
        'status': status.name.toUpperCase(),
        'timestamp': DateTime.now().toIso8601String(),
        if (swipeTime != null) 'swipeTime': swipeTime,
      };

      await firestore.collection('daily_logs').doc(today).set(
        data,
        SetOptions(merge: true),
      );
      return true;
    } catch (e) {
      print('Error updating today status: $e');
      return false;
    }
  }

  String _getTodayDateString() {
    return _formatDate(DateTime.now());
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

