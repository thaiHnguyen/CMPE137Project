import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../auth/validators.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/form_parts.dart';
import 'login_screen.dart';

/// Create an account with an email, username and password (GU-07).
/// The new account is logged in right away
class RegisterScreen extends StatefulWidget {
  /// Creates the sign-up page
  const RegisterScreen({super.key, required this.auth});

  final AuthController auth; // Who is logged in

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String? _error;                       // Not about one field
  Map<String, String> _fieldErrors = {}; 

  @override
  void dispose() {
    _email.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Editing a field clears the server's error on it, e.g. "taken"
  void _edited(String field) {
    if (_fieldErrors.containsKey(field)) {
      setState(() => _fieldErrors = {..._fieldErrors}..remove(field));
    }
  }

  Future<void> _submit() async {
    setState(() => _fieldErrors = {});
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.register(
        email: _email.text,
        username: _username.text,
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        final field = e.field;
        if (field != null) {
          _fieldErrors = {field: e.message}; // e.g. "That email is in use."
        } else {
          _error = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => LoginScreen(auth: widget.auth)),
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
                      'Create account',
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    child: Text(
                      'Vote on moods, rate and review, and keep a watchlist.',
                      style: text.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeSlideIn.staggered(
                    index: 1,
                    child: TextFormField(
                      controller: _email,
                      autocorrect: false,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      validator: checkEmail,
                      onChanged: (_) => _edited('email'),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.mail_outline),
                        errorText: _fieldErrors['email'],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn.staggered(
                    index: 2,
                    child: TextFormField(
                      controller: _username,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.newUsername],
                      textInputAction: TextInputAction.next,
                      validator: checkUsername,
                      onChanged: (_) => _edited('username'),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        helperText: '3-20 letters, digits or underscores',
                        prefixIcon: const Icon(Icons.person_outline),
                        errorText: _fieldErrors['username'],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn.staggered(
                    index: 3,
                    child: PasswordField(
                      controller: _password,
                      isNewPassword: true,
                      validator: checkNewPassword,
                      errorText: _fieldErrors['password'],
                      onChanged: (_) => _edited('password'),
                      onSubmitted: _submit,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FadeSlideIn.staggered(
                    index: 3,
                    child: Text(
                      'At least 8 characters, with a letter and a digit.',
                      style: text.bodySmall,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    FadeSlideIn(child: FormMessage(text: _error!)),
                  ],
                  const SizedBox(height: 24),
                  FadeSlideIn.staggered(
                    index: 4,
                    child: SubmitButton(
                      label: 'Create account',
                      busy: _busy,
                      onPressed: _submit,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn.staggered(
                    index: 5,
                    child: Center(
                      child: TextButton(
                        onPressed: _busy ? null : _openLogin,
                        child: const Text('Already have an account? Log in'),
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
