import 'package:msal_flutter/msal_flutter.dart';

class MsalService {
  late PublicClientApplication _publicClientApplication;
  String? _accessToken;

  Future<void> initialize() async {
    try {
      _publicClientApplication = await PublicClientApplication.createPublicClientApplication(
        '880bec29-de8b-49b2-9911-e12da787f3f1 ', // Replace with your client ID
        // Replace with your authority and redirect URI
        // authority: 'https://login.microsoftonline.com/your-tenant-id', 
        // redirectUri: 'your-redirect-uri',
        authority: 'https://login.microsoftonline.com/common',
        redirectUri: 'your-redirect-uri',
      );
    } catch (e) {
      print('Error initializing MSAL: $e');
    }
  }

  Future<void> signIn() async {
    try {
      // acquireToken now returns a String (access token)
      _accessToken = await _publicClientApplication.acquireToken(['user.read']);
      print('Access Token: $_accessToken');
    } catch (e) {
      print('Error during sign-in: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _publicClientApplication.logout();
      _accessToken = null;
    } catch (e) {
      print('Error during sign-out: $e');
    }
  }

  String? get accessToken => _accessToken;
  String? get clientId => '880bec29-de8b-49b2-9911-e12da787f3f1'; // Replace with your client ID
}
