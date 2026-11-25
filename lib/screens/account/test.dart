import 'package:flutter/material.dart';

import '../../config/device_info.dart';
import '../../services/auth/account_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Mode { signIn, signUp }

class _LoginScreenState extends State<LoginScreen> {
  _Mode _mode = _Mode.signIn;

  bool _working = false;
  String? _error;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  late Future<DeviceDetails> _deviceInfoFuture;

  @override
  void initState() {
    super.initState();
    _deviceInfoFuture = DeviceInfoConfig.getDeviceInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Fill in every field.');
      return;
    }

    if (_mode == _Mode.signUp && _nameController.text.trim().isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }

    if (_mode == _Mode.signUp && password != _confirmController.text) {
      setState(() => _error = "Passwords don't match.");
      return;
    }

    setState(() {
      _working = true;
      _error = null;
    });

    try {
      if (_mode == _Mode.signUp) {
        await AccountService.instance.signUp(
          name: _nameController.text.trim(),
          email: email,
          password: password,
          passwordConfirmation: _confirmController.text,
        );
      } else {
        await AccountService.instance.signIn(email: email, password: password);
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _working = false;
        _error = describeAuthError(e);
      });
    }
  }

  Widget _buildDeviceInfo() {
    final colors = context.colors;

    return FutureBuilder<DeviceDetails>(
      future: _deviceInfoFuture,
      builder: (context, snapshot) {
        final device = snapshot.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR DEVICE',
              style: AppTypography.labelCaps.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This device will be registered with your account',
              style: AppTypography.bodySm.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: colors.borderSubtle),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.smartphone,
                    color: colors.onSurfaceVariant,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          snapshot.connectionState == ConnectionState.waiting
                              ? 'Detecting device...'
                              : snapshot.hasError
                              ? 'Device information unavailable'
                              : device?.deviceName ?? 'Unknown device',
                          style: AppTypography.bodyMd.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        if (device != null)
                          Text(
                            '${device.platform.toUpperCase()} • ${device.osVersion}',
                            style: AppTypography.bodySm.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.verified_outlined, color: colors.primary),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final signUp = _mode == _Mode.signUp;

    return Scaffold(
      appBar: AppBar(title: Text(signUp ? 'Create account' : 'Sign in')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (signUp) ...[
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(hintText: 'Name'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(hintText: 'Email'),
          ),

          const SizedBox(height: AppSpacing.sm),

          TextField(
            controller: _passwordController,
            obscureText: true,
            autofillHints: [
              signUp ? AutofillHints.newPassword : AutofillHints.password,
            ],
            decoration: const InputDecoration(hintText: 'Password'),
          ),

          if (signUp) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Confirm password'),
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // Automatically detected, read-only device information.
          _buildDeviceInfo(),

          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: AppTypography.bodySm.copyWith(color: colors.error),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          ElevatedButton(
            onPressed: _working ? null : _submit,
            child: _working
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(signUp ? 'Create account' : 'Sign in'),
          ),

          const SizedBox(height: AppSpacing.sm),

          TextButton(
            onPressed: _working
                ? null
                : () {
                    setState(() {
                      _mode = signUp ? _Mode.signIn : _Mode.signUp;
                      _error = null;
                    });
                  },
            child: Text(
              signUp
                  ? 'Already have an account? Sign in'
                  : "Don't have an account? Create one",
            ),
          ),
        ],
      ),
    );
  }
}
