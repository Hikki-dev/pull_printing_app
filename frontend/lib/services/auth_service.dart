class AuthService {
  String? _userId;
  String? _displayName;
  bool _isAdmin = false;

  /// Simulated login: replace with MSAL later
  Future<bool> loginWithAzureAD({required bool asAdmin}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _userId = asAdmin ? 'admin-id' : 'user-id';
    _displayName = asAdmin ? 'Admin User' : 'Regular User';
    _isAdmin = asAdmin;
    return true;
  }

  String? currentUserId() => _userId;
  String? currentUserName() => _displayName;
  bool get isAdmin => _isAdmin;

  Future<String?> getAccessTokenOrNull() async => null; // MSAL token later
}
