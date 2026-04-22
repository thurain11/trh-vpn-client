import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../app/theme_mode_controller.dart';
import '../../domain/entities/vpn_profile.dart';
import '../../domain/entities/vpn_status.dart';
import '../controllers/vpn_controller.dart';
import 'qr_scan_page.dart';
part 'home_page_vault_widgets.dart';
part 'home_page_configs_widgets.dart';
part 'home_page_helpers.dart';

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
