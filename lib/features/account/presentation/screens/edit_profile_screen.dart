import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lpco_llc/core/config/app_config.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _companyController;
  late final TextEditingController _provinceController;
  late final TextEditingController _phoneCodeController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

   bool _initialized = false;
  bool _submitted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final auth = context.read<AuthCubit>().state;
      if (auth is Authenticated) {
        final user = auth.user;
        _companyController = TextEditingController(text: user.companyName);
        _provinceController = TextEditingController(text: user.city);
        
        // Handle phone splitting if possible, or just put it in the phone field
        String phoneCode = '+963';
        String phoneNum = user.phone;
        if (user.phone.startsWith('+')) {
          // Semi-naive split: assume code is +963 (4 digits)
          if (user.phone.startsWith('+963') && user.phone.length > 4) {
            phoneCode = '+963';
            phoneNum = user.phone.substring(4);
          }
        }
        
        _phoneCodeController = TextEditingController(text: phoneCode);
        _phoneController = TextEditingController(text: phoneNum);
        _addressController = TextEditingController(text: user.address);
      } else {
        _companyController = TextEditingController();
        _provinceController = TextEditingController();
        _phoneCodeController = TextEditingController(text: '+963');
        _phoneController = TextEditingController();
        _addressController = TextEditingController();
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _provinceController.dispose();
    _phoneCodeController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _submitted = true;
    });

    context.read<AuthCubit>().updateProfile(
          company: _companyController.text.trim(),
          province: _provinceController.text.trim(),
          phone: '${_phoneCodeController.text.trim()}${_phoneController.text.trim()}',
          address: _addressController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          _submitted = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        } else if (_submitted && state is Authenticated) {
          _submitted = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث البيانات بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تحديث بيانات المستخدم'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'تعديل المعلومات الشخصية',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _companyController,
                    decoration: const InputDecoration(
                      labelText: 'الاسم التجاري *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'حقل مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _provinceController.text.isEmpty
                        ? null
                        : _provinceController.text,
                    decoration: const InputDecoration(
                      labelText: 'المحافظة *',
                      border: OutlineInputBorder(),
                    ),
                    items: AppStaticData.provinces
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _provinceController.text = value ?? '';
                      });
                    },
                    validator: (value) =>
                        value == null || value.isEmpty ? 'حقل مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: TextFormField(
                          controller: _phoneCodeController,
                          decoration: const InputDecoration(
                            labelText: 'الرمز',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty ? 'مطلوب' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'رقم الهاتف *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'حقل مطلوب'
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'العنوان بالتفصيل *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'حقل مطلوب' : null,
                  ),
                  const SizedBox(height: 32),
                  BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, state) {
                      final isLoading = state is AuthLoading;
                      return FilledButton(
                        onPressed: isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'حفظ التغييرات',
                                style: TextStyle(fontSize: 16),
                              ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
