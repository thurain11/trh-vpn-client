class TrafficStats {
  const TrafficStats({
    required this.downloadBytes,
    required this.uploadBytes,
    this.downloadSpeedBytesPerSecond = 0,
    this.uploadSpeedBytesPerSecond = 0,
    this.totalDownloadBytes = 0,
    this.totalUploadBytes = 0,
    this.sessionDuration = Duration.zero,
  });

  // Session-scoped counters. These are reset on every new connect cycle.
  final int downloadBytes;
  final int uploadBytes;
  final int downloadSpeedBytesPerSecond;
  final int uploadSpeedBytesPerSecond;

  // Raw counters reported by runtime.
  final int totalDownloadBytes;
  final int totalUploadBytes;

  final Duration sessionDuration;

  factory TrafficStats.empty() {
    return const TrafficStats(
      downloadBytes: 0,
      uploadBytes: 0,
      downloadSpeedBytesPerSecond: 0,
      uploadSpeedBytesPerSecond: 0,
      totalDownloadBytes: 0,
      totalUploadBytes: 0,
      sessionDuration: Duration.zero,
    );
  }
}
