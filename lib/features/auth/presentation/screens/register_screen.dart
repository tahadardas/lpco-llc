import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lpco_llc/core/config/app_config.dart';
import 'package:lpco_llc/core/navigation/app_back_scope.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _companyController = TextEditingController();
  final _provinceController = TextEditingController();
  final _phoneCodeController = TextEditingController(text: '+963');
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitted = false;

  void _setControllerText(TextEditingController controller, String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  @override
  void dispose() {
    _companyController.dispose();
    _provinceController.dispose();
    _phoneCodeController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    _submitted = true;
    context.read<AuthCubit>().register(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      firstName: '',
      company: _companyController.text.trim(),
      province: _provinceController.text.trim(),
      phone:
          '${_phoneCodeController.text.trim()}${_phoneController.text.trim()}',
      address: _addressController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackScope(
      fallbackLocation: '/',
      child: Scaffold(
        appBar: AppBar(title: const Text('إنشاء حساب')),
        body: BlocListener<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthError) {
              _applyUsernameSuggestionFromError(state.message);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            if (_submitted && state is Unauthenticated) {
              _submitted = false;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إنشاء الحساب. يمكنك تسجيل الدخول الآن.'),
                  backgroundColor: Colors.green,
                ),
              );
              context.pop();
            }
          },
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _companyController,
                      decoration: const InputDecoration(
                        labelText: 'الاسم التجاري *',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'حقل مطلوب'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _provinceController.text.isEmpty
                          ? null
                          : _provinceController.text,
                      decoration: const InputDecoration(
                        labelText: 'المحافظة *',
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
                        _setControllerText(_provinceController, value ?? '');
                      },
                      validator: (value) =>
                          value == null || value.isEmpty ? 'حقل مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 96,
                          child: TextFormField(
                            controller: _phoneCodeController,
                            decoration: const InputDecoration(labelText: 'رمز'),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'مطلوب'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'رقم الهاتف *',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'حقل مطلوب'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'العنوان *'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'حقل مطلوب'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم المستخدم *',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'حقل مطلوب';
                        }

                        final regex = RegExp(r'^[a-zA-Z0-9._-]+$');
                        if (!regex.hasMatch(value.trim())) {
                          return 'يجب أن يكون بالانجليزية فقط';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور *',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'حقل مطلوب';
                        }
                        if (value.length < 6) {
                          return 'يجب أن تكون 6 أحرف على الأقل';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'تأكيد كلمة المرور *',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'حقل مطلوب';
                        }
                        if (value != _passwordController.text) {
                          return 'كلمتا المرور غير متطابقتين';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    BlocBuilder<AuthCubit, AuthState>(
                      builder: (context, state) {
                        final loading = state is AuthLoading;
                        return FilledButton(
                          onPressed: loading ? null : _submit,
                          child: loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('إنشاء الحساب'),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _applyUsernameSuggestionFromError(String message) {
    final match = RegExp(
      r'\u062c\u0631\u0651\u0628:\s*([a-z0-9._-]+)',
    ).firstMatch(message);
    final suggestion = match?.group(1)?.trim() ?? '';
    if (suggestion.isEmpty) {
      return;
    }
    _setControllerText(_usernameController, suggestion);
  }
}
