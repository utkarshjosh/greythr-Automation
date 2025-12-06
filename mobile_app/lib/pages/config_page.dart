import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/schedule_config.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/location_picker.dart';
import '../theme/app_theme.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final _cronController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _enabled = true;
  bool _isLoading = false;
  bool _hasChanges = false;
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
    _cronController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Saving configuration...',
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
                  'Configuration',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              ),
              actions: [
                if (_hasChanges)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: FilledButton.icon(
                        onPressed: _saveScheduleConfig,
                        icon: const Icon(Icons.save_rounded, size: 20),
                        label: const Text('Save'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: RefreshIndicator(
                  onRefresh: _loadConfig,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Schedule Config
                        StreamBuilder<ScheduleConfig?>(
                          stream: _firebaseService.watchScheduleConfig(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              print('Error in schedule config stream: ${snapshot.error}');
                              return _buildErrorCard(context, 'Failed to load schedule configuration');
                            }

                            final config = snapshot.data;
                            if (config != null && !_hasChanges) {
                              _cronController.text = config.cron;
                              _descriptionController.text = config.description;
                              _enabled = config.enabled;
                            }

                            return _buildScheduleConfigCard(context, config);
                          },
                        ),
                        const SizedBox(height: 24),

                        // General Config
                        StreamBuilder<Map<String, dynamic>?>(
                          stream: _firebaseService.watchGeneralConfig(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox.shrink();
                            }

                            if (snapshot.hasError) {
                              print('Error in general config stream: ${snapshot.error}');
                              return const SizedBox.shrink();
                            }

                            final config = snapshot.data ?? {};
                            final notifications = config['notifications'] as Map<String, dynamic>? ?? {};

                            return _buildGeneralConfigCard(context, config, notifications);
                          },
                        ),
                        const SizedBox(height: 24),

                        const SizedBox(height: 24),

                        // Work Location Config
                        StreamBuilder<Map<String, dynamic>?>(
                          stream: _firebaseService.watchWorkLocationConfig(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox.shrink();
                            }

                            if (snapshot.hasError) {
                              print('Error in work location config stream: ${snapshot.error}');
                              return const SizedBox.shrink();
                            }

                            final config = snapshot.data ?? {};

                            return _buildWorkLocationConfigCard(context, config);
                          },
                        ),
                        const SizedBox(height: 24),

                        // Location Config
                        StreamBuilder<Map<String, dynamic>?>(
                          stream: _firebaseService.watchLocationConfig(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox.shrink();
                            }

                            if (snapshot.hasError) {
                              print('Error in location config stream: ${snapshot.error}');
                              return const SizedBox.shrink();
                            }

                            final config = snapshot.data ?? {};

                            return _buildLocationConfigCard(context, config);
                          },
                        ),
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

  Widget _buildScheduleConfigCard(BuildContext context, ScheduleConfig? config) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Schedule Configuration',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Configure when automation runs',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _cronController,
              decoration: InputDecoration(
                labelText: 'Cron Expression',
                hintText: '0 9 * * *',
                helperText: 'Format: minute hour day month weekday',
                prefixIcon: const Icon(Icons.code_rounded),
                filled: true,
              ),
              onChanged: (_) => _markChanged(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Daily automation at 9:00 AM',
                prefixIcon: Icon(Icons.description_rounded),
                filled: true,
              ),
              onChanged: (_) => _markChanged(),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.toggle_on_rounded,
                        color: _enabled ? AppTheme.successColor : theme.colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enabled',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _enabled ? 'Automation is active' : 'Automation is disabled',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: _enabled,
                    onChanged: (value) {
                      setState(() {
                        _enabled = value;
                        _markChanged();
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildCronExamples(context),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralConfigCard(
    BuildContext context,
    Map<String, dynamic> config,
    Map<String, dynamic> notifications,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: AppTheme.secondaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'General Settings',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Automation and notification preferences',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSwitchRow(
              context,
              'Headless Mode',
              'Run browser in background',
              Icons.visibility_off_rounded,
              config['headless'] ?? true,
              (value) => _updateGeneralConfig('headless', value),
            ),
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            _buildSwitchRow(
              context,
              'Notifications Enabled',
              'Receive push notifications',
              Icons.notifications_rounded,
              notifications['enabled'] ?? true,
              (value) => _updateGeneralConfig('notifications.enabled', value),
            ),
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            _buildSwitchRow(
              context,
              'Notify on Success',
              'Get notified when automation succeeds',
              Icons.check_circle_rounded,
              notifications['onSuccess'] ?? true,
              (value) => _updateGeneralConfig('notifications.onSuccess', value),
            ),
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            _buildSwitchRow(
              context,
              'Notify on Failure',
              'Get notified when automation fails',
              Icons.error_rounded,
              notifications['onFailure'] ?? true,
              (value) => _updateGeneralConfig('notifications.onFailure', value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildCronExamples(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Cron Examples',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCronExample('0 9 * * *', 'Daily at 9:00 AM'),
          const SizedBox(height: 12),
          _buildCronExample('0 9 * * 1-5', 'Weekdays at 9:00 AM'),
          const SizedBox(height: 12),
          _buildCronExample('0 8,17 * * *', '8:00 AM and 5:00 PM daily'),
        ],
      ),
    );
  }

  Widget _buildCronExample(String cron, String description) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            cron,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              description,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveScheduleConfig() async {
    setState(() {
      _isLoading = true;
      _hasChanges = false;
    });

    try {
      final config = ScheduleConfig(
        cron: _cronController.text.trim(),
        description: _descriptionController.text.trim(),
        enabled: _enabled,
        updatedAt: DateTime.now().toIso8601String(),
      );

      final success = await _firebaseService.updateScheduleConfig(config);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Schedule configuration saved')),
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Failed to save configuration')),
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
        setState(() {
          _hasChanges = true;
        });
      }
    } catch (e) {
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
      setState(() {
        _hasChanges = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateGeneralConfig(String key, dynamic value) async {
    try {
      final currentConfig = await _firebaseService.getGeneralConfig() ?? {};
      final updatedConfig = Map<String, dynamic>.from(currentConfig);

      if (key.contains('.')) {
        final parts = key.split('.');
        if (parts.length == 2) {
          final parentKey = parts[0];
          final childKey = parts[1];
          final parent = Map<String, dynamic>.from(
            updatedConfig[parentKey] as Map? ?? {},
          );
          parent[childKey] = value;
          updatedConfig[parentKey] = parent;
        }
      } else {
        updatedConfig[key] = value;
      }

      await _firebaseService.updateGeneralConfig(updatedConfig);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(child: Text('Settings updated')),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error updating config: $e')),
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
  }

  Widget _buildLocationConfigCard(
    BuildContext context,
    Map<String, dynamic> config,
  ) {
    final theme = Theme.of(context);
    final latitude = (config['latitude'] as num?)?.toDouble() ?? 28.5355;
    final longitude = (config['longitude'] as num?)?.toDouble() ?? 77.391;
    final accuracy = (config['accuracy'] as num?)?.toDouble() ?? 100.0;
    final enabled = config['enabled'] ?? true;
    final description = config['description'] as String? ?? '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppTheme.accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location Configuration',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set GPS coordinates for automation',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Current location display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildLocationInfo(
                          context,
                          'Latitude',
                          latitude.toStringAsFixed(6),
                          Icons.north_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildLocationInfo(
                          context,
                          'Longitude',
                          longitude.toStringAsFixed(6),
                          Icons.east_rounded,
                        ),
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              description,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Pick location button
            FilledButton.icon(
              onPressed: () async {
                final result = await showDialog<Map<String, double>>(
                  context: context,
                  builder: (context) => LocationPicker(
                    initialLatitude: latitude,
                    initialLongitude: longitude,
                    initialAccuracy: accuracy,
                  ),
                );

                if (result != null && mounted) {
                  await _updateLocationConfig(
                    result['latitude']!,
                    result['longitude']!,
                    accuracy,
                    enabled,
                  );
                }
              },
              icon: const Icon(Icons.map_rounded),
              label: const Text('Pick Location on Map'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 20),
            // Accuracy slider
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Accuracy',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${accuracy.toInt()}m',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: accuracy,
                    min: 10,
                    max: 500,
                    divisions: 49,
                    label: '${accuracy.toInt()} meters',
                    onChanged: (value) async {
                      await _updateLocationConfig(
                        latitude,
                        longitude,
                        value,
                        enabled,
                      );
                    },
                  ),
                  Text(
                    'Location accuracy radius in meters',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Enabled toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.toggle_on_rounded,
                        color: enabled ? AppTheme.successColor : theme.colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location Enabled',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            enabled ? 'GPS coordinates will be used' : 'Location will be ignored',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (value) async {
                      await _updateLocationConfig(
                        latitude,
                        longitude,
                        accuracy,
                        value,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateLocationConfig(
    double latitude,
    double longitude,
    double accuracy,
    bool enabled,
  ) async {
    try {
      final currentConfig = await _firebaseService.getLocationConfig() ?? {};
      final updatedConfig = Map<String, dynamic>.from(currentConfig);

      updatedConfig['latitude'] = latitude;
      updatedConfig['longitude'] = longitude;
      updatedConfig['accuracy'] = accuracy;
      updatedConfig['enabled'] = enabled;
      
      // Generate description if not exists or update it
      if (!updatedConfig.containsKey('description') || 
          updatedConfig['description'] == null ||
          updatedConfig['description'].toString().isEmpty) {
        updatedConfig['description'] = 
            'Location: ${latitude.toStringAsFixed(4)}° N, ${longitude.toStringAsFixed(4)}° E';
      }

      if (!updatedConfig.containsKey('createdAt')) {
        updatedConfig['createdAt'] = DateTime.now().toIso8601String();
      }

      final success = await _firebaseService.updateLocationConfig(updatedConfig);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    success ? 'Location configuration updated' : 'Failed to update location',
                  ),
                ),
              ],
            ),
            backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error updating location: $e')),
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
  }

  Future<void> _updateWorkLocationConfig(String key, dynamic value) async {
    try {
      final currentConfig = await _firebaseService.getWorkLocationConfig() ?? {};
      final updatedConfig = Map<String, dynamic>.from(currentConfig);

      updatedConfig[key] = value;

      await _firebaseService.updateWorkLocationConfig(updatedConfig);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(child: Text('Work location updated')),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error updating config: $e')),
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
  }

  Widget _buildWorkLocationConfigCard(
    BuildContext context,
    Map<String, dynamic> config,
  ) {
    final theme = Theme.of(context);
    final workLocation = config['workLocation'] as String? ?? 'Office';
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.work_rounded,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Work Location',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Where are you working from?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Office'),
                    subtitle: const Text('Sign in from office location'),
                    value: 'Office',
                    groupValue: workLocation,
                    onChanged: (value) {
                      if (value != null) {
                        _updateWorkLocationConfig('workLocation', value);
                      }
                    },
                    secondary: const Icon(Icons.business_rounded),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.colorScheme.outline.withOpacity(0.1),
                  ),
                  RadioListTile<String>(
                    title: const Text('Work from Home'),
                    subtitle: const Text('Sign in from home location'),
                    value: 'Work From Home',
                    groupValue: workLocation,
                    onChanged: (value) {
                      if (value != null) {
                        _updateWorkLocationConfig('workLocation', value);
                      }
                    },
                    secondary: const Icon(Icons.home_rounded),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadConfig() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.error.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
