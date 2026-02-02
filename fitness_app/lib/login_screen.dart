import 'package:fitness_app/services/api_config.dart';
import 'package:flutter/material.dart';
import 'dart:convert'; // For json.encode/decode
import 'package:http/http.dart' as http; // For making HTTP requests

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _login() async {
    // ✅ クリック確認ログ
    debugPrint('LOGIN: tapped -> POST $apiBaseUrl/login');

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final uri = Uri.parse('$apiBaseUrl/login');
      debugPrint('LOGIN: uri=$uri');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _usernameController.text,
          'password': _passwordController.text,
        }),
      );

      debugPrint('LOGIN: status=${response.statusCode}');
      debugPrint('LOGIN: body=${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        String message = 'Login failed. Please try again.';
        try {
          final Map<String, dynamic> responseBody =
              json.decode(response.body) as Map<String, dynamic>;
          message = (responseBody['message'] ?? message).toString();
        } catch (_) {
          // JSONじゃないときは response.body をそのまま表示してもOK
          if (response.body.isNotEmpty) message = response.body;
        }
        setState(() {
          _errorMessage = message;
        });
      }
    } catch (e, st) {
      // ✅ 例外内容を必ず表示（Networkに出ない原因を特定できる）
      debugPrint('LOGIN: exception=$e');
      debugPrint('LOGIN: stacktrace=$st');

      if (mounted) {
        setState(() {
          _errorMessage = 'Network error or server unavailable.';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(
                  Icons.fitness_center,
                  size: 80,
                  color: theme.primaryColor,
                ),
                const SizedBox(height: 16),

                Text(
                  'FitTrackr',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Welcome back!',
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

                // Username Field with Autocomplete
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      return const Iterable<String>.empty();
                    }
                    const options = [
                      'user1@example.com',
                      'user2@example.com',
                      'testuser'
                    ];
                    return options.where((String option) {
                      return option.contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    _usernameController.text = selection;
                  },
                  fieldViewBuilder: (
                    BuildContext context,
                    TextEditingController fieldTextEditingController,
                    FocusNode fieldFocusNode,
                    VoidCallback onFieldSubmitted,
                  ) {
                    return TextField(
                      controller: _usernameController,
                      focusNode: fieldFocusNode,
                      decoration: const InputDecoration(
                        hintText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      keyboardType: TextInputType.text,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 32),

                // Login Button
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _login,
                          child: const Text('Login'),
                        ),
                      ),
                const SizedBox(height: 24),

                // Sign up navigation
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/signup');
                      },
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
