import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';

class UnlockScreen extends StatefulWidget {
  final AuthLocked state;

  const UnlockScreen({super.key, required this.state});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _requestedBiometric = false;

  @override
  void initState() {
    super.initState();
    _scheduleBiometricPrompt();
  }

  @override
  void didUpdateWidget(covariant UnlockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final userChanged = oldWidget.state.userScope != widget.state.userScope;
    final requirementChanged =
        oldWidget.state.requirement.requiresBiometric !=
            widget.state.requirement.requiresBiometric ||
        oldWidget.state.requirement.canUseBiometric !=
            widget.state.requirement.canUseBiometric;
    final errorCleared =
        oldWidget.state.errorMessage.isNotEmpty &&
        widget.state.errorMessage.isEmpty;

    if (userChanged || requirementChanged || errorCleared) {
      _requestedBiometric = false;
      _scheduleBiometricPrompt();
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requirement = widget.state.requirement;
    final displayName = widget.state.user.displayName.trim().isEmpty
        ? widget.state.user.username
        : widget.state.user.displayName.trim();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.lock_rounded, size: 56),
                  const SizedBox(height: 14),
                  Text(
                    'مرحبًا بعودتك، $displayName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'افتح الجلسة للمتابعة إلى التطبيق.',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.5),
                  ),
                  if (widget.state.errorMessage.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    _messageBox(
                      text: widget.state.errorMessage,
                      color: const Color(0xFFD31225),
                      background: const Color(0xFFFFEBEE),
                    ),
                  ],
                  if (requirement.inLockout &&
                      requirement.lockoutUntil != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _messageBox(
                      text:
                          'تم إيقاف رمز PIN مؤقتًا حتى ${_formatLockout(requirement.lockoutUntil!)}',
                      color: const Color(0xFFD31225),
                      background: const Color(0xFFFFF3F3),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (requirement.canUseBiometric)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () =>
                            context.read<AuthCubit>().unlockWithBiometric(),
                        icon: const Icon(Icons.fingerprint_rounded),
                        label: Text(
                          requirement.requiresBiometric
                              ? 'استخدام البصمة مطلوب'
                              : 'فتح بالبصمة',
                        ),
                      ),
                    ),
                  if (requirement.canUseBiometric && requirement.canUsePin)
                    const SizedBox(height: 12),
                  if (requirement.canUsePin)
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      obscureText: true,
                      maxLength: 8,
                      enabled: !requirement.inLockout,
                      decoration: const InputDecoration(
                        labelText: 'رمز PIN',
                        hintText: 'أدخل رمز PIN',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _submitPin(context),
                    ),
                  if (requirement.canUsePin)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: requirement.inLockout
                            ? null
                            : () => _submitPin(context),
                        child: const Text('فتح برمز PIN'),
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => context.read<AuthCubit>().logout(),
                    child: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _messageBox({
    required String text,
    required Color color,
    required Color background,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  void _scheduleBiometricPrompt() {
    final requirement = widget.state.requirement;
    if (_requestedBiometric ||
        !requirement.requiresBiometric ||
        !requirement.canUseBiometric ||
        widget.state.errorMessage.trim().isNotEmpty) {
      return;
    }

    _requestedBiometric = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AuthCubit>().unlockWithBiometric();
    });
  }

  void _submitPin(BuildContext context) {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      return;
    }
    context.read<AuthCubit>().unlockWithPin(pin);
    _pinController.clear();
  }

  String _formatLockout(DateTime dateTime) {
    return DateFormat('yyyy/MM/dd - HH:mm').format(dateTime.toLocal());
  }
}
