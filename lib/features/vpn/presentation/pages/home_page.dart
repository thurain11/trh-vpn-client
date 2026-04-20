import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../app/theme_mode_controller.dart';
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

const _kAccent = Color(0xFF355EDC);
const _kAccentDark = Color(0xFF2448B6);
const _kAccentSoftStrong = Color(0xFFE3EBFF);
const _kSelectProfileFirstMessage = 'Select a profile first.';

class _HomePageState extends ConsumerState<HomePage> {
  late final TextEditingController _importController;
  late final TextEditingController _subscriptionController;
  String _appVersionText = 'Loading...';

  int _tabIndex = 0;
  _ConfigSortMode _sortMode = _ConfigSortMode.ping;

  @override
  void initState() {
    super.initState();
    _importController = TextEditingController();
    _subscriptionController = TextEditingController();
    _loadAppVersion();
  }

  @override
  void dispose() {
    _importController.dispose();
    _subscriptionController.dispose();
    super.dispose();
  }

  Future<bool> _confirmExitRequested() async {
    if (_tabIndex != 0) {
      setState(() => _tabIndex = 0);
      return false;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Exit Lunex'),
          content: const Text('Do you want to exit the app?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );

    return shouldExit == true;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vpnControllerProvider);
    final controller = ref.read(vpnControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBackground =
        isDark ? const Color(0xFF0A0D2F) : const Color(0xFFF3F6FF);
    final appBarTextColor =
        isDark ? const Color(0xFFEAF0FF) : const Color(0xFF1C2431);
    final appBarIconColor =
        isDark ? const Color(0xFFAAB4EB) : const Color(0xFF5A6475);

    ref.listen<VpnState>(vpnControllerProvider, (previous, next) {
      final nextError = next.errorMessage;
      if (nextError == null || nextError == previous?.errorMessage) {
        return;
      }
      if (nextError != _kSelectProfileFirstMessage) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(_kSelectProfileFirstMessage),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      controller.clearErrorMessage();
    });

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

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldExit = await _confirmExitRequested();
        if (!mounted || !shouldExit) {
          return;
        }
        Navigator.of(this.context).pop();
      },
      child: Scaffold(
        backgroundColor: pageBackground,
        appBar: AppBar(
          backgroundColor: pageBackground,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 16,
          title: Row(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: _kAccent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Lunex Security',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: appBarTextColor,
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
              color: appBarIconColor,
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
                if (state.errorMessage != null &&
                    state.errorMessage != _kSelectProfileFirstMessage) ...[
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
      ),
    );
  }

  Widget _buildHomeTab(
    BuildContext context,
    VpnState state,
    VpnController controller,
  ) {
    final selectedProfile = state.selectedProfile;
    final canDisconnect = _shouldShowDisconnectAction(state.status);
    final pingLabel =
        selectedProfile == null ? '--' : '${_estimatePing(selectedProfile)}ms';

    return ListView(
      children: [
        _VaultStyleHomePanel(
          status: state.status,
          isBusy: state.isBusy,
          regionLabel: _regionLabel(selectedProfile),
          pingLabel: pingLabel,
          durationLabel: _formatDuration(state.trafficStats.sessionDuration),
          statusLabel: _statusMetaLabel(state.status),
          virtualIpLabel: _publicIpLabel(selectedProfile),
          downloadLabel:
              _formatSpeed(state.trafficStats.downloadSpeedBytesPerSecond),
          uploadLabel:
              _formatSpeed(state.trafficStats.uploadSpeedBytesPerSecond),
          selectedProfileName: selectedProfile?.name ?? 'No server selected',
          selectedProfileMeta: selectedProfile == null
              ? 'Import a profile from Configs tab'
              : 'Optimized Path • $pingLabel',
          selectedProfile: selectedProfile,
          onPowerTap: () {
            if (state.isBusy) {
              return;
            }
            if (canDisconnect) {
              controller.disconnect();
            } else {
              controller.connect();
            }
          },
          onOpenConfigs: () => setState(() => _tabIndex = 1),
        ),
      ],
    );
  }

  Widget _buildConfigsTab(
    BuildContext context,
    VpnState state,
    VpnController controller,
  ) {
    final canDisconnect = _shouldShowDisconnectAction(state.status);
    final profiles = [...state.profiles];
    final mutedColor = _secondaryTextColor(context);
    final titleColor = _primaryTextColor(context);
    profiles.sort((a, b) {
      if (_sortMode == _ConfigSortMode.name) {
        final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (byName != 0) {
          return byName;
        }
        return _estimatePing(a).compareTo(_estimatePing(b));
      }
      final byPing = _estimatePing(a).compareTo(_estimatePing(b));
      if (byPing != 0) {
        return byPing;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    final sortLabel = _sortMode == _ConfigSortMode.ping ? 'Latency' : 'Name';
    final profileCountLabel =
        profiles.length == 1 ? '1 profile' : '${profiles.length} profiles';
    final selectedLabel = state.selectedProfile == null
        ? 'No selected config'
        : 'Selected: ${state.selectedProfile!.name}';

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _softSurfaceColor(context),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: _borderColor(context)),
                    ),
                    child: const Icon(
                      Icons.dns_rounded,
                      size: 18,
                      color: _kAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configs',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: titleColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$profileCountLabel  •  Sort: $sortLabel',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: mutedColor,
                                    fontWeight: FontWeight.w600,
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
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  selectedLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openImportDialog(context),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Import / Sync'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: state.isBusy
                  ? null
                  : () => _scanQrAndImport(context, controller),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan QR'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: profiles.isEmpty
              ? _EmptyConfigsCard(
                  onImportTap: () => _openImportDialog(context),
                )
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
                      onDelete: () =>
                          _confirmDeleteProfile(context, controller, profile),
                    );
                  },
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
      ],
    );
  }

  Widget _buildSettingsTab(
    BuildContext context,
    VpnState state,
    VpnController controller,
  ) {
    final themeMode = ref.watch(appThemeModeProvider);
    final themeController = ref.read(appThemeModeProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedTextColor =
        isDark ? const Color(0xFFAAB4EB) : const Color(0xFF667085);

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appearance', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_rounded),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_rounded),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {
                    themeMode == ThemeMode.dark
                        ? ThemeMode.dark
                        : ThemeMode.light,
                  },
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) {
                      return;
                    }
                    themeController.setThemeMode(selection.first);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose between light and dark app appearance.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: mutedTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child:
                    Text('Support & Legal', style: theme.textTheme.titleMedium),
              ),
              _SettingsMenuTile(
                icon: Icons.info_outline_rounded,
                title: 'About Us',
                subtitle: 'What Lunex is and our mission',
                onTap: () => _showSettingsInfoSheet(
                  context,
                  title: 'About Lunex',
                  content:
                      'Lunex is a personal VPN client focused on fast profile import, stable connect/disconnect flow, and easy diagnostics for support.',
                ),
              ),
              _SettingsMenuTile(
                icon: Icons.mail_outline_rounded,
                title: 'Contact Us',
                subtitle: 'Support channels',
                onTap: () => _showSettingsInfoSheet(
                  context,
                  title: 'Contact Us',
                  content:
                      'Support Email: support@lunex.app\nTelegram: @lunex_support\n\nYou can also share your runtime log from this app when reporting issues.',
                ),
              ),
              _SettingsMenuTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'How data is handled',
                onTap: () => _showSettingsInfoSheet(
                  context,
                  title: 'Privacy Policy',
                  content:
                      'Lunex stores imported VPN profiles and subscription info locally on your device. Connection logs are only generated on-device for troubleshooting and are shared only when you choose to export/share them.',
                ),
              ),
              _SettingsMenuTile(
                icon: Icons.gavel_rounded,
                title: 'Terms & Conditions',
                subtitle: 'Usage terms',
                onTap: () => _showSettingsInfoSheet(
                  context,
                  title: 'Terms & Conditions',
                  content:
                      'Use Lunex in compliance with your local laws and network policy. You are responsible for imported endpoints/configurations and any traffic routed through them.',
                ),
              ),
              _SettingsMenuTile(
                icon: Icons.verified_outlined,
                title: 'Version',
                subtitle: _appVersionText,
                onTap: () => _showSettingsInfoSheet(
                  context,
                  title: 'App Version',
                  content: 'Current build: $_appVersionText',
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Runtime Health', style: theme.textTheme.titleMedium),
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
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (state.healthDetails != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    state.healthDetails!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (state.lastHealthCheckAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Last check: ${_formatDateTime(state.lastHealthCheckAt!)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) {
        return;
      }
      setState(() {
        _appVersionText = 'v${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _appVersionText = 'v0.1.0';
      });
    }
  }

  Future<void> _showSettingsInfoSheet(
    BuildContext context, {
    required String title,
    required String content,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                    ),
              ),
            ],
          ),
        );
      },
    );
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

  Future<void> _confirmDeleteProfile(
    BuildContext context,
    VpnController controller,
    VpnProfile profile,
  ) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Profile'),
          content: Text('Delete "${profile.name}" from local profiles?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD14D41),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (approved != true) {
      return;
    }
    await controller.deleteProfile(profile);
  }

  Future<void> _openImportDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(vpnControllerProvider);
              final controller = ref.read(vpnControllerProvider.notifier);

              return Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import & Sync',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add a profile by URI or sync from a subscription URL.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF667085),
                            ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Import URI',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _importController,
                        minLines: 2,
                        maxLines: 4,
                        onChanged: controller.setImportInput,
                        decoration: const InputDecoration(
                          hintText:
                              'Paste vless://, vmess://, trojan://, or ss://',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed:
                              state.isBusy ? null : controller.importRawUri,
                          child: const Text('Import Profile'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Text(
                        'Subscription Sync',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed:
                              state.isBusy ? null : controller.syncSubscription,
                          child: const Text('Sync Subscription Now'),
                        ),
                      ),
                      if (state.lastSubscriptionSyncAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Last sync: ${_formatDateTime(state.lastSubscriptionSyncAt!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
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

class _VaultStyleHomePanel extends StatelessWidget {
  const _VaultStyleHomePanel({
    required this.status,
    required this.isBusy,
    required this.regionLabel,
    required this.pingLabel,
    required this.durationLabel,
    required this.statusLabel,
    required this.virtualIpLabel,
    required this.downloadLabel,
    required this.uploadLabel,
    required this.selectedProfileName,
    required this.selectedProfileMeta,
    required this.selectedProfile,
    required this.onPowerTap,
    required this.onOpenConfigs,
  });

  final VpnStatus status;
  final bool isBusy;
  final String regionLabel;
  final String pingLabel;
  final String durationLabel;
  final String statusLabel;
  final String virtualIpLabel;
  final String downloadLabel;
  final String uploadLabel;
  final String selectedProfileName;
  final String selectedProfileMeta;
  final VpnProfile? selectedProfile;
  final VoidCallback onPowerTap;
  final VoidCallback onOpenConfigs;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = status == VpnStatus.connected
        ? (isDark ? const Color(0xFF79A7FF) : const Color(0xFF355EDC))
        : (isDark ? const Color(0xFFA8B4FF) : const Color(0xFF5C6EA8));
    final statusTextColor = status == VpnStatus.connected
        ? (isDark ? const Color(0xFFE3E7FA) : const Color(0xFF2E3342))
        : (isDark ? const Color(0xFFC6CCE9) : const Color(0xFF626A7C));
    final panelGradient = isDark
        ? const [Color(0xFF11133F), Color(0xFF0A0D2F)]
        : const [Color(0xFFF8FAFF), Color(0xFFEAF0FF)];
    final panelBorder =
        isDark ? const Color(0xFF23285A) : const Color(0xFFC9D6F4);
    final panelShadow =
        isDark ? const Color(0x34000000) : const Color(0x1D7D92C6);
    final brandIconColor =
        isDark ? const Color(0xFF8E9DFF) : const Color(0xFF4E5FC5);
    final brandTextColor =
        isDark ? const Color(0xFFE1E5FA) : const Color(0xFF3A3F4A);
    final regionChipBg =
        isDark ? const Color(0xFF1E2157) : const Color(0xFFE4EBFF);
    final regionChipBorder =
        isDark ? const Color(0xFF2E3371) : const Color(0xFFBECCF5);
    final regionIconColor =
        isDark ? const Color(0xFF9CAAF6) : const Color(0xFF5E74C9);
    final regionTextColor =
        isDark ? const Color(0xFFD2D8F4) : const Color(0xFF5B6270);
    final powerGradient = isDark
        ? const [Color(0xFF252B68), Color(0xFF171B4F)]
        : const [Color(0xFFE2E9FF), Color(0xFFCCD8FF)];
    final powerBorder =
        isDark ? const Color(0xFF2C3374) : const Color(0xFFB4C3F2);
    final metricBg = isDark ? const Color(0xFF14184B) : const Color(0xFFEAF0FF);
    final metricBorder =
        isDark ? const Color(0xFF262C67) : const Color(0xFFC3D2F5);
    final metricTitleColor =
        isDark ? const Color(0xFFB3BAD8) : const Color(0xFF8C93A0);
    final metricValueColor =
        isDark ? const Color(0xFFF1F4FF) : const Color(0xFF2F3443);
    final pingValueColor =
        isDark ? const Color(0xFF62E5FF) : const Color(0xFF0B9BC8);
    final statusValueColor = switch (status) {
      VpnStatus.connected =>
        (isDark ? const Color(0xFF7EF1BF) : const Color(0xFF2C9F66)),
      VpnStatus.connecting =>
        (isDark ? const Color(0xFFFFD27A) : const Color(0xFFC28416)),
      VpnStatus.disconnecting =>
        (isDark ? const Color(0xFFFFB480) : const Color(0xFFC86A2B)),
      VpnStatus.error =>
        (isDark ? const Color(0xFFFF7F98) : const Color(0xFFC93758)),
      VpnStatus.disconnected =>
        (isDark ? const Color(0xFFFF7F98) : const Color(0xFFC93758)),
    };
    final detailBg = isDark ? const Color(0xFF1A1E4D) : const Color(0xFFE5ECFF);
    final detailBorder =
        isDark ? const Color(0xFF2B3170) : const Color(0xFFBECDF3);
    final detailLabelColor =
        isDark ? const Color(0xFFB2B9D8) : const Color(0xFF8A92A0);
    final detailValueColor =
        isDark ? const Color(0xFFF0F3FF) : const Color(0xFF2D3342);
    final badgeBorder =
        isDark ? const Color(0xFF626AAB) : const Color(0xFF93A5DB);
    final badgeTextColor =
        isDark ? const Color(0xFFDDE3FF) : const Color(0xFF5A6172);
    final serverBg = isDark ? const Color(0xFF131646) : const Color(0xFFEAF0FF);
    final serverBorder =
        isDark ? const Color(0xFF313875) : const Color(0xFFC2D0F2);
    final serverAvatarGradient = isDark
        ? const [Color(0xFF28336D), Color(0xFF1A204B)]
        : const [Color(0xFFCEDBFF), Color(0xFFB8C9FA)];
    final serverAvatarTextColor =
        isDark ? const Color(0xFFE2E7FF) : const Color(0xFF2D4D97);
    final serverTitleColor =
        isDark ? const Color(0xFFEFF3FF) : const Color(0xFF2F3442);
    final serverMetaColor =
        isDark ? const Color(0xFFBDC6E8) : const Color(0xFF727B8E);
    final arrowBg = isDark ? const Color(0xFF222A63) : const Color(0xFFD4E0FF);
    final arrowColor =
        isDark ? const Color(0xFFC5CEFF) : const Color(0xFF3958B4);
    final isConnected = status == VpnStatus.connected;
    final isTransitioning =
        status == VpnStatus.connecting || status == VpnStatus.disconnecting;
    final powerOuterRing = isConnected
        ? (isDark ? const Color(0xFF32438D) : const Color(0xFFCBD8FF))
        : (isDark ? const Color(0xFF2A3165) : const Color(0xFFD2D6DD));
    final powerOuterBorder = isConnected
        ? (isDark ? const Color(0xFF4658A7) : const Color(0xFFB9CBFF))
        : (isDark ? const Color(0xFF404986) : const Color(0xFFC9CED6));
    final powerInnerBg = isConnected
        ? (isDark ? const Color(0xFF1A204B) : const Color(0xFFF4F7FF))
        : (isDark ? const Color(0xFF1A1E4D) : const Color(0xFFF2F3F5));
    final mainStateTextColor = isDark
        ? (isConnected ? const Color(0xFFEAF0FF) : const Color(0xFFE3E7FA))
        : (isConnected ? const Color(0xFF283E84) : const Color(0xFF2F3442));
    final actionHintColor =
        isDark ? const Color(0xFFAEB6D8) : const Color(0xFF7E8695);
    final stateHeadline = switch (status) {
      VpnStatus.connected => 'Connected',
      VpnStatus.connecting => 'Connecting',
      VpnStatus.disconnecting => 'Disconnecting',
      VpnStatus.error => 'Connection Error',
      VpnStatus.disconnected => 'Disconnected',
    };
    final stateHint = switch (status) {
      VpnStatus.connected => 'TAP TO DISCONNECT',
      VpnStatus.connecting => 'ESTABLISHING SECURE LAYER',
      VpnStatus.disconnecting => 'STOPPING SECURE LAYER',
      VpnStatus.error => 'TAP TO RETRY CONNECTION',
      VpnStatus.disconnected => 'TAP TO SECURE LAYER',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: panelGradient,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: panelBorder),
        boxShadow: [
          BoxShadow(
            color: panelShadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: brandIconColor),
              const SizedBox(width: 6),
              Text(
                'LUNEX VPN',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: brandTextColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: regionChipBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: regionChipBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: regionIconColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      regionLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: regionTextColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onPowerTap,
            child: Column(
              children: [
                Container(
                  width: 224,
                  height: 224,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: powerOuterRing,
                    border: Border.all(color: powerOuterBorder, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: isDark ? 0.2 : 0.1),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 154,
                      height: 154,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: powerInnerBg,
                        gradient: isConnected
                            ? RadialGradient(
                                colors: powerGradient,
                                radius: 0.85,
                              )
                            : null,
                        border: Border.all(color: powerBorder, width: 1.1),
                      ),
                      child: Center(
                        child: isBusy
                            ? const SizedBox(
                                width: 36,
                                height: 36,
                                child:
                                    CircularProgressIndicator(strokeWidth: 3),
                              )
                            : Icon(
                                Icons.power_settings_new_rounded,
                                size: 52,
                                color: accent,
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  stateHeadline,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: mainStateTextColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  stateHint,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: actionHintColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                ),
              ],
            ),
          ),
          if (isTransitioning) ...[
            const SizedBox(height: 6),
            Text(
              'Please wait...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: statusTextColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _VaultMetricTile(
                  title: 'PING',
                  value: pingLabel,
                  backgroundColor: metricBg,
                  borderColor: metricBorder,
                  titleColor: metricTitleColor,
                  valueColor: metricValueColor,
                  valueColorOverride: pingValueColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VaultMetricTile(
                  title: 'DURATION',
                  value: durationLabel,
                  backgroundColor: metricBg,
                  borderColor: metricBorder,
                  titleColor: metricTitleColor,
                  valueColor: metricValueColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VaultMetricTile(
                  title: 'STATUS',
                  value: statusLabel,
                  backgroundColor: metricBg,
                  borderColor: metricBorder,
                  titleColor: metricTitleColor,
                  valueColor: metricValueColor,
                  valueColorOverride: statusValueColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: detailBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: detailBorder),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'VIRTUAL IP ADDRESS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: detailLabelColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: badgeBorder),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _encryptionLabel(selectedProfile),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: badgeTextColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    virtualIpLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: detailValueColor,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _VaultTrafficTile(
                        icon: Icons.download_rounded,
                        label: 'DOWNLOAD',
                        value: downloadLabel,
                        iconColor: pingValueColor,
                        labelColor: metricTitleColor,
                        valueColor: metricValueColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _VaultTrafficTile(
                        icon: Icons.upload_rounded,
                        label: 'UPLOAD',
                        value: uploadLabel,
                        iconColor: metricValueColor,
                        labelColor: metricTitleColor,
                        valueColor: metricValueColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onOpenConfigs,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 9, 9, 9),
              decoration: BoxDecoration(
                color: serverBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: serverBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: serverAvatarGradient,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _regionAbbr(regionLabel),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: serverAvatarTextColor,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedProfileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: serverTitleColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedProfileMeta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: serverMetaColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: arrowBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: arrowColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultMetricTile extends StatelessWidget {
  const _VaultMetricTile({
    required this.title,
    required this.value,
    required this.backgroundColor,
    required this.borderColor,
    required this.titleColor,
    required this.valueColor,
    this.valueColorOverride,
  });

  final String title;
  final String value;
  final Color backgroundColor;
  final Color borderColor;
  final Color titleColor;
  final Color valueColor;
  final Color? valueColorOverride;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: valueColorOverride ?? valueColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _VaultTrafficTile extends StatelessWidget {
  const _VaultTrafficTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.labelColor,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color labelColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: valueColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
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
    required this.onDelete,
  });

  final VpnProfile profile;
  final int pingMs;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onInfo;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor =
        isDark ? const Color(0xFFEFF3FF) : const Color(0xFF2E3444);
    final subtitleColor =
        isDark ? const Color(0xFFB7BEE2) : const Color(0xFF6C7385);
    final rowColor = selected
        ? (isDark ? const Color(0xFF1A1E57) : const Color(0xFFEAF0FF))
        : (isDark ? const Color(0xFF121547) : Colors.white);
    final rowBorder = selected
        ? (isDark ? const Color(0xFF5567D0) : const Color(0xFFAFBDF0))
        : (isDark ? const Color(0xFF262C67) : const Color(0xFFE1E6F4));
    final iconTileBg =
        isDark ? const Color(0xFF242B68) : const Color(0xFFDDE6FF);
    final actionColor =
        isDark ? const Color(0xFFC0C7EE) : const Color(0xFF606A85);
    final pingColor = _pingColor(pingMs, isDark: isDark);

    return Material(
      color: rowColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: rowBorder,
              width: selected ? 1.2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: (isDark
                              ? const Color(0xFF7288FF)
                              : const Color(0xFF8BA2E8))
                          .withValues(alpha: isDark ? 0.22 : 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                margin: const EdgeInsets.only(right: 10, top: 1),
                decoration: BoxDecoration(
                  color: iconTileBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.storage_rounded,
                  size: 20,
                  color: selected
                      ? (isDark
                          ? const Color(0xFFBFCBFF)
                          : const Color(0xFF4C62B6))
                      : actionColor,
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
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'IP: ${_publicIpLabel(profile)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: subtitleColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: pingColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$pingMs ms',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: pingColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const Spacer(),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: onInfo,
                          icon:
                              const Icon(Icons.info_outline_rounded, size: 20),
                          color: actionColor,
                          tooltip: 'Info',
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 20),
                          color: const Color(0xFFD14D41),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ],
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonBg = isDark ? const Color(0xFF1D2455) : _kAccentSoftStrong;
    final buttonText = isDark ? const Color(0xFFC8D5FF) : _kAccentDark;
    final label = mode == _ConfigSortMode.ping ? 'Latency' : 'Name';

    return PopupMenuButton<_ConfigSortMode>(
      onSelected: onChanged,
      tooltip: 'Sort configs',
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _ConfigSortMode.ping,
          child: _SortMenuItem(
            label: 'Latency',
            selected: mode == _ConfigSortMode.ping,
          ),
        ),
        PopupMenuItem(
          value: _ConfigSortMode.name,
          child: _SortMenuItem(
            label: 'Name',
            selected: mode == _ConfigSortMode.name,
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: buttonBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 16, color: buttonText),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: buttonText,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: buttonText,
            ),
          ],
        ),
      ),
    );
  }
}

class _SortMenuItem extends StatelessWidget {
  const _SortMenuItem({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          selected ? Icons.check_rounded : Icons.circle_outlined,
          size: 16,
          color: selected ? _kAccent : _secondaryTextColor(context),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
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
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.dns_rounded,
            size: 30,
            color: _secondaryTextColor(context),
          ),
          const SizedBox(height: 8),
          Text(
            'No configs yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap Import / Sync above to add VLESS/VMESS/Trojan/SS profiles.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _secondaryTextColor(context),
                ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: onImportTap,
            child: const Text('Open Import Dialog'),
          ),
        ],
      ),
    );
  }
}

class _SettingsMenuTile extends StatelessWidget {
  const _SettingsMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtitleColor =
        isDark ? const Color(0xFFAAB4EB) : const Color(0xFF667085);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: _kAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canDisconnect = _shouldShowDisconnectAction(status);
    final transitioning =
        status == VpnStatus.connecting || status == VpnStatus.disconnecting;
    final title = switch (status) {
      VpnStatus.connected => 'Connected',
      VpnStatus.connecting => 'Connecting...',
      VpnStatus.disconnecting => 'Disconnecting...',
      VpnStatus.error => 'Connection Error',
      VpnStatus.disconnected => 'Not connected',
    };
    final subtitle = switch (status) {
      VpnStatus.connected => 'Secure tunnel is active.',
      VpnStatus.connecting => 'Establishing secure route.',
      VpnStatus.disconnecting => 'Stopping secure route.',
      VpnStatus.error => 'Try reconnecting or switch config.',
      VpnStatus.disconnected => 'Select a config or connect to best available.',
    };
    final panelBg = isDark ? const Color(0xFF212669) : const Color(0xFFEEF2FF);
    final panelBorder =
        isDark ? const Color(0xFF30397C) : const Color(0xFFD2DBF8);
    final titleColor =
        isDark ? const Color(0xFFEAF0FF) : const Color(0xFF2F3442);
    final subtitleColor =
        isDark ? const Color(0xFFB2BADD) : const Color(0xFF757E95);
    final iconCircleBg =
        isDark ? const Color(0xFF111644) : const Color(0xFFDDE6FF);
    final iconColor = switch (status) {
      VpnStatus.connected =>
        isDark ? const Color(0xFF82F5BE) : const Color(0xFF2A9E66),
      VpnStatus.connecting =>
        isDark ? const Color(0xFFFFD27A) : const Color(0xFFC78822),
      VpnStatus.disconnecting =>
        isDark ? const Color(0xFFFFB480) : const Color(0xFFC76D2C),
      VpnStatus.error =>
        isDark ? const Color(0xFFFF8AA3) : const Color(0xFFCC3C5A),
      VpnStatus.disconnected =>
        isDark ? const Color(0xFFA9B2D9) : const Color(0xFF6D7587),
    };
    final buttonBg = canDisconnect
        ? const Color(0xFFD92D20)
        : (isDark ? const Color(0xFF7E96FF) : _kAccent);
    final buttonText = canDisconnect
        ? 'DISCONNECT'
        : (transitioning ? 'CONNECTING' : 'CONNECT');
    final statusIcon = switch (status) {
      VpnStatus.connected => Icons.shield_rounded,
      VpnStatus.connecting => Icons.sync_rounded,
      VpnStatus.disconnecting => Icons.sync_disabled_rounded,
      VpnStatus.error => Icons.gpp_bad_rounded,
      VpnStatus.disconnected => Icons.wifi_off_rounded,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: panelBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconCircleBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, size: 23, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: titleColor,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: subtitleColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: isBusy ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: buttonBg,
              minimumSize: const Size.fromHeight(50),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: transitioning
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(canDisconnect ? 'STOPPING' : 'CONNECTING'),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        canDisconnect
                            ? Icons.power_settings_new_rounded
                            : Icons.bolt_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(buttonText),
                    ],
                  ),
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
    final inactiveColor = _secondaryTextColor(context);
    final navBackground = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF131646)
        : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: navBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor(context)),
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
                        color: currentIndex == i ? _kAccent : inactiveColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w800,
                              color:
                                  currentIndex == i ? _kAccent : inactiveColor,
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

Color _surfaceColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF14184A)
      : Colors.white;
}

Color _softSurfaceColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF1A1F56)
      : const Color(0xFFF1F5FF);
}

Color _borderColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF2C3376)
      : const Color(0xFFE4E9F1);
}

Color _primaryTextColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFEAF0FF)
      : const Color(0xFF1E2430);
}

Color _secondaryTextColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFAAB4EB)
      : const Color(0xFF667085);
}

bool _shouldShowDisconnectAction(VpnStatus status) {
  return status == VpnStatus.connected ||
      status == VpnStatus.connecting ||
      status == VpnStatus.error;
}

String _statusMetaLabel(VpnStatus status) {
  return switch (status) {
    VpnStatus.connected => 'Secure',
    VpnStatus.connecting => 'Establishing',
    VpnStatus.disconnecting => 'Stopping',
    VpnStatus.error => 'Action needed',
    VpnStatus.disconnected => 'Inactive',
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
    return _maskIpv4(host);
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

String _maskIpv4(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) {
    return ip;
  }
  return '${parts[0]}.***.***.${parts[3]}';
}

String _regionLabel(VpnProfile? profile) {
  if (profile == null) {
    return 'NO SERVER';
  }

  final raw = profile.name.trim();
  if (raw.isEmpty) {
    return 'AUTO';
  }

  final tokens =
      raw.split(RegExp(r'[\s\-_]+')).where((item) => item.isNotEmpty).toList();
  if (tokens.isEmpty) {
    return 'AUTO';
  }
  return tokens.first.toUpperCase();
}

String _regionAbbr(String value) {
  final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (cleaned.isEmpty) {
    return 'VPN';
  }
  if (cleaned.length <= 3) {
    return cleaned.toUpperCase();
  }
  return cleaned.substring(0, 3).toUpperCase();
}

Color _pingColor(int pingMs, {required bool isDark}) {
  if (pingMs <= 90) {
    return isDark ? const Color(0xFF62E5FF) : const Color(0xFF0B9BC8);
  }
  if (pingMs <= 180) {
    return isDark ? const Color(0xFFDCE5FF) : const Color(0xFF7183B8);
  }
  return isDark ? const Color(0xFFFF7F98) : const Color(0xFFC93758);
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
