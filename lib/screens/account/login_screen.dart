import 'package:flutter/material.dart';

import '../../services/auth/account_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import '../../config/device_info.dart';

// Pushed, not a shell tab.
// Returns true via Navigator.pop once actually signed in.
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
      // Get the same device information displayed on the screen.
      final device = await DeviceInfoConfig.getDeviceInfo();

      if (_mode == _Mode.signUp) {
        await AccountService.instance.signUp(
          name: _nameController.text.trim(),
          email: email,
          password: password,
          passwordConfirmation: _confirmController.text,
          deviceName: device.deviceName,
          platform: device.platform,
        );
      } else {
        await AccountService.instance.signIn(
          email: email,
          password: password,
          deviceName: device.deviceName,
          platform: device.platform,
        );
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

          Text(
            'DEVICE NAME',
            style: AppTypography.labelCaps.copyWith(
              color: colors.textSecondary,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'How this phone shows up under Devices',
            style: AppTypography.bodySm.copyWith(color: colors.textSecondary),
          ),

          const SizedBox(height: AppSpacing.sm),

          FutureBuilder<DeviceDetails>(
            future: _deviceInfoFuture,
            builder: (context, snapshot) {
              return TextField(
                readOnly: true,
                controller: TextEditingController(
                  text:
                      snapshot.data?.deviceName ??
                      (snapshot.hasError
                          ? 'Device information unavailable'
                          : 'Detecting device...'),
                ),
                decoration: const InputDecoration(
                  hintText: 'Device name',
                  prefixIcon: Icon(Icons.smartphone),
                ),
              );
            },
          ),

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
                : () => setState(() {
                    _mode = signUp ? _Mode.signIn : _Mode.signUp;
                    _error = null;
                  }),
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
