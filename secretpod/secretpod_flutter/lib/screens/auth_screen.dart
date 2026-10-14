import 'package:flutter/material.dart';
import '../state/vault_controller.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller});
  final VaultController controller;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _name = TextEditingController();
  bool _register = false, _busy = false, _obscure = true;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.authenticate(
        email: _email.text,
        password: _password.text,
        name: _register ? _name.text : null,
      );
    } catch (e) {
      if (mounted) setState(() => _error = VaultController.describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, size) {
          final wide = size.maxWidth > 950;
          return Row(
            children: [
              if (wide)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(52),
                    decoration: BoxDecoration(
                      color: context.colors.blueContainer,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Brand(large: true),
                        const Spacer(),
                        Icon(
                          Icons.hub_outlined,
                          size: 72,
                          color: context.colors.blue,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'A home for your\nteam’s secrets.',
                          style: TextStyle(
                            fontSize: 48,
                            height: 1.12,
                            letterSpacing: -2,
                            color: context.colors.ink,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'API keys, environment variables, and credentials.\nOrganized together. Hosted by you.',
                          style: TextStyle(
                            fontSize: 18,
                            height: 1.65,
                            color: context.colors.muted,
                          ),
                        ),
                        const SizedBox(height: 38),
                        const Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _Feature('Encrypted at rest', Icons.lock_outline),
                            _Feature('Built for teams', Icons.people_outline),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          'YOUR INFRASTRUCTURE. YOUR CONTROL.',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.5,
                            color: context.colors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(wide ? 48 : 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!wide) ...[
                              const Brand(large: true),
                              const SizedBox(height: 56),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.successContainer,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                'Your private workspace',
                                style: TextStyle(
                                  color: context.colors.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _register
                                  ? 'Create your account'
                                  : 'Welcome back',
                              style: const TextStyle(
                                fontSize: 32,
                                letterSpacing: -.8,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _register
                                  ? 'Start a shared vault for your organization.'
                                  : 'Sign in to your organization’s vault.',
                              style: TextStyle(
                                color: context.colors.muted,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 32),
                            if (_register) ...[
                              TextFormField(
                                controller: _name,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Your name',
                                ),
                                validator: (s) => (s?.trim().isEmpty ?? true)
                                    ? 'Enter your name.'
                                    : null,
                              ),
                              const SizedBox(height: 18),
                            ],
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email address',
                              ),
                              validator: (s) => (s?.trim().isEmpty ?? true)
                                  ? 'Enter your email.'
                                  : (!RegExp(
                                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                        ).hasMatch(s!.trim())
                                        ? 'Enter a valid email.'
                                        : null),
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                helperText: _register
                                    ? 'At least 12 characters'
                                    : null,
                                suffixIcon: IconButton(
                                  tooltip: _obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              onFieldSubmitted: (_) => _submit(),
                              validator: (s) => (s?.isEmpty ?? true)
                                  ? 'Enter your password.'
                                  : (_register && s!.length < 12
                                        ? 'Use at least 12 characters.'
                                        : null),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 18),
                              ErrorNotice(_error!),
                            ],
                            if (widget.controller.sessionStorageWarning !=
                                null) ...[
                              const SizedBox(height: 18),
                              ErrorNotice(
                                widget.controller.sessionStorageWarning!,
                              ),
                            ],
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: context.colors.ink,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _register
                                            ? 'Create account'
                                            : 'Sign in',
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                        _register = !_register;
                                        _error = null;
                                        _form.currentState?.reset();
                                      }),
                                child: Text(
                                  _register
                                      ? 'Already have an account? Sign in'
                                      : 'New here? Create an account',
                                ),
                              ),
                            ),
                            const SizedBox(height: 36),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.dns_outlined,
                                  size: 16,
                                  color: context.colors.muted,
                                ),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Self-hosted · Powered by Serverpod',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.muted,
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
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _Feature extends StatelessWidget {
  const _Feature(this.label, this.icon);
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: context.colors.raisedPanel.withValues(alpha: .65),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: context.colors.blue, size: 18),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: context.colors.blue, fontSize: 13)),
      ],
    ),
  );
}
