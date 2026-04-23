part of 'home_page.dart';

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
    final titleColor = _primaryTextColor(context);
    final subtitleColor = _secondaryTextColor(context);
    final rowColor = selected
        ? (isDark ? const Color(0xFF1B2258) : Colors.white)
        : _surfaceColor(context);
    final rowBorder = _borderColor(context);
    final iconTileBg = _softSurfaceColor(context);
    final actionColor = _secondaryTextColor(context);
    final selectedBadgeBg =
        isDark ? const Color(0xFF2A3270) : const Color(0xFFE4ECFF);
    final selectedBadgeText =
        isDark ? const Color(0xFFDFE6FF) : const Color(0xFF2E4FBA);
    final pingChipBg = _softSurfaceColor(context);
    final pingColor = _pingColor(pingMs, isDark: isDark);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          decoration: BoxDecoration(
            color: rowColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: rowBorder,
              width: selected ? 1.0 : 0.8,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(right: 8, top: 1),
                decoration: BoxDecoration(
                  color: iconTileBg,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _borderColor(context)),
                ),
                child: Icon(
                  Icons.description_rounded,
                  size: 17,
                  color: selected ? _kAccent : actionColor,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                ),
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: selectedBadgeBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'SELECTED',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: selectedBadgeText,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'IP: ${_publicIpLabel(profile)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: subtitleColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: pingChipBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: _borderColor(context), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: pingColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$pingMs ms',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: pingColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                              width: 30, height: 30),
                          padding: EdgeInsets.zero,
                          splashRadius: 16,
                          onPressed: onInfo,
                          icon:
                              const Icon(Icons.info_outline_rounded, size: 19),
                          color: actionColor,
                          tooltip: 'Info',
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                              width: 30, height: 30),
                          padding: EdgeInsets.zero,
                          splashRadius: 16,
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 19),
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
    final buttonBg = _surfaceColor(context);
    final buttonText = _primaryTextColor(context);
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: buttonBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor(context), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded, size: 15, color: buttonText),
            const SizedBox(width: 4),
            Text(
              'Sort: $label',
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
        border: Border.all(color: _borderColor(context), width: 0.8),
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
