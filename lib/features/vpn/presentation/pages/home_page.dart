import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/traffic_stats.dart';
import '../../domain/entities/vpn_profile.dart';
import '../../domain/entities/vpn_status.dart';
import '../controllers/vpn_controller.dart';
import 'qr_scan_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

enum _ConfigSortMode { ping, name }

const _kAccent = Color(0xFF159A72);
const _kAccentDark = Color(0xFF0E7A59);
const _kAccentSoft = Color(0xFFE8F7F1);
const _kAccentSoftStrong = Color(0xFFDDF2E9);

class _HomePageState extends ConsumerState<HomePage> {
  late final TextEditingController _importController;
  late final TextEditingController _subscriptionController;

  int _tabIndex = 0;
  _ConfigSortMode _sortMode = _ConfigSortMode.ping;

  @override
  void initState() {
    super.initState();
    _importController = TextEditingController();
    _subscriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _importController.dispose();
    _subscriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vpnControllerProvider);
    final controller = ref.read(vpnControllerProvider.notifier);

    if (_importController.text != state.importInput) {
      _importController.value = TextEditingValue(
        text: state.importInput,
        selection: TextSelection.collapsed(offset: state.importInput.length),
      );
    }

    if (_subscriptionController.text != state.subscriptionInput) {
      _subscriptionController.value = TextEditingValue(
        text: state.subscriptionInput,
        selection: TextSelection.collapsed(
          offset: state.subscriptionInput.length,
        ),
      );
    }

    final tabViews = <Widget>[
      _buildHomeTab(context, state, controller),
      _buildConfigsTab(context, state, controller),
      _buildSettingsTab(context, state, controller),
    ];

    final canDisconnect = _shouldShowDisconnectAction(state.status);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F3F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F3F8),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            const Icon(Icons.shield_rounded, color: _kAccent, size: 22),
            const SizedBox(width: 8),
            Text(
              'Lunex Security',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C2431),
                  ),
            ),
          ],
        ),
        actions: [
          if (state.status == VpnStatus.connected)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.bolt_rounded, color: _kAccent, size: 20),
            ),
          IconButton(
            onPressed: () => setState(() => _tabIndex = 2),
            icon: const Icon(Icons.tune_rounded),
            color: const Color(0xFF5A6475),
            tooltip: 'Settings',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(
                    key: ValueKey(_tabIndex),
                    child: tabViews[_tabIndex],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _ConnectionDock(
                status: state.status,
                isBusy: state.isBusy,
                onPressed: () {
                  if (canDisconnect) {
                    controller.disconnect();
                  } else {
                    controller.connect();
                  }
                },
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    state.errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFB42318),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _BottomTabBar(
                currentIndex: _tabIndex,
                onChanged: (index) => setState(() => _tabIndex = index),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab(
    BuildContext context,
    VpnState state,
    VpnController controller,
  ) {
    final statusColor = _statusColor(state.status);
    final selectedProfile = state.selectedProfile;

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE4E9F1)),
          ),
          child: Column(
            children: [
              Container(
                height: 92,
                width: 92,
                decoration: BoxDecoration(
                  color: _kAccentSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _statusIcon(state.status),
                  size: 38,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _statusHeadline(state.status),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1E2430),
                      letterSpacing: -0.6,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusSubline(state.status),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5E6675),
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: state.profiles.isEmpty
                      ? null
                      : () {
                          final best = _pickBestProfile(state.profiles);
                          if (best != null) {
                            controller.selectProfile(best);
                          }
                        },
                  icon: const Icon(Icons.public_rounded),
                  label: const Text('Select Optimal Server'),
                  style: FilledButton.styleFrom(
                    foregroundColor: _kAccentDark,
                    backgroundColor: _kAccentSoft,
                    minimumSize: const Size.fromHeight(48),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (selectedProfile != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Selected: ${selectedProfile.name}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF475467),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                label: 'PUBLIC IP',
                value: _publicIpLabel(selectedProfile),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoTile(
                label: 'ENCRYPTION',
                value: _encryptionLabel(selectedProfile),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _WorldMapPanel(trafficStats: state.trafficStats),
        const SizedBox(height: 12),
        _SpeedCard(
          trafficStats: state.trafficStats,
          status: state.status,
          healthSummary: state.healthSummary,
        ),
      ],
    );
  }

  Widget _buildConfigsTab(
    BuildContext context,
    VpnState state,
    VpnController controller,
  ) {
    final profiles = [...state.profiles];
    profiles.sort((a, b) {
      if (_sortMode == _ConfigSortMode.name) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _estimatePing(a).compareTo(_estimatePing(b));
    });

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Network Assets',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF667085),
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Configs',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1E2430),
                          letterSpacing: -0.6,
                        ),
                  ),
                ],
              ),
            ),
            _SortButton(
              mode: _sortMode,
              onChanged: (mode) => setState(() => _sortMode = mode),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _tabIndex = 2),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Import / Sync'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: state.profiles.isEmpty
                  ? null
                  : () {
                      final best = _pickBestProfile(state.profiles);
                      if (best != null) {
                        controller.selectProfile(best);
                      }
                    },
              icon: const Icon(Icons.speed_rounded),
              label: const Text('Best'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: profiles.isEmpty
              ? _EmptyConfigsCard(
                  onImportTap: () => setState(() => _tabIndex = 2))
              : ListView.separated(
                  itemCount: profiles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    final isSelected = profile.id == state.selectedProfile?.id;
                    return _ConfigRowCard(
                      profile: profile,
                      pingMs: _estimatePing(profile),
                      selected: isSelected,
                      onTap: () => controller.selectProfile(profile),
                      onInfo: () => _showProfileInfo(context, profile),
                      onEdit: () =>
                          _showSoon(context, 'Rename/edit is coming next.'),
                      onDelete: () => _showSoon(
                          context, 'Delete action will be added in next step.'),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab(
    BuildContext context,
    VpnState state,
    VpnController controller,
  ) {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Runtime Health',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: state.isBusy || state.isHealthChecking
                        ? null
                        : controller.runHealthCheck,
                    child: Text(state.isHealthChecking
                        ? 'Checking...'
                        : 'Run Health Check'),
                  ),
                ),
                if (state.healthSummary != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    state.healthSummary!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
                if (state.healthDetails != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    state.healthDetails!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (state.lastHealthCheckAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Last check: ${_formatDateTime(state.lastHealthCheckAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Import URI',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _importController,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: controller.setImportInput,
                  decoration: const InputDecoration(
                    hintText: 'Paste vless://, vmess://, trojan://, or ss://',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            state.isBusy ? null : controller.importRawUri,
                        child: const Text('Import Profile'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: state.isBusy
                            ? null
                            : () => _scanQrAndImport(context, controller),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Scan QR'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subscription Sync',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _subscriptionController,
                  minLines: 1,
                  maxLines: 2,
                  onChanged: controller.setSubscriptionInput,
                  decoration: const InputDecoration(
                    hintText: 'Paste https:// subscription URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed:
                        state.isBusy ? null : controller.syncSubscription,
                    child: const Text('Sync Subscription Now'),
                  ),
                ),
                if (state.lastSubscriptionSyncAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Last sync: ${_formatDateTime(state.lastSubscriptionSyncAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  VpnProfile? _pickBestProfile(List<VpnProfile> profiles) {
    if (profiles.isEmpty) {
      return null;
    }

    final sorted = [...profiles]..sort(
        (a, b) => _estimatePing(a).compareTo(_estimatePing(b)),
      );
    return sorted.first;
  }

  int _estimatePing(VpnProfile profile) {
    final hostSeed = profile.endpoint.host.codeUnits.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    return 35 + ((hostSeed + profile.endpoint.port) % 180);
  }

  void _showProfileInfo(BuildContext context, VpnProfile profile) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Text('Host: ${profile.endpoint.host}'),
              Text('Port: ${profile.endpoint.port}'),
              Text('Protocol: ${profile.protocol.name.toUpperCase()}'),
              Text('Security: ${_encryptionLabel(profile)}'),
            ],
          ),
        );
      },
    );
  }

  void _showSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _scanQrAndImport(
    BuildContext context,
    VpnController controller,
  ) async {
    final scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScanPage(),
      ),
    );
    if (!mounted || scannedValue == null || scannedValue.trim().isEmpty) {
      return;
    }
    await controller.importFromQrPayload(scannedValue);
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF7C8494),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF202939),
                ),
          ),
        ],
      ),
    );
  }
}

class _WorldMapPanel extends StatelessWidget {
  const _WorldMapPanel({required this.trafficStats});

  final TrafficStats trafficStats;

  @override
  Widget build(BuildContext context) {
    final activity = trafficStats.downloadSpeedBytesPerSecond +
        trafficStats.uploadSpeedBytesPerSecond;

    return Container(
      height: 118,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE1E6EF), Color(0xFFD3DAE7)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.25,
              child: CustomPaint(painter: _GridPainter()),
            ),
          ),
          Positioned(
            left: 16,
            top: 14,
            child: Row(
              children: [
                const Icon(Icons.public, color: Color(0xFF667085), size: 18),
                const SizedBox(width: 6),
                Text(
                  activity > 0 ? 'Traffic flowing' : 'Waiting for traffic',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF4B5565),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 14,
            bottom: 10,
            child: Text(
              '↓ ${_formatSpeed(trafficStats.downloadSpeedBytesPerSecond)}  '
              '↑ ${_formatSpeed(trafficStats.uploadSpeedBytesPerSecond)}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF3F495A),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 1;

    const rows = 5;
    const cols = 8;

    for (var i = 1; i < rows; i++) {
      final y = size.height * i / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    for (var i = 1; i < cols; i++) {
      final x = size.width * i / cols;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SpeedCard extends StatelessWidget {
  const _SpeedCard({
    required this.trafficStats,
    required this.status,
    required this.healthSummary,
  });

  final TrafficStats trafficStats;
  final VpnStatus status;
  final String? healthSummary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _dot(
                status == VpnStatus.connected
                    ? const Color(0xFF12B76A)
                    : const Color(0xFFF04438),
              ),
              const SizedBox(width: 8),
              Text(
                status == VpnStatus.connected
                    ? 'Connected metrics'
                    : 'Not connected',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'DOWNLOAD',
                  value: _formatSpeed(trafficStats.downloadSpeedBytesPerSecond),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  label: 'UPLOAD',
                  value: _formatSpeed(trafficStats.uploadSpeedBytesPerSecond),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Session ${_formatDuration(trafficStats.sessionDuration)}   '
            'Total ↓ ${_formatBytes(trafficStats.downloadBytes)} '
            '↑ ${_formatBytes(trafficStats.uploadBytes)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF667085),
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (healthSummary != null) ...[
            const SizedBox(height: 6),
            Text(
              'Health: $healthSummary',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF475467),
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF7D8696),
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ConfigRowCard extends StatelessWidget {
  const _ConfigRowCard({
    required this.profile,
    required this.pingMs,
    required this.selected,
    required this.onTap,
    required this.onInfo,
    required this.onEdit,
    required this.onDelete,
  });

  final VpnProfile profile;
  final int pingMs;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onInfo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _kAccent : const Color(0xFFE4E9F1),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 44,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: selected ? _kAccent : const Color(0xFFC8CDD8),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E2430),
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_maskHost(profile.endpoint.host)}  •  $pingMs ms',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF667085),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 20),
                color: const Color(0xFF667085),
                tooltip: 'Edit',
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onInfo,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                color: const Color(0xFF667085),
                tooltip: 'Info',
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: const Color(0xFFD14D41),
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.mode, required this.onChanged});

  final _ConfigSortMode mode;
  final ValueChanged<_ConfigSortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _kAccentSoftStrong,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_ConfigSortMode>(
          value: mode,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _kAccentDark,
                fontWeight: FontWeight.w700,
              ),
          items: const [
            DropdownMenuItem(
              value: _ConfigSortMode.ping,
              child: Text('Sort by: Ping'),
            ),
            DropdownMenuItem(
              value: _ConfigSortMode.name,
              child: Text('Sort by: Name'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }
}

class _EmptyConfigsCard extends StatelessWidget {
  const _EmptyConfigsCard({required this.onImportTap});

  final VoidCallback onImportTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.dns_rounded, size: 30, color: Color(0xFF98A2B3)),
          const SizedBox(height: 8),
          Text(
            'No configs yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Import your VLESS/VMESS URI from Settings tab.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF667085),
                ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: onImportTap,
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }
}

class _ConnectionDock extends StatelessWidget {
  const _ConnectionDock({
    required this.status,
    required this.isBusy,
    required this.onPressed,
  });

  final VpnStatus status;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final canDisconnect = _shouldShowDisconnectAction(status);
    final transitioning =
        status == VpnStatus.connecting || status == VpnStatus.disconnecting;

    final leftText = switch (status) {
      VpnStatus.connected => 'Connected',
      VpnStatus.connecting => 'Connecting...',
      VpnStatus.disconnecting => 'Disconnecting...',
      VpnStatus.error => 'Error state',
      VpnStatus.disconnected => 'Not connected',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: status == VpnStatus.connected
                  ? const Color(0xFF12B76A)
                  : const Color(0xFFF79009),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              leftText,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF272F3E),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          FilledButton(
            onPressed: isBusy ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor:
                  canDisconnect ? const Color(0xFFD92D20) : _kAccent,
              minimumSize: const Size(126, 42),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: transitioning
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(canDisconnect ? 'Stopping' : 'Starting'),
                    ],
                  )
                : Text(canDisconnect ? 'Disconnect' : 'Connect'),
          ),
        ],
      ),
    );
  }
}

class _BottomTabBar extends StatelessWidget {
  const _BottomTabBar({required this.currentIndex, required this.onChanged});

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      (icon: Icons.home_rounded, label: 'HOME'),
      (icon: Icons.dns_rounded, label: 'CONFIGS'),
      (icon: Icons.settings_rounded, label: 'SETTINGS'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].icon,
                        size: 22,
                        color: currentIndex == i
                            ? _kAccent
                            : const Color(0xFF7A8394),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w800,
                              color: currentIndex == i
                                  ? _kAccent
                                  : const Color(0xFF7A8394),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

bool _shouldShowDisconnectAction(VpnStatus status) {
  return status == VpnStatus.connected ||
      status == VpnStatus.connecting ||
      status == VpnStatus.error;
}

IconData _statusIcon(VpnStatus status) {
  return switch (status) {
    VpnStatus.connected => Icons.check_circle_rounded,
    VpnStatus.connecting => Icons.shield_moon_rounded,
    VpnStatus.disconnecting => Icons.shield_outlined,
    VpnStatus.error => Icons.gpp_bad_rounded,
    VpnStatus.disconnected => Icons.gpp_maybe_rounded,
  };
}

Color _statusColor(VpnStatus status) {
  return switch (status) {
    VpnStatus.connected => _kAccentDark,
    VpnStatus.connecting => _kAccent,
    VpnStatus.disconnecting => const Color(0xFFB54708),
    VpnStatus.error => const Color(0xFFB42318),
    VpnStatus.disconnected => const Color(0xFF6B7280),
  };
}

String _statusHeadline(VpnStatus status) {
  return switch (status) {
    VpnStatus.connected => 'CONNECTED',
    VpnStatus.connecting => 'CONNECTING',
    VpnStatus.disconnecting => 'DISCONNECTING',
    VpnStatus.error => 'ERROR',
    VpnStatus.disconnected => 'DISCONNECTED',
  };
}

String _statusSubline(VpnStatus status) {
  return switch (status) {
    VpnStatus.connected =>
      'Your traffic is encrypted and routed through Lunex.',
    VpnStatus.connecting => 'Preparing secure tunnel. Please wait a moment.',
    VpnStatus.disconnecting =>
      'Shutting down tunnel and restoring network paths.',
    VpnStatus.error => 'Tunnel has an issue. You can disconnect and try again.',
    VpnStatus.disconnected =>
      'Your connection is not encrypted. Traffic is visible to others.',
  };
}

String _encryptionLabel(VpnProfile? profile) {
  if (profile == null) {
    return 'None';
  }
  final security = profile.transport.security?.trim() ?? '';
  if (security.isNotEmpty) {
    return security.toUpperCase();
  }
  return switch (profile.protocol) {
    VpnProtocol.vless => 'REALITY/TLS',
    VpnProtocol.vmess => 'VMESS',
    VpnProtocol.trojan => 'TLS',
    VpnProtocol.shadowsocks => 'SHADOWSOCKS',
    VpnProtocol.wireGuard => 'WIREGUARD',
    VpnProtocol.custom => 'CUSTOM',
  };
}

String _publicIpLabel(VpnProfile? profile) {
  final host = profile?.endpoint.host;
  if (host == null || host.isEmpty) {
    return 'Unknown';
  }
  final ipv4 = RegExp(r'^\d+\.\d+\.\d+\.\d+$');
  if (ipv4.hasMatch(host)) {
    return host;
  }
  return _maskHost(host);
}

String _maskHost(String host) {
  final parts = host.split('.');
  if (parts.length < 3) {
    return host;
  }
  final first = parts[0];
  final second = parts[1];
  final last = parts.last;
  return '$first.$second.***.$last';
}

String _formatBytes(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  final text =
      value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$text ${units[unitIndex]}';
}

String _formatSpeed(int bytesPerSecond) {
  return '${_formatBytes(bytesPerSecond)}/s';
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String _formatDateTime(DateTime timestamp) {
  final date = '${timestamp.year.toString().padLeft(4, '0')}-'
      '${timestamp.month.toString().padLeft(2, '0')}-'
      '${timestamp.day.toString().padLeft(2, '0')}';
  return '$date ${_formatClock(timestamp)}';
}

String _formatClock(DateTime timestamp) {
  final hour = timestamp.hour.toString().padLeft(2, '0');
  final minute = timestamp.minute.toString().padLeft(2, '0');
  final second = timestamp.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}
