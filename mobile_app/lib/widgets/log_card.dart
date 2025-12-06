import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_log.dart';
import 'status_badge.dart';
import '../theme/app_theme.dart';

class LogCard extends StatefulWidget {
  final DailyLog log;
  final VoidCallback? onTap;

  const LogCard({
    super.key,
    required this.log,
    this.onTap,
  });

  @override
  State<LogCard> createState() => _LogCardState();
}

class _LogCardState extends State<LogCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTheme.shortAnimation,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final logDate = DateTime(date.year, date.month, date.day);

      if (logDate == today) {
        return 'Today';
      } else if (logDate == today.subtract(const Duration(days: 1))) {
        return 'Yesterday';
      } else {
        return DateFormat('MMM d, yyyy').format(date);
      }
    } catch (e) {
      return dateString;
    }
  }

  String? _formatTime(String? timeString) {
    if (timeString == null) return null;
    try {
      return timeString;
    } catch (e) {
      return timeString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = widget.log.date == _getTodayDateString();

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (isToday)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'TODAY',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            if (isToday) const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _formatDate(widget.log.date),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(status: widget.log.status, compact: true),
                    ],
                  ),
                  if (widget.log.message != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(widget.log.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(widget.log.status).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: _getStatusColor(widget.log.status),
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.log.message!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _getStatusColor(widget.log.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (widget.log.swipeTime != null || widget.log.timestamp != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      height: 1,
                      color: theme.colorScheme.outline.withOpacity(0.1),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 20,
                      runSpacing: 12,
                      children: [
                        if (widget.log.swipeTime != null)
                          _buildInfoRow(
                            context,
                            Icons.access_time_rounded,
                            'Swipe Time',
                            _formatTime(widget.log.swipeTime) ?? 'N/A',
                          ),
                        if (widget.log.timestamp != null)
                          _buildInfoRow(
                            context,
                            Icons.schedule_rounded,
                            'Timestamp',
                            _formatTimestamp(widget.log.timestamp!),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return DateFormat('MMM d, h:mm a').format(date);
    } catch (e) {
      return timestamp;
    }
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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
}
