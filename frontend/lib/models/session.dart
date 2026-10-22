/// Who is signed in and the token to call the API with.
class Session {
  final String token;
  final String userId;
  final String name;
  final bool isAdmin;

  /// True for the private sample sandbox, false for a real work account.
  final bool demo;

  const Session({
    required this.token,
    required this.userId,
    required this.name,
    this.isAdmin = false,
    this.demo = true,
  });
}

/// Pages used and allowed this month. A total of 0 means "not known".
class QuotaInfo {
  final int used;
  final int total;

  const QuotaInfo({required this.used, required this.total});

  static const unknown = QuotaInfo(used: 0, total: 0);

  bool get known => total > 0;
  int get left => total > used ? total - used : 0;
}

/// One row of the admin "People and quotas" table.
class UserQuota {
  final String userId;
  final String name;
  final String? email;
  final QuotaInfo quota;

  const UserQuota({
    required this.userId,
    required this.name,
    required this.quota,
    this.email,
  });
}

/// How people sign in on this server, known before anyone is signed in.
class AuthConfig {
  /// `microsoft`, `google` or `none`.
  final String provider;

  /// Domain people must belong to, such as `contoso.com`. Empty when any is allowed.
  final String? domain;

  /// True when anyone can open a private sample sandbox.
  final bool demo;

  const AuthConfig({this.provider = 'none', this.domain, this.demo = true});

  /// Sample data only, no work accounts.
  static const demoOnly = AuthConfig();

  bool get hasWorkspace => provider == 'microsoft' || provider == 'google';

  /// `Microsoft` or `Google`, as shown on the button.
  String get providerName => provider == 'google' ? 'Google' : 'Microsoft';
}

/// What the administrator's setup check shows.
class SetupInfo {
  final String provider;
  final String? domain;
  final bool demoEnabled;
  final int defaultQuota;
  final int people;
  final int printers;

  /// The address to register with Microsoft or Google as the sign-in redirect.
  final String redirectUri;

  /// Things still to do, in plain words. Empty when the setup is complete.
  final List<String> warnings;

  const SetupInfo({
    required this.provider,
    required this.demoEnabled,
    required this.defaultQuota,
    required this.people,
    required this.printers,
    required this.redirectUri,
    required this.warnings,
    this.domain,
  });

  bool get hasWorkspace => provider == 'Microsoft' || provider == 'Google';
}
