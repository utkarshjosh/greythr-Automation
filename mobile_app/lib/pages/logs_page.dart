import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/daily_log.dart';
import '../widgets/log_card.dart';
import '../widgets/status_badge.dart';
import '../theme/app_theme.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  LogStatus? _selectedFilter;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
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
    _searchController.dispose();
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
                'Logs',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                onPressed: _showFilterDialog,
                tooltip: 'Filter',
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by date or employee ID...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                      _searchController.clear();
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filter Chips
                  if (_selectedFilter != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          StatusBadge(status: _selectedFilter!, compact: true),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedFilter = null;
                                });
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text('Clear Filter'),
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                foregroundColor: theme.colorScheme.onSurface,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_selectedFilter != null) const SizedBox(height: 16),

                  // Status Filter Chips
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(context, null, 'All'),
                          const SizedBox(width: 8),
                          ...LogStatus.values.map((status) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildFilterChip(context, status, status.displayName),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Logs List
          StreamBuilder<List<DailyLog>>(
            stream: _firebaseService.watchDailyLogs(days: 30),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: _buildErrorState(context, snapshot.error.toString()),
                );
              }

              final logs = snapshot.data ?? [];
              final filteredLogs = _filterLogs(logs);

              if (filteredLogs.isEmpty) {
                return SliverFillRemaining(
                  child: _buildEmptyState(context),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final log = filteredLogs[index];
                    return LogCard(
                      log: log,
                      onTap: () => _showLogDetails(context, log),
                    );
                  },
                  childCount: filteredLogs.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, LogStatus? status, String label) {
    final theme = Theme.of(context);
    final isSelected = _selectedFilter == status;
    
    return FilterChip(
      selected: isSelected,
      label: status != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusBadge(status: status, compact: true),
                const SizedBox(width: 8),
                Text(label),
              ],
            )
          : Text(label),
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? status : null;
        });
      },
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.onPrimaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Error loading logs',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() {});
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              _selectedFilter != null || _searchQuery.isNotEmpty
                  ? 'No logs match your filter'
                  : 'No logs available',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter != null || _searchQuery.isNotEmpty
                  ? 'Try adjusting your filters or search query'
                  : 'Your automation logs will appear here',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<DailyLog> _filterLogs(List<DailyLog> logs) {
    var filtered = logs;

    // Filter by status
    if (_selectedFilter != null) {
      filtered = filtered.where((log) => log.status == _selectedFilter).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final queryLower = _searchQuery.toLowerCase();
      filtered = filtered.where((log) {
        return log.date.contains(_searchQuery) ||
            (log.empId != null && log.empId!.toLowerCase().contains(queryLower));
      }).toList();
    }

    return filtered;
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Status',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Radio<LogStatus?>(
                value: null,
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value;
                  });
                  Navigator.pop(context);
                },
              ),
              title: const Text('All'),
              onTap: () {
                setState(() {
                  _selectedFilter = null;
                });
                Navigator.pop(context);
              },
            ),
            ...LogStatus.values.map((status) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Radio<LogStatus?>(
                  value: status,
                  groupValue: _selectedFilter,
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value;
                    });
                    Navigator.pop(context);
                  },
                ),
                title: Text(status.displayName),
                trailing: StatusBadge(status: status, compact: true),
                onTap: () {
                  setState(() {
                    _selectedFilter = status;
                  });
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showLogDetails(BuildContext context, DailyLog log) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Log Details',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    StatusBadge(status: log.status),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailRow(context, 'Date', _formatDate(log.date)),
                if (log.message != null) ...[
                  const Divider(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getStatusColor(log.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(log.status).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: _getStatusColor(log.status),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            log.message!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _getStatusColor(log.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (log.status != LogStatus.pending && log.swipeTime != null) ...[
                  const Divider(height: 32),
                  if (log.swipeTime != null)
                    _buildDetailRow(context, 'Swipe Time', log.swipeTime!),
                  if (log.swipeTime != null && log.timestamp != null)
                    const Divider(height: 32),
                  if (log.timestamp != null)
                    _buildDetailRow(
                      context,
                      'Timestamp',
                      _formatTimestamp(log.timestamp!),
                    ),
                  if (log.timestamp != null && log.empId != null)
                    const Divider(height: 32),
                  if (log.empId != null)
                    _buildDetailRow(context, 'Employee ID', log.empId!),
                  if (log.empId != null && log.workLocation != null)
                    const Divider(height: 32),
                  if (log.workLocation != null)
                    _buildDetailRow(context, 'Work Location', log.workLocation!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
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
      return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
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
