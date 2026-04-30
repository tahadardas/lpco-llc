import 'package:flutter/material.dart';

import 'package:lpco_llc/core/widgets/glass.dart';

class CheckoutBottomBar extends StatelessWidget {
  final int currentStep;
  final bool disableActions;
  final bool submitting;
  final VoidCallback onBack;
  final VoidCallback onPrimaryAction;

  const CheckoutBottomBar({
    super.key,
    required this.currentStep,
    required this.disableActions,
    required this.submitting,
    required this.onBack,
    required this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: FrostedGlassPanel(
          radius: 30,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              if (currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: disableActions ? null : onBack,
                    child: const Text('السابق'),
                  ),
                ),
              if (currentStep > 0) const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: disableActions ? null : onPrimaryAction,
                  child: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_primaryActionLabel(currentStep)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _primaryActionLabel(int step) {
    switch (step) {
      case 0:
        return 'متابعة إلى الشحن';
      case 1:
        return 'متابعة إلى الدفع';
      case 2:
        return 'مراجعة الطلب';
      case 3:
      default:
        return 'إرسال الطلب';
    }
  }
}
