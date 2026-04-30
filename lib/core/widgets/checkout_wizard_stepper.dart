import 'package:flutter/material.dart';

import 'package:lpco_llc/core/widgets/glass.dart';

class CheckoutWizardStepper extends StatelessWidget {
  final int currentStep;
  final List<String> steps;

  const CheckoutWizardStepper({
    super.key,
    required this.currentStep,
    this.steps = const ['السلة', 'الشحن', 'الدفع', 'التأكيد'],
  });

  @override
  Widget build(BuildContext context) {
    final clampedStep = currentStep.clamp(1, steps.length);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: GlassStyle.acrylicDecoration(radius: 20),
      child: Column(
        children: [
          Row(
            children: List.generate(steps.length, (index) {
              final stepNum = index + 1;
              final isActive = stepNum == clampedStep;
              final isDone = stepNum < clampedStep;

              return Expanded(
                child: Row(
                  children: [
                    if (index != 0)
                      Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          color: isDone
                              ? GlassStyle.fireRed
                              : const Color(0xFFE1E5EC),
                        ),
                      ),
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: isDone || isActive
                          ? GlassStyle.fireRed
                          : const Color(0xFFE1E5EC),
                      child: isDone
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 15,
                            )
                          : Text(
                              '$stepNum',
                              style: TextStyle(
                                color: isActive
                                    ? Colors.white
                                    : const Color(0xFF5E6676),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(
              steps.length,
              (index) => Expanded(
                child: Text(
                  steps[index],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6F7786),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
