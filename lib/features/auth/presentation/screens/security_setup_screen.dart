import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';

class SecuritySetupScreen extends StatefulWidget {
  final AuthSecuritySetupRequired state;

  const SecuritySetupScreen({super.key, required this.state});

  @override
  State<SecuritySetupScreen> createState() => _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends State<SecuritySetupScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  bool _enableBiometric = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _enableBiometric = widget.state.biometricAvailable;
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.security_rounded, size: 56),
                  const SizedBox(height: 14),
                  const Text(
                    'إعداد أمان التطبيق',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'أنشئ رمز PIN لفتح الجلسة بسرعة في المرات القادمة. يمكنك أيضًا تفعيل البصمة إذا كانت متاحة على الجهاز.',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    obscureText: true,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'رمز PIN من 4 إلى 8 أرقام',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _confirmPinController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    obscureText: true,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'تأكيد رمز PIN',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (widget.state.biometricAvailable) ...<Widget>[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _enableBiometric,
                      title: const Text('تفعيل فتح التطبيق بالبصمة'),
                      subtitle: const Text(
                        'سيُطلب التحقق بالبصمة عند الحاجة لحماية الجلسة.',
                      ),
                      onChanged: (value) =>
                          setState(() => _enableBiometric = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('حفظ إعدادات الأمان'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => context.read<AuthCubit>().skipSecuritySetup(),
                    child: const Text('تخطي الآن'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (pin.length < 4 || pin.length > 8 || int.tryParse(pin) == null) {
      _show('يجب أن يتكون رمز PIN من 4 إلى 8 أرقام.');
      return;
    }
    if (confirm != pin) {
      _show('تأكيد رمز PIN غير مطابق.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await context.read<AuthCubit>().completeSecuritySetup(
        pin: pin,
        enableBiometric: _enableBiometric,
      );
    } catch (error) {
      _show(error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _show(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }
}
