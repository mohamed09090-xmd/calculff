import 'package:flutter/material.dart';

import '../domain/admin_auth_failure.dart';
import 'platform_ui_text.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({
    super.key,
    required this.authenticating,
    required this.onSignIn,
    this.failureCode,
  });

  final bool authenticating;
  final AdminAuthFailureCode? failureCode;
  final Future<void> Function({required String email, required String password})
  onSignIn;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _submitLocked = false;

  bool get _disabled => widget.authenticating || _submitLocked;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? _validateEmail(String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) {
      return platformText(context, 'البريد مطلوب.');
    }
    final isValid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
    if (!isValid) {
      return platformText(context, 'صيغة البريد غير صالحة.');
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return platformText(context, 'كلمة المرور مطلوبة.');
    }
    return null;
  }

  Future<void> _submit() async {
    if (_disabled) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _submitLocked = true);
    try {
      await widget.onSignIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } finally {
      if (mounted) setState(() => _submitLocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failure = widget.failureCode == null
        ? null
        : platformFailureText(context, widget.failureCode);

    return Scaffold(
      appBar: AppBar(title: Text(platformText(context, 'منصة الزبائن'))),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(
                              Icons.admin_panel_settings_outlined,
                              size: 64,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              platformText(context, 'تسجيل دخول المدير'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Semantics(
                              textField: true,
                              label: platformText(context, 'البريد'),
                              child: TextFormField(
                                key: const Key('platform-email-field'),
                                controller: _emailController,
                                enabled: !_disabled,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: InputDecoration(
                                  labelText: platformText(context, 'البريد'),
                                  prefixIcon: const Icon(Icons.email_outlined),
                                ),
                                validator: _validateEmail,
                                onFieldSubmitted: (_) =>
                                    _passwordFocusNode.requestFocus(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Semantics(
                              textField: true,
                              label: platformText(context, 'كلمة المرور'),
                              child: TextFormField(
                                key: const Key('platform-password-field'),
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                enabled: !_disabled,
                                obscureText: _obscurePassword,
                                keyboardType: TextInputType.visiblePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: InputDecoration(
                                  labelText: platformText(
                                    context,
                                    'كلمة المرور',
                                  ),
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: Semantics(
                                    button: true,
                                    label: platformText(
                                      context,
                                      _obscurePassword
                                          ? 'إظهار كلمة المرور'
                                          : 'إخفاء كلمة المرور',
                                    ),
                                    child: IconButton(
                                      key: const Key(
                                        'platform-password-visibility',
                                      ),
                                      tooltip: platformText(
                                        context,
                                        _obscurePassword
                                            ? 'إظهار كلمة المرور'
                                            : 'إخفاء كلمة المرور',
                                      ),
                                      onPressed: _disabled
                                          ? null
                                          : () => setState(
                                              () => _obscurePassword =
                                                  !_obscurePassword,
                                            ),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                ),
                                validator: _validatePassword,
                                onFieldSubmitted: (_) => _submit(),
                              ),
                            ),
                            if (failure != null) ...[
                              const SizedBox(height: 16),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  failure,
                                  key: const Key('platform-login-error'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Semantics(
                              button: true,
                              label: platformText(context, 'دخول'),
                              child: FilledButton.icon(
                                key: const Key('platform-sign-in-button'),
                                onPressed: _disabled ? null : _submit,
                                icon: widget.authenticating
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.login),
                                label: Text(
                                  platformText(
                                    context,
                                    widget.authenticating
                                        ? 'جاري تسجيل الدخول...'
                                        : 'دخول',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
