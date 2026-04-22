part of 'home_page.dart';

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
