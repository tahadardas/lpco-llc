import 'package:flutter/material.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/features/admin/data/models/admin_models.dart';
import 'package:lpco_llc/features/admin/data/repositories/admin_repository.dart';
import 'package:lpco_llc/features/admin/presentation/widgets/admin_module_widgets.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final AdminRepository _repository = AdminRepository();

  late Future<AdminSettingsModel> _future;
  final TextEditingController _exchangeRateController = TextEditingController();
  final TextEditingController _corsController = TextEditingController();
  final TextEditingController _turnstileSiteController =
      TextEditingController();
  final TextEditingController _turnstileSecretController =
      TextEditingController();
  final TextEditingController _recaptchaSiteController =
      TextEditingController();
  final TextEditingController _recaptchaSecretController =
      TextEditingController();
  final TextEditingController _emailsController = TextEditingController();

  String _currency = 'syp';
  bool _allowGuestCheckout = false;
  bool _enableDebugLogs = false;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _exchangeRateController.dispose();
    _corsController.dispose();
    _turnstileSiteController.dispose();
    _turnstileSecretController.dispose();
    _recaptchaSiteController.dispose();
    _recaptchaSecretController.dispose();
    _emailsController.dispose();
    super.dispose();
  }

  Future<AdminSettingsModel> _load() async {
    final settings = await _repository.fetchSettings();
    _apply(settings);
    return settings;
  }

  void _apply(AdminSettingsModel settings) {
    _exchangeRateController.text = settings.exchangeRateUsdSyp.toString();
    _corsController.text = settings.corsAllowedOrigins.join('\n');
    _turnstileSiteController.text = settings.turnstileSiteKey;
    _turnstileSecretController.text = settings.turnstileSecretKey;
    _recaptchaSiteController.text = settings.recaptchaSiteKey;
    _recaptchaSecretController.text = settings.recaptchaSecretKey;
    _emailsController.text = settings.notificationEmails;
    _currency = settings.defaultCurrency;
    _allowGuestCheckout = settings.allowGuestCheckout;
    _enableDebugLogs = settings.enableDebugLogs;
    _dirty = false;
  }

  AdminSettingsModel _current() {
    return AdminSettingsModel(
      exchangeRateUsdSyp: double.tryParse(_exchangeRateController.text) ?? 0,
      defaultCurrency: _currency,
      allowGuestCheckout: _allowGuestCheckout,
      enableDebugLogs: _enableDebugLogs,
      corsAllowedOrigins: _corsController.text
          .split(RegExp(r'[\r\n,]+'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      turnstileSiteKey: _turnstileSiteController.text.trim(),
      turnstileSecretKey: _turnstileSecretController.text.trim(),
      recaptchaSiteKey: _recaptchaSiteController.text.trim(),
      recaptchaSecretKey: _recaptchaSecretController.text.trim(),
      notificationEmails: _emailsController.text.trim(),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await _repository.updateSettings(_current());
      _apply(saved);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات بنجاح.')));
    } catch (error) {
      if (!mounted) return;
      final safeMessage = ApiContract.safeMessageFromException(
        error,
        fallback: 'تعذر حفظ الإعدادات حالياً. يرجى إعادة المحاولة.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(safeMessage)));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminModuleScaffold(
      title: 'إعدادات التطبيق',
      body: FutureBuilder<AdminSettingsModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final safeMessage = ApiContract.safeMessageFromException(
              snapshot.error ?? const FormatException('unknown'),
              fallback: 'تعذر تحميل الإعدادات حالياً. يرجى إعادة المحاولة.',
            );
            return AdminScreenError(
              message: safeMessage,
              onRetry: () => setState(() => _future = _load()),
            );
          }
          if (!snapshot.hasData) {
            return const AdminScreenEmpty(label: 'لا توجد إعدادات متاحة.');
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 92, 16, 24),
            children: <Widget>[
              if (_dirty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AdminSectionCard(
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.info_outline_rounded),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'لديك تغييرات غير محفوظة.',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ'),
                        ),
                      ],
                    ),
                  ),
                ),
              _SettingsSection(
                title: 'إعدادات التجارة',
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: _exchangeRateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() => _dirty = true),
                      decoration: const InputDecoration(
                        labelText: 'سعر الصرف USD/SYP',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: const InputDecoration(
                        labelText: 'العملة الافتراضية',
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(value: 'syp', child: Text('SYP')),
                        DropdownMenuItem(value: 'usd', child: Text('USD')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _currency = value ?? 'syp';
                          _dirty = true;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _allowGuestCheckout,
                      onChanged: (value) {
                        setState(() {
                          _allowGuestCheckout = value;
                          _dirty = true;
                        });
                      },
                      title: const Text('السماح بالشراء كضيف'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SettingsSection(
                title: 'إعدادات الحماية',
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: _turnstileSiteController,
                      onChanged: (_) => setState(() => _dirty = true),
                      decoration: const InputDecoration(
                        labelText: 'Turnstile Site Key',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _turnstileSecretController,
                      onChanged: (_) => setState(() => _dirty = true),
                      decoration: const InputDecoration(
                        labelText: 'Turnstile Secret Key',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _recaptchaSiteController,
                      onChanged: (_) => setState(() => _dirty = true),
                      decoration: const InputDecoration(
                        labelText: 'reCAPTCHA Site Key',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _recaptchaSecretController,
                      onChanged: (_) => setState(() => _dirty = true),
                      decoration: const InputDecoration(
                        labelText: 'reCAPTCHA Secret Key',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SettingsSection(
                title: 'إعدادات التكامل',
                child: TextField(
                  controller: _corsController,
                  minLines: 3,
                  maxLines: 6,
                  onChanged: (_) => setState(() => _dirty = true),
                  decoration: const InputDecoration(
                    labelText: 'CORS Allowed Origins',
                    hintText: 'ضع Origin واحدًا بكل سطر',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SettingsSection(
                title: 'مستلمو التنبيهات',
                child: TextField(
                  controller: _emailsController,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (_) => setState(() => _dirty = true),
                  decoration: const InputDecoration(
                    labelText: 'رسائل البريد الإدارية',
                    hintText: 'admin@example.com, sales@example.com',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SettingsSection(
                title: 'إعدادات التصحيح',
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _enableDebugLogs,
                  onChanged: (value) {
                    setState(() {
                      _enableDebugLogs = value;
                      _dirty = true;
                    });
                  },
                  title: const Text('تفعيل Debug Logs'),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_rounded),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الإعدادات'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AdminSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
