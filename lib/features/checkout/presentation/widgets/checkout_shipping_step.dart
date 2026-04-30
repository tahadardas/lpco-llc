import 'package:flutter/material.dart';

import 'package:lpco_llc/core/widgets/glass.dart';

class CheckoutShippingStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController cityController;
  final TextEditingController stateController;
  final TextEditingController emailController;
  final TextEditingController notesController;
  final bool detectingLocation;
  final double? latitude;
  final double? longitude;
  final Future<void> Function() onUseCurrentLocation;
  final String? Function(String?) requiredValidator;

  const CheckoutShippingStep({
    super.key,
    required this.formKey,
    required this.fullNameController,
    required this.phoneController,
    required this.addressController,
    required this.cityController,
    required this.stateController,
    required this.emailController,
    required this.notesController,
    required this.detectingLocation,
    required this.latitude,
    required this.longitude,
    required this.onUseCurrentLocation,
    required this.requiredValidator,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: GlassStyle.acrylicDecoration(radius: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'بيانات الشحن',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            const SizedBox(height: 6),
            const Text(
              'أدخل بيانات الاستلام بدقة، ويمكنك تعبئة العنوان من GPS.',
              style: TextStyle(
                color: Color(0xFF707887),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: detectingLocation ? null : onUseCurrentLocation,
                    icon: detectingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                    label: const Text('استخدام موقعي الحالي'),
                  ),
                ),
              ],
            ),
            if (latitude != null && longitude != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'GPS: ${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}',
                  style: const TextStyle(
                    color: Color(0xFF707887),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'البيانات الأساسية',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: fullNameController,
              decoration: const InputDecoration(labelText: 'الاسم الكامل *'),
              validator: requiredValidator,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف *'),
              validator: requiredValidator,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: addressController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'عنوان الشحن *'),
              validator: requiredValidator,
            ),
            const SizedBox(height: 12),
            const Text(
              'تفاصيل إضافية',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: cityController,
              decoration: const InputDecoration(labelText: 'المدينة'),
              validator: requiredValidator,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: stateController,
              decoration: const InputDecoration(labelText: 'المحافظة'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: notesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'ملاحظات الطلب'),
            ),
          ],
        ),
      ),
    );
  }
}
