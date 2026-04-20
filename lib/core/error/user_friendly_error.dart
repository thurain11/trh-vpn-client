enum VpnErrorCategory {
  validation,
  unsupportedFormat,
  timeout,
  network,
  permission,
  runtime,
  profile,
  subscription,
  healthCheck,
  diagnostics,
  unknown,
}

class UserFriendlyError {
  const UserFriendlyError({
    required this.category,
    required this.message,
  });

  final VpnErrorCategory category;
  final String message;
}

class UserFriendlyErrorMapper {
  const UserFriendlyErrorMapper._();

  static UserFriendlyError map(String rawMessage) {
    final raw = rawMessage.trim();
    if (raw.isEmpty) {
      return const UserFriendlyError(
        category: VpnErrorCategory.unknown,
        message: 'Something went wrong. Please try again.',
      );
    }

    final lower = raw.toLowerCase();

    if (lower.contains('paste a vpn uri first')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.validation,
        message: 'Paste a VPN URI before importing.',
      );
    }
    if (lower.contains('paste a subscription url first')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.validation,
        message: 'Paste a subscription URL before syncing.',
      );
    }
    if (lower.contains('select a profile first')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.profile,
        message: 'Select a profile first.',
      );
    }
    if (lower.contains('unsupported profile format')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.unsupportedFormat,
        message:
            'Unsupported profile format. Use VLESS/VMess/Trojan/SS URI or a valid subscription URL.',
      );
    }
    if (lower.contains('qr content is empty or unsupported')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.unsupportedFormat,
        message: 'QR content is empty or unsupported.',
      );
    }
    if (lower.contains('no log file available yet')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.diagnostics,
        message:
            'No diagnostics log available yet. Connect once and try again.',
      );
    }
    if (lower.contains('unable to open log file')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.diagnostics,
        message: 'Unable to open diagnostics log file.',
      );
    }
    if (lower.contains('unable to share log file')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.diagnostics,
        message: 'Unable to share diagnostics log file.',
      );
    }

    if (lower.contains('bundled native binary missing') ||
        lower.contains('libxray.so') ||
        lower.contains('nativelibrarydir')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.runtime,
        message:
            'Xray runtime binary is missing for this device ABI. Rebuild and include the correct libxray.so in android/app/src/main/jniLibs.',
      );
    }

    if (lower.contains('timeoutexception') || lower.contains('timed out')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.timeout,
        message:
            'Request timed out. Check network/server reachability and try again.',
      );
    }
    if (lower.contains('unable to resolve host') ||
        lower.contains('failed host lookup') ||
        lower.contains('name or service not known') ||
        lower.contains('nodename nor servname provided')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.network,
        message: 'Cannot resolve server host. Check DNS/network and try again.',
      );
    }
    if (lower.contains('connection refused')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.network,
        message: 'Server refused the connection. Check host/port and server.',
      );
    }
    if (lower.contains('connection reset')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.network,
        message: 'Connection was reset by server. Try again or switch profile.',
      );
    }
    if (lower.contains('network is unreachable')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.network,
        message: 'Network is unreachable. Check your internet connection.',
      );
    }

    if (lower.contains('permission denied') ||
        lower.contains('securityexception') ||
        lower.contains('not allowed') ||
        lower.contains('denied')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.permission,
        message:
            'Permission denied. Please allow required VPN/file permissions.',
      );
    }

    if (lower.contains('subscription sync failed')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.subscription,
        message: 'Subscription sync failed. Please verify URL and try again.',
      );
    }
    if (lower.contains('import failed') || lower.contains('qr import failed')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.unsupportedFormat,
        message: 'Import failed. Verify the profile data and try again.',
      );
    }
    if (lower.contains('health check failed')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.healthCheck,
        message: 'Health check failed. Please retry in a moment.',
      );
    }
    if (lower.contains('delete failed')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.profile,
        message: 'Unable to delete profile right now. Please try again.',
      );
    }

    if (lower.contains('failed') || lower.contains('error')) {
      return const UserFriendlyError(
        category: VpnErrorCategory.unknown,
        message: 'Operation failed. Please try again.',
      );
    }

    return UserFriendlyError(
      category: VpnErrorCategory.unknown,
      message: raw,
    );
  }

  static String toMessage(String rawMessage) => map(rawMessage).message;
}
