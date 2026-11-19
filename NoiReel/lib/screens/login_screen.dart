import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../auth/validators.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/form_parts.dart';
import 'register_screen.dart';

/// Log in with a username or email and a password (GU-08)
class LoginScreen extends StatefulWidget {
  /// Creates the log in page
  const LoginScreen({super.key, required this.auth});

  final AuthController auth; // Who is logged in

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String? _error; // From the server, e.g. wrong password or locked

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.login(_login.text, _password.text);
      if (!mounted) return;
      // Back to the Profile tab, which now shows the account
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = loginErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openRegister() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RegisterScreen(auth: widget.auth),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('NOIREEL')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                children: [
                  FadeSlideIn(
                    child: Text(
                      'Log in',
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeSlideIn.staggered(
                    index: 1,
                    child: TextFormField(
                      controller: _login,
                      autocorrect: false,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      textInputAction: TextInputAction.next,
                      validator: (v) => checkFilled(v, 'username or email'),
                      decoration: const InputDecoration(
                        labelText: 'Username or email',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn.staggered(
                    index: 2,
                    child: PasswordField(
                      controller: _password,
                      validator: (v) => checkFilled(v, 'password'),
                      onSubmitted: _submit,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    FadeSlideIn(child: FormMessage(text: _error!)),
                  ],
                  const SizedBox(height: 24),
                  FadeSlideIn.staggered(
                    index: 3,
                    child: SubmitButton(
                      label: 'Log in',
                      busy: _busy,
                      onPressed: _submit,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn.staggered(
                    index: 4,
                    child: Center(
                      child: TextButton(
                        onPressed: _busy ? null : _openRegister,
                        child: const Text("Don't have an account? Create one"),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A clear message for a failed log in (GU-08.02-04)
String loginErrorMessage(ApiException e) {
  final reason = e.body['reason'] as String?;
  final until = _shortDate(e.body['until'] as String?);
  return switch (e.error) {
    'suspended' => 'Your account is suspended'
        '${until == null ? '' : ' until $until'}.'
        '${reason == null ? '' : ' Reason: $reason'}',
    'banned' => 'Your account has been banned.'
        '${reason == null ? '' : ' Reason: $reason'}',
    _ => e.message, // incorrect, locked, or the server can't be reached
  };
}

/// "2026-12-01 18:30:00" -> "2026-12-01 18:30"
String? _shortDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return value.length >= 16 ? value.substring(0, 16) : value;
}
