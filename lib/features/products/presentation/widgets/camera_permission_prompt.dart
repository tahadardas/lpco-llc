import 'package:flutter/material.dart';

import 'package:lpco_llc/core/l10n/app_review_strings.dart';

class CameraPermissionPrompt extends StatelessWidget {
  final bool requesting;
  final bool cameraStartFailed;
  final VoidCallback onBack;
  final VoidCallback onManualSearch;
  final VoidCallback onRequestPermission;

  const CameraPermissionPrompt({
    super.key,
    required this.requesting,
    required this.cameraStartFailed,
    required this.onBack,
    required this.onManualSearch,
    required this.onRequestPermission,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppReviewStrings.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            Text(
              cameraStartFailed ? strings.cameraFailure : strings.cameraPurpose,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(onPressed: onBack, child: const Text('رجوع')),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: onManualSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('بحث يدوي'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: requesting ? null : onRequestPermission,
              child: requesting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      cameraStartFailed ? strings.retry : strings.allowCamera,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
