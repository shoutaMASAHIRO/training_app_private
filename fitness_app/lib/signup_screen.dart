import 'package:flutter/material.dart';
import 'package:fitness_app/services/database_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final DatabaseService _dbService = DatabaseService();

  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';

  Future<void> _signup() async {
    debugPrint('SIGNUP: tapped');

    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter username and password.';
        _successMessage = '';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
        _successMessage = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      // ユーザー名の重複確認
      final exists = await _dbService.usernameExists(username);
      if (exists) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Username already exists.';
          });
        }
        return;
      }

      final success = await _dbService.register(username, password);

      if (!mounted) return;

      if (success) {
        setState(() {
          _successMessage = 'Registration successful! Redirecting to login...';
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Registration failed. Please try again.';
        });
      }
    } catch (e, st) {
      debugPrint('SIGNUP: exception=$e');
      debugPrint('SIGNUP: stacktrace=$st');

      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        // The AppBar's foregroundColor is handled by the global theme
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Join us to start your fitness journey!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 48),

                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                      ),
                    ),
                  ),

                if (_successMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _successMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF00ACC1),
                        fontSize: 14,
                      ),
                    ),
                  ),

                TextField(
                  controller: _usernameController,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
                  decoration: const InputDecoration(
                    hintText: 'Username',
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
                  decoration: const InputDecoration(
                    hintText: 'Password',
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
                  decoration: const InputDecoration(
                    hintText: 'Confirm Password',
                  ),
                ),
                const SizedBox(height: 32),

                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _signup,
                          child: const Text('Sign Up'),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
