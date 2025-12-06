import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final LogStatus status;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  Color get _statusColor {
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

  IconData get _statusIcon {
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

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _statusColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _statusColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_statusIcon, size: 14, color: _statusColor),
            const SizedBox(width: 6),
            Text(
              status.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _statusColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _statusColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon, size: 18, color: _statusColor),
          const SizedBox(width: 8),
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _statusColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
