import 'package:flutter/material.dart';
import '../services/MsAuthService.dart';
import 'release_jobs_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _msalService = MsAuthService();
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    final accessToken = await _msalService.login();
    setState(() => _loading = false);

    if (accessToken != null) {
      // Pass the token to the next screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReleaseJobsScreen(accessToken: accessToken),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _login,
                child: const Text('Sign in with Azure AD'),
              ),
      ),
    );
  }
}