import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../models/daily_log.dart';
import '../models/schedule_config.dart';
import '../widgets/status_badge.dart';
import '../widgets/loading_overlay.dart';
import '../theme/app_theme.dart';
import '../utils/cron_parser.dart';

class GreytHrPage extends StatefulWidget {
  const GreytHrPage({super.key});

  @override
  State<GreytHrPage> createState() => _GreytHrPageState();
}

class _GreytHrPageState extends State<GreytHrPage> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;
  String? _lastMessage;
  DailyLog? _todayLog;
  ScheduleConfig? _scheduleConfig;
  bool _isRefreshing = false;
  List<DailyLog> _oldLogs = [];
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: AppTheme.mediumAnimation,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      // Fetch today's log - try API first (like dashboard does), then Firebase
      DailyLog? todayLog;
      try {
        final statusResponse = await _apiService.getStatus();
        if (statusResponse.success && statusResponse.data != null) {
          todayLog = statusResponse.data!;
        }
      } catch (e) {
        print('Error fetching from API: $e');
      }
      
      // Fallback to Firestore if API fails or returns no data
      if (todayLog == null) {
        todayLog = await _firebaseService.getTodayLog();
      }
      
      // Ensure we have at least a pending status for today
      final today = _getTodayDateString();
      todayLog ??= DailyLog(
        date: today,
        status: LogStatus.pending,
      );
      
      // Fetch schedule config
      final firestoreConfig = await _firebaseService.getScheduleConfig();
      
      // Get schedule config from API for cron expression
      try {
        final configResponse = await _apiService.getConfig();
        if (configResponse.success && configResponse.data != null) {
          final configData = configResponse.data!;
          final schedule = configData['schedule'] as String?;
          if (schedule != null) {
            setState(() {
              _scheduleConfig = ScheduleConfig(
                cron: schedule,
                enabled: firestoreConfig?.enabled ?? true,
                description: firestoreConfig?.description ?? 'Scheduled automation',
              );
            });
          }
        }
      } catch (e) {
        print('Error fetching config from API: $e');
        // Use Firebase config if API fails
        if (firestoreConfig != null) {
          setState(() {
            _scheduleConfig = firestoreConfig;
          });
        }
      }
      
      // Fetch old logs (last 7 days excluding today)
      // Get logs from Firestore - only include logs that actually exist (not auto-generated pending)
      final allLogs = await _firebaseService.getDailyLogs(days: 8);
      // Filter out today and only keep logs that have actual data (not just pending status)
      // A log is considered "real" if it has a timestamp, swipeTime, or status other than pending
      final oldLogs = allLogs.where((log) {
        if (log.date == today) return false;
        // Only include logs that have actual data (timestamp, swipeTime, or non-pending status)
        return log.timestamp != null || 
               log.swipeTime != null || 
               log.status != LogStatus.pending;
      }).toList();
      oldLogs.sort((a, b) => b.date.compareTo(a.date)); // Sort by date descending
      
      setState(() {
        _todayLog = todayLog;
        _oldLogs = oldLogs;
      });
    } catch (e) {
      print('Error loading data: $e');
      // Ensure we have at least a pending status for today
      setState(() {
        _todayLog ??= DailyLog(
          date: _getTodayDateString(),
          status: LogStatus.pending,
        );
      });
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: _lastMessage ?? 'Processing...',
        child: CustomScrollView(
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
                  'GreytHR Automation',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              ),
              actions: [
                IconButton(
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  onPressed: _isRefreshing ? null : _loadData,
                  tooltip: 'Refresh',
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Current Status Card
                        _buildStatusCard(context),
                        const SizedBox(height: 24),

                        // Schedule Information
                        if (_scheduleConfig != null && _scheduleConfig!.enabled)
                          _buildScheduleInfoCard(context),
                        if (_scheduleConfig != null && _scheduleConfig!.enabled)
                          const SizedBox(height: 24),

                        // Action Buttons Section
                        Text(
                          'Actions',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildActionButton(
                          context,
                          icon: Icons.play_arrow_rounded,
                          label: 'Trigger Swipe-In',
                          description: 'Run automation now',
                          color: AppTheme.primaryColor,
                          onPressed: _isLoading ? null : () => _triggerAutomation(false),
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          context,
                          icon: Icons.skip_next_rounded,
                          label: 'Skip Today',
                          description: 'Mark today as skipped',
                          color: AppTheme.statusSkip,
                          onPressed: _isLoading ? null : _skipToday,
                          isLoading: _isLoading,
                          outlined: true,
                        ),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          context,
                          icon: Icons.refresh_rounded,
                          label: 'Force Trigger',
                          description: 'Force run even if already done',
                          color: AppTheme.warningColor,
                          onPressed: _isLoading ? null : () => _triggerAutomation(true),
                          isLoading: _isLoading,
                          outlined: true,
                        ),
                        const SizedBox(height: 32),

                        // Today's Details
                        Text(
                          "Today's Details",
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailsCard(context),
                        const SizedBox(height: 32),
                        
                        // Old Logs Section
                        Text(
                          'Recent Logs',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildOldLogsCard(context),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final theme = Theme.of(context);
    final todayLog = _todayLog ??
        DailyLog(
          date: _getTodayDateString(),
          status: LogStatus.pending,
        );
    final statusColor = _getStatusColor(todayLog.status);
    final isDone = todayLog.status == LogStatus.done;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.2),
            statusColor.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.15),
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
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getStatusIcon(todayLog.status),
                  color: statusColor,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isDone ? "Today's Auto-Login Done ✓" : 'Current Status',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              StatusBadge(status: todayLog.status),
              if (isDone && todayLog.swipeTime != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.successColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Swiped at ${todayLog.swipeTime}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_lastMessage != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _lastMessage!,
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    final config = _scheduleConfig!;
    final nextTime = CronParser.getNextScheduledTime(config.cron);
    final minutesUntil = CronParser.getMinutesUntilNext(config.cron);
    final isUpcoming = minutesUntil != null && minutesUntil > 0 && minutesUntil < 1440; // Less than 24 hours
    final minutesUntilValue = minutesUntil;

    if (nextTime == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withOpacity(0.1),
              AppTheme.primaryColor.withOpacity(0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next Auto-Login',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        config.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CronParser.formatNextScheduledTime(config.cron),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (isUpcoming && minutesUntilValue != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer_rounded,
                            size: 18,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimeUntilNext(minutesUntilValue),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback? onPressed,
    required bool isLoading,
    bool outlined = false,
  }) {
    final theme = Theme.of(context);

    Widget buttonContent = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: outlined ? Colors.transparent : color,
        border: outlined ? Border.all(color: color, width: 2) : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: outlined
                  ? color.withOpacity(0.15)
                  : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        outlined ? color : Colors.white,
                      ),
                    ),
                  )
                : Icon(
                    icon,
                    color: outlined ? color : Colors.white,
                    size: 24,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: outlined ? color : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: outlined
                        ? theme.colorScheme.onSurfaceVariant
                        : Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: outlined ? color : Colors.white,
            size: 18,
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: buttonContent,
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    final theme = Theme.of(context);
    final todayLog = _todayLog ??
        DailyLog(
          date: _getTodayDateString(),
          status: LogStatus.pending,
        );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Date',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(todayLog.date),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (todayLog.swipeTime != null) ...[
              const Divider(height: 32),
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Swipe Time',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    todayLog.swipeTime!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 32),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Last Updated',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    todayLog.timestamp != null
                        ? _formatTimestamp(todayLog.timestamp!)
                        : 'Not yet updated',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: todayLog.timestamp != null
                          ? null
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            if (todayLog.empId != null) ...[
              const Divider(height: 32),
              Row(
                children: [
                  Icon(
                    Icons.badge_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Employee ID',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    todayLog.empId!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOldLogsCard(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_oldLogs.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No recent logs available',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Last ${_oldLogs.length} Days',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...(_oldLogs.take(7).map((log) {
              final statusColor = _getStatusColor(log.status);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: StatusBadge(status: log.status),
                          ),
                          const Spacer(),
                          Text(
                            _formatDate(log.date),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (log.swipeTime != null || log.timestamp != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (log.swipeTime != null) ...[
                              Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Swipe: ${log.swipeTime}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (log.swipeTime != null && log.timestamp != null)
                              const SizedBox(width: 12),
                            if (log.timestamp != null) ...[
                              Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _formatTimestamp(log.timestamp!),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList()),
          ],
        ),
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

  Future<void> _triggerAutomation(bool force) async {
    setState(() {
      _isLoading = true;
      _lastMessage = force ? 'Force triggering automation...' : 'Triggering automation...';
    });

    try {
      final response = await _apiService.triggerAutomation(force: force);

      if (response.success) {
        setState(() {
          _lastMessage = response.message ?? 'Automation triggered successfully';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_lastMessage!)),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }

        // Reload data after a delay
        await Future.delayed(const Duration(seconds: 2));
        await _loadData();
      } else {
        setState(() {
          _lastMessage = response.error ?? 'Failed to trigger automation';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_lastMessage!)),
                ],
              ),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _lastMessage = 'Error: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _skipToday() async {
    setState(() {
      _isLoading = true;
      _lastMessage = 'Skipping today...';
    });

    try {
      final success = await _firebaseService.updateTodayStatus(LogStatus.skip);

      if (success) {
        setState(() {
          _lastMessage = 'Today marked as skipped';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Today marked as skipped')),
                ],
              ),
              backgroundColor: AppTheme.statusSkip,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }

        await _loadData();
      } else {
        setState(() {
          _lastMessage = 'Failed to skip today';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Failed to skip today')),
                ],
              ),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _lastMessage = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} on ${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return timestamp;
    }
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _formatTimeUntilNext(int minutes) {
    if (minutes < 60) {
      return 'Upcoming in $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return 'Upcoming in $hours ${hours == 1 ? 'hour' : 'hours'}';
      } else {
        return 'Upcoming in $hours ${hours == 1 ? 'hour' : 'hours'} and $remainingMinutes ${remainingMinutes == 1 ? 'minute' : 'minutes'}';
      }
    }
  }
}
