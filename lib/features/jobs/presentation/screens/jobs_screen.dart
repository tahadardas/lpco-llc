import 'package:flutter/material.dart';
import 'package:lpco_llc/core/config/app_config.dart';
import 'package:lpco_llc/core/navigation/app_back_navigation.dart';
import 'package:lpco_llc/core/navigation/app_back_scope.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/widgets/brand_app_bar.dart';
import 'package:lpco_llc/features/jobs/data/repositories/job_repository.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _province = TextEditingController();
  final _education = TextEditingController();
  final _position = TextEditingController();
  final _experience = TextEditingController();
  final _about = TextEditingController();
  final JobRepository _repository = JobRepository();

  bool _submitting = false;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _province.dispose();
    _education.dispose();
    _position.dispose();
    _experience.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _submitting = true);
    try {
      await _repository.submitApplication(
        fullName: _fullName.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        province: _province.text.trim(),
        education: _education.text.trim(),
        position: _position.text.trim(),
        experience: _experience.text.trim(),
        about: _about.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب التوظيف بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      _formKey.currentState?.reset();
      _fullName.clear();
      _email.clear();
      _phone.clear();
      _province.clear();
      _education.clear();
      _position.clear();
      _experience.clear();
      _about.clear();
    } catch (e) {
      if (!mounted) return;
      final safeMessage = ApiContract.safeMessageFromException(
        e,
        fallback: 'تعذر إرسال طلب التوظيف حالياً. يرجى إعادة المحاولة.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(safeMessage), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackScope(
      child: Scaffold(
        appBar: BrandAppBar(
          title: 'طلبات التوظيف',
          showBack: true,
          onBack: () => AppBackNavigation.popOrGo(context),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _fullName,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل *',
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني *',
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف *'),
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _province.text.isEmpty ? null : _province.text,
                    decoration: const InputDecoration(labelText: 'المحافظة *'),
                    items: AppStaticData.provinces
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (value) => _province.text = value ?? '',
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _education.text.isEmpty
                        ? null
                        : _education.text,
                    decoration: const InputDecoration(
                      labelText: 'المؤهل العلمي *',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'ثانوية',
                        child: Text('ثانوية عامة'),
                      ),
                      DropdownMenuItem(value: 'معهد', child: Text('معهد متوسط')),
                      DropdownMenuItem(
                        value: 'بكالوريوس',
                        child: Text('بكالوريوس'),
                      ),
                      DropdownMenuItem(value: 'ماجستير', child: Text('ماجستير')),
                      DropdownMenuItem(value: 'دكتوراه', child: Text('دكتوراه')),
                    ],
                    onChanged: (value) => _education.text = value ?? '',
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _position,
                    decoration: const InputDecoration(
                      labelText: 'الوظيفة المطلوبة *',
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _experience,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'سنوات الخبرة'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _about,
                    minLines: 4,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'نبذة عنك *'),
                    validator: _required,
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('إرسال الطلب'),
                  ),
                ],
              ),
            ),
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
