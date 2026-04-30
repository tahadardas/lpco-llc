import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lpco_llc/core/security/app_lock_manager.dart';
import 'package:lpco_llc/core/session/session_manager.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final AppLockManager _appLockManager = AppLockManager();
  final SessionManager _sessionManager = SessionManager();

  bool _loading = true;
  String _scope = 'guest';
  bool _hasPin = false;
  bool _biometricAvailable = false;
  AppLockSettings _settings = AppLockSettings.defaults();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthCubit>().currentUser;
    if (user == null || user.isGuest) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    final scope = _sessionManager.buildUserScope(user);
    final settings = await _appLockManager.loadSettings(scope);
    final hasPin = await _appLockManager.hasPin(scope);
    final capability = await _appLockManager.biometricCapability();

    if (!mounted) {
      return;
    }

    setState(() {
      _scope = scope;
      _settings = settings;
      _hasPin = hasPin;
      _biometricAvailable = capability.available;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('App Security')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  title: const Text('Enable app lock'),
                  subtitle: Text(
                    _hasPin
                        ? 'Require unlock after inactivity timeout.'
                        : 'Set a PIN first to enable app lock.',
                  ),
                  value: _settings.appLockEnabled,
                  onChanged: _hasPin
                      ? (value) async {
                          await _appLockManager.setAppLockEnabled(
                            _scope,
                            value,
                          );
                          await _load();
                        }
                      : null,
                ),
                SwitchListTile(
                  title: const Text('Enable biometric unlock'),
                  subtitle: Text(
                    _biometricAvailable
                        ? 'Biometric re-verification required once every 24 hours.'
                        : 'Biometric is unavailable on this device.',
                  ),
                  value: _settings.biometricEnabled,
                  onChanged: (_biometricAvailable && _hasPin)
                      ? (value) async {
                          await _appLockManager.setBiometricEnabled(
                            _scope,
                            value,
                          );
                          await _load();
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _showPinDialog,
            icon: const Icon(Icons.password_rounded),
            label: Text(_hasPin ? 'Change PIN' : 'Set PIN'),
          ),
          const SizedBox(height: 8),
          if (_hasPin)
            OutlinedButton.icon(
              onPressed: () async {
                await _appLockManager.removePin(_scope);
                await _load();
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Remove PIN and disable lock'),
            ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Inactivity timeout'),
              subtitle: Text('${_settings.inactivityTimeoutMinutes} minutes'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPinDialog() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_hasPin ? 'Change PIN' : 'Set PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: 'PIN (4-8 digits)',
                ),
              ),
              TextField(
                controller: confirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 8,
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final pin = pinController.text.trim();
                final confirm = confirmController.text.trim();
                if (pin != confirm ||
                    pin.length < 4 ||
                    int.tryParse(pin) == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Invalid PIN input')),
                    );
                  }
                  return;
                }

                await _appLockManager.configurePin(
                  userScope: _scope,
                  pin: pin,
                  enableAppLock: true,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                await _load();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    pinController.dispose();
    confirmController.dispose();
  }
}
