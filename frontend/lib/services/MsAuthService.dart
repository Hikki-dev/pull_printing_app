import 'package:msal_flutter/msal_flutter.dart';
import 'package:flutter/foundation.dart';

class MsAuthService {
  late final PublicClientApplication _pca;

  Future<void> init() async {
    _pca = await PublicClientApplication.createPublicClientApplication(
      '880bec29-de8b-49b2-9911-e12da787f3f1',
      authority:
          'https://login.microsoftonline.com/e0cb52e9-ea0c-4e1b-96e0-ada23537ba49',
      redirectUri: 'msal880bec29-de8b-49b2-9911-e12da787f3f1://auth',
    );
  }

  Future<String?> login() async {
    try {
      final token = await _pca.acquireToken(['User.Read']);
      return token; // Access token
    } catch (e) {
      debugPrint('Login failed: $e');
      return null;
    }
  }
}
