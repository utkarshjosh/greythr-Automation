import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/api_service.dart';
import '../models/daily_log.dart';
import '../widgets/status_badge.dart';
import '../widgets/log_card.dart';
import '../theme/app_theme.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final ApiService _apiService = ApiService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: AppTheme.mediumAnimation,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: theme.colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Dashboard',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  setState(() {});
                },
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {});
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // Today's Status Card
                    FutureBuilder<DailyLog>(
                      future: _fetchTodayLog(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (snapshot.hasError) {
                          print('Error fetching today log: ${snapshot.error}');
                          final todayLog = DailyLog(
                            date: _getTodayDateString(),
                            status: LogStatus.pending,
                          );
                          return _buildTodayStatusCard(context, todayLog);
                        }
                        
                        final todayLog = snapshot.data ??
                            DailyLog(
                              date: _getTodayDateString(),
                              status: LogStatus.pending,
                            );

                        return _buildTodayStatusCard(context, todayLog);
                      },
                    ),
                    const SizedBox(height: 24),

                    // Stats Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Statistics',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<List<DailyLog>>(
                      stream: _firebaseService.watchDailyLogs(days: 7),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (snapshot.hasError) {
                          print('Error in daily logs stream: ${snapshot.error}');
                          return Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'Failed to load statistics',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          );
                        }

                        final logs = snapshot.data ?? [];
                        return _buildStatsCards(context, logs);
                      },
                    ),
                    const SizedBox(height: 32),

                    // Recent Activity Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Activity',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // Navigate to logs page
                              // Navigate to logs page - handled by parent navigation
                            },
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<DailyLog>>(
                      stream: _firebaseService.watchDailyLogs(days: 7),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (snapshot.hasError) {
                          print('Error in daily logs stream: ${snapshot.error}');
                          return Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'Failed to load recent activity',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          );
                        }

                        final logs = snapshot.data ?? [];
                        if (logs.isEmpty) {
                          return _buildEmptyState(context);
                        }

                        return Column(
                          children: logs.take(5).map((log) {
                            return LogCard(log: log);
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayStatusCard(BuildContext context, DailyLog todayLog) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(todayLog.status);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.15),
            statusColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Status",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      StatusBadge(status: todayLog.status),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getStatusIcon(todayLog.status),
                      color: statusColor,
                      size: 28,
                    ),
                  ),
                ],
              ),
              if (todayLog.message != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: statusColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          todayLog.message!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (todayLog.swipeTime != null || todayLog.timestamp != null) ...[
                const SizedBox(height: 24),
                Container(
                  height: 1,
                  color: theme.colorScheme.onSurface.withOpacity(0.1),
                ),
                const SizedBox(height: 20),
                if (todayLog.swipeTime != null)
                  _buildInfoRow(
                    context,
                    Icons.access_time_rounded,
                    'Swipe Time',
                    todayLog.swipeTime!,
                    statusColor,
                  ),
                if (todayLog.swipeTime != null && todayLog.timestamp != null)
                  const SizedBox(height: 16),
                if (todayLog.timestamp != null)
                  _buildInfoRow(
                    context,
                    Icons.schedule_rounded,
                    'Last Updated',
                    _formatTimestamp(todayLog.timestamp!),
                    statusColor,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards(BuildContext context, List<DailyLog> logs) {
    final doneCount = logs.where((l) => l.status == LogStatus.done).length;
    final pendingCount = logs.where((l) => l.status == LogStatus.pending).length;
    final errorCount = logs.where((l) => l.status == LogStatus.error).length;
    final skipCount = logs.where((l) => l.status == LogStatus.skip).length;
    final totalCount = logs.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Done',
                  doneCount.toString(),
                  totalCount > 0 ? (doneCount / totalCount * 100).toStringAsFixed(0) : '0',
                  AppTheme.statusDone,
                  Icons.check_circle_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Pending',
                  pendingCount.toString(),
                  totalCount > 0 ? (pendingCount / totalCount * 100).toStringAsFixed(0) : '0',
                  AppTheme.statusPending,
                  Icons.pending_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Errors',
                  errorCount.toString(),
                  totalCount > 0 ? (errorCount / totalCount * 100).toStringAsFixed(0) : '0',
                  AppTheme.statusError,
                  Icons.error_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Skipped',
                  skipCount.toString(),
                  totalCount > 0 ? (skipCount / totalCount * 100).toStringAsFixed(0) : '0',
                  AppTheme.statusSkip,
                  Icons.skip_next_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    String percentage,
    Color color,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: color.withOpacity(0.05),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No activity yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your automation logs will appear here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(LogStatus status) {
    switch (status) {
      case LogStatus.done:
        return AppTheme.statusDone;
      case LogStatus.pending:
        return AppTheme.statusPending;
      case LogStatus.error:
        return AppTheme.statusError;
      case LogStatus.skip:
        return AppTheme.statusSkip;
      case LogStatus.unknown:
        return AppTheme.statusUnknown;
    }
  }

  IconData _getStatusIcon(LogStatus status) {
    switch (status) {
      case LogStatus.done:
        return Icons.check_circle_rounded;
      case LogStatus.pending:
        return Icons.pending_rounded;
      case LogStatus.error:
        return Icons.error_rounded;
      case LogStatus.skip:
        return Icons.skip_next_rounded;
      case LogStatus.unknown:
        return Icons.help_outline_rounded;
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return timestamp;
    }
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<DailyLog> _fetchTodayLog() async {
    try {
      // Try API first
      final statusResponse = await _apiService.getStatus();
      if (statusResponse.success && statusResponse.data != null) {
        return statusResponse.data!;
      }
    } catch (e) {
      print('Error fetching from API: $e');
    }
    
    // Fallback to Firestore
    final firestoreLog = await _firebaseService.getTodayLog();
    return firestoreLog ?? DailyLog(
      date: _getTodayDateString(),
      status: LogStatus.pending,
    );
  }
}
