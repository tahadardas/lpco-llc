import 'package:flutter/material.dart';

class LegalConsentScreen extends StatefulWidget {
  final VoidCallback onAccepted;
  final void Function(BuildContext context) onOpenPrivacyPolicy;
  final void Function(BuildContext context) onOpenTermsOfUse;

  const LegalConsentScreen({
    super.key,
    required this.onAccepted,
    required this.onOpenPrivacyPolicy,
    required this.onOpenTermsOfUse,
  });

  @override
  State<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends State<LegalConsentScreen> {
  bool _isChecked = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                // App Logo
                Center(
                  child: Icon(
                    Icons.gavel_rounded,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Title
                Text(
                  'الموافقة على سياسة الاستخدام',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                
                // Description
                Text(
                  'يرجى قراءة سياسة الخصوصية وشروط الاستخدام قبل متابعة استخدام التطبيق.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 32),

                // Links
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => widget.onOpenPrivacyPolicy(context),
                      child: const Text('سياسة الخصوصية'),
                    ),
                    const Text(' | '),
                    TextButton(
                      onPressed: () => widget.onOpenTermsOfUse(context),
                      child: const Text('شروط الاستخدام'),
                    ),
                  ],
                ),
                const Spacer(),

                // Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _isChecked,
                        onChanged: (value) {
                          setState(() {
                            _isChecked = value ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isChecked = !_isChecked;
                          });
                        },
                        child: Text(
                          'أقرّ بأنني قرأت ووافقت على سياسة الخصوصية وشروط الاستخدام.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                height: 1.4,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Continue Button
                ElevatedButton(
                  onPressed: _isChecked ? widget.onAccepted : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'موافق ومتابعة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
