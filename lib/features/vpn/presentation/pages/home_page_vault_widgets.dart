part of 'home_page.dart';

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
