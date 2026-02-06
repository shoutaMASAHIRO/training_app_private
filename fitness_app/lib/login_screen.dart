import 'package:flutter/material.dart';
import 'package:fitness_app/services/database_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();

  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _login() async {
    debugPrint('LOGIN: tapped');

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      if (username.isEmpty || password.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter username and password.';
        });
        return;
      }

      final success = await _dbService.login(username, password);

      if (!mounted) return;

      if (success) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() {
          _errorMessage = 'Invalid username or password.';
        });
      }
    } catch (e, st) {
      debugPrint('LOGIN: exception=$e');
      debugPrint('LOGIN: stacktrace=$st');

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Header
                Text(
                  'Sign In',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 32),

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

                // Username Field
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
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
                      decoration: const InputDecoration(
                        hintText: 'Username',
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
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF424242)),
                  decoration: const InputDecoration(
                    hintText: 'Password',
                  ),
                ),
                const SizedBox(height: 32),

                // Sign In Button
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                             backgroundColor: const Color(0xFF00E5FF),
                          ),
                          child: const Text(
                            'SIGN IN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 32),

                // Create Account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have Account? ",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/signup');
                      },
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
