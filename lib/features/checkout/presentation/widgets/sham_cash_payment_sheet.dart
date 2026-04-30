import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:lpco_llc/core/widgets/app_network_image.dart';
import 'package:lpco_llc/core/widgets/glass.dart';
import 'package:lpco_llc/features/orders/data/models/order_model.dart';

class ShamCashSheetResult {
  final bool confirmed;
  final String transactionId;

  const ShamCashSheetResult._({
    required this.confirmed,
    this.transactionId = '',
  });

  const ShamCashSheetResult.later() : this._(confirmed: false);

  const ShamCashSheetResult.confirmed({String transactionId = ''})
    : this._(confirmed: true, transactionId: transactionId);
}

Future<ShamCashSheetResult?> showShamCashPaymentSheet({
  required BuildContext context,
  required ShamCashPayload shamCash,
  required String amountFormatted,
}) async {
  final paymentCode = shamCash.qrText.isNotEmpty
      ? shamCash.qrText
      : shamCash.account;
  final qrImageUrl = paymentCode.isNotEmpty
      ? 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${Uri.encodeComponent(paymentCode)}&color=dc2626&bgcolor=ffffff'
      : shamCash.qrUrl;

  var transactionId = '';

  return showModalBottomSheet<ShamCashSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          16 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'دفع شام كاش',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: GlassStyle.acrylicDecoration(radius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الشركة: ${shamCash.company}'),
                    const SizedBox(height: 4),
                    Text('المبلغ: $amountFormatted'),
                    const SizedBox(height: 4),
                    Text('المهلة: ${shamCash.timeLimit} دقيقة'),
                  ],
                ),
              ),
              if (qrImageUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE0E4EB)),
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.all(10),
                    child: AppNetworkImage(
                      imageUrl: qrImageUrl,
                      fit: BoxFit.contain,
                      placeholder: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: const Center(
                        child: Icon(Icons.qr_code_2_rounded, size: 36),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(qrImageUrl);
                      if (uri == null) {
                        _showSnack(sheetContext, 'رابط رمز الدفع غير صالح');
                        return;
                      }
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('فتح رمز الدفع'),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: GlassStyle.acrylicDecoration(radius: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'رمز الدفع',
                            style: TextStyle(
                              color: Color(0xFF707887),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          SelectableText(
                            paymentCode,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          if (shamCash.account.isNotEmpty &&
                              shamCash.account != paymentCode) ...[
                            const SizedBox(height: 6),
                            Text(
                              'رقم الحساب: ${shamCash.account}',
                              style: const TextStyle(
                                color: Color(0xFF707887),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: paymentCode),
                        );
                        if (!sheetContext.mounted) {
                          return;
                        }
                        _showSnack(
                          sheetContext,
                          'تم نسخ رمز الدفع',
                          isError: false,
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (value) => transactionId = value.trim(),
                decoration: const InputDecoration(
                  labelText: 'رقم الحوالة (اختياري)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(
                        sheetContext,
                      ).pop(const ShamCashSheetResult.later()),
                      child: const Text('لاحقاً'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        FocusScope.of(sheetContext).unfocus();
                        Navigator.of(sheetContext).pop(
                          ShamCashSheetResult.confirmed(
                            transactionId: transactionId,
                          ),
                        );
                      },
                      child: const Text('تم التحويل'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showSnack(BuildContext context, String message, {bool isError = true}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
    ),
  );
}
