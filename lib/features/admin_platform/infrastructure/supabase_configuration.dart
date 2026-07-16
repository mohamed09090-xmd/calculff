enum SupabaseConfigurationStatus { valid, missing, invalid }

enum SupabaseConfigurationIssue {
  missingUrl,
  missingPublishableKey,
  invalidUrl,
  insecureUrl,
  forbiddenProject,
  unexpectedHost,
  invalidPublishableKey,
}

class SupabaseConfiguration {
  const SupabaseConfiguration({
    required this.url,
    required this.publishableKey,
  });

  static const approvedProjectRef = 'zegjqwsvsaprnguvxuwk';
  static const approvedHost = '$approvedProjectRef.supabase.co';
  static const forbiddenProjectRef = 'txxokpovdbvsvnkpbrrp';

  final String url;
  final String publishableKey;
}

class SupabaseConfigurationResult {
  const SupabaseConfigurationResult._({
    required this.status,
    this.configuration,
    this.issue,
  });

  const SupabaseConfigurationResult.valid(
    SupabaseConfiguration configuration,
  ) : this._(
          status: SupabaseConfigurationStatus.valid,
          configuration: configuration,
        );

  const SupabaseConfigurationResult.missing(
    SupabaseConfigurationIssue issue,
  ) : this._(
          status: SupabaseConfigurationStatus.missing,
          issue: issue,
        );

  const SupabaseConfigurationResult.invalid(
    SupabaseConfigurationIssue issue,
  ) : this._(
          status: SupabaseConfigurationStatus.invalid,
          issue: issue,
        );

  final SupabaseConfigurationStatus status;
  final SupabaseConfiguration? configuration;
  final SupabaseConfigurationIssue? issue;
}

abstract final class SupabaseBuildConfiguration {
  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static SupabaseConfigurationResult get current => validate(
        url: _url,
        publishableKey: _publishableKey,
      );

  static SupabaseConfigurationResult validate({
    required String url,
    required String publishableKey,
  }) {
    final normalizedUrl = url.trim();
    final normalizedKey = publishableKey.trim();

    if (normalizedUrl.isEmpty) {
      return const SupabaseConfigurationResult.missing(
        SupabaseConfigurationIssue.missingUrl,
      );
    }
    if (normalizedKey.isEmpty) {
      return const SupabaseConfigurationResult.missing(
        SupabaseConfigurationIssue.missingPublishableKey,
      );
    }

    final lowerUrl = normalizedUrl.toLowerCase();
    if (lowerUrl.contains(SupabaseConfiguration.forbiddenProjectRef)) {
      return const SupabaseConfigurationResult.invalid(
        SupabaseConfigurationIssue.forbiddenProject,
      );
    }

    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      return const SupabaseConfigurationResult.invalid(
        SupabaseConfigurationIssue.invalidUrl,
      );
    }
    if (uri.scheme.toLowerCase() != 'https') {
      return const SupabaseConfigurationResult.invalid(
        SupabaseConfigurationIssue.insecureUrl,
      );
    }
    if (uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443) ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      return const SupabaseConfigurationResult.invalid(
        SupabaseConfigurationIssue.invalidUrl,
      );
    }

    final host = uri.host.toLowerCase();
    if (host.contains(SupabaseConfiguration.forbiddenProjectRef)) {
      return const SupabaseConfigurationResult.invalid(
        SupabaseConfigurationIssue.forbiddenProject,
      );
    }
    if (host != SupabaseConfiguration.approvedHost) {
      return const SupabaseConfigurationResult.invalid(
        SupabaseConfigurationIssue.unexpectedHost,
      );
    }

    final lowerKey = normalizedKey.toLowerCase();
    if (lowerKey.startsWith('sb_secret_') ||
        lowerKey.contains('service_role')) {
      return const SupabaseConfigurationResult.invalid(
        SupabaseConfigurationIssue.invalidPublishableKey,
      );
    }

    return SupabaseConfigurationResult.valid(
      SupabaseConfiguration(
        url: uri.replace(path: '').toString(),
        publishableKey: normalizedKey,
      ),
    );
  }
}
