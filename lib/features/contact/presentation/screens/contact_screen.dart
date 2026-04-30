import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lpco_llc/core/config/app_config.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _message = TextEditingController();

  bool _expandedHours = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submitContact() async {
    if (_formKey.currentState?.validate() != true) return;

    final subject = Uri.encodeComponent('رسالة من تطبيق LPCO');
    final body = Uri.encodeComponent(
      'الاسم: ${_name.text}\n'
      'البريد: ${_email.text}\n'
      'الهاتف: ${_phone.text}\n\n'
      'الرسالة:\n${_message.text}',
    );

    final uri = Uri.parse(
      'mailto:${AppStaticData.contactEmail}?subject=$subject&body=$body',
    );
    final opened = await launchUrl(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح تطبيق البريد')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اتصل بنا')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'لأي استفسار لا تتردد في إرسال رسالة لنا',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('فريقنا متاح للرد على جميع أسئلتكم خلال ساعات العمل.'),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'معلومات التواصل',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      for (final phone in AppStaticData.contactPhones)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.phone),
                          title: Text(phone),
                          trailing: IconButton(
                            icon: const Icon(Icons.chat),
                            onPressed: () => launchUrl(
                              Uri.parse(
                                'https://wa.me/${phone.replaceAll('+', '')}',
                              ),
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                          onTap: () => launchUrl(Uri.parse('tel:$phone')),
                        ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.email_outlined),
                        title: Text(AppStaticData.contactEmail),
                        onTap: () => launchUrl(
                          Uri.parse('mailto:${AppStaticData.contactEmail}'),
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(AppStaticData.contactAddress),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.access_time),
                        title: const Text('ساعات العمل'),
                        subtitle: _expandedHours
                            ? const Text(
                                'السبت - الخميس: 9:00 ص - 6:30 م\nالجمعة: مغلق',
                              )
                            : const Text('اضغط لعرض التفاصيل'),
                        onTap: () =>
                            setState(() => _expandedHours = !_expandedHours),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'أرسل لنا رسالة',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'اسمك *',
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'بريدك الإلكتروني *',
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'هاتفك'),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _message,
                          minLines: 4,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: 'رسالتك *',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length < 10) {
                              return 'الرسالة يجب أن تكون 10 أحرف على الأقل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _submitContact,
                          child: const Text('إرسال الرسالة'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () {
                  launchUrl(
                    Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=Halboni,Syria',
                    ),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text('فتح الموقع على الخريطة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'حقل مطلوب';
    }
    return null;
  }
}
