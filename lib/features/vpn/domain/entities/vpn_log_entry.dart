enum VpnLogSeverity { info, warn, error }

enum VpnLogFilter { all, info, warn, error }

class VpnLogEntry {
  const VpnLogEntry({
    required this.timestamp,
    required this.title,
    required this.message,
    required this.severity,
  });

  final DateTime timestamp;
  final String title;
  final String message;
  final VpnLogSeverity severity;
}
