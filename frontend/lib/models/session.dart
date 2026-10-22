/// Who is signed in and the token to call the API with.
class Session {
  final String token;
  final String userId;
  final String name;
  final bool isAdmin;

  const Session({
    required this.token,
    required this.userId,
    required this.name,
    this.isAdmin = false,
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

/// One row of the admin "Users and quotas" table.
class UserQuota {
  final String userId;
  final String name;
  final QuotaInfo quota;

  const UserQuota({
    required this.userId,
    required this.name,
    required this.quota,
  });
}
