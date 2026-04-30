import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/features/admin/data/models/admin_models.dart';
import 'package:lpco_llc/features/admin/data/repositories/admin_repository.dart';
import 'package:lpco_llc/features/admin/presentation/widgets/admin_module_widgets.dart';

class AdminHomeBannerScreen extends StatefulWidget {
  const AdminHomeBannerScreen({super.key});

  @override
  State<AdminHomeBannerScreen> createState() => _AdminHomeBannerScreenState();
}

class _AdminHomeBannerScreenState extends State<AdminHomeBannerScreen> {
  final AdminRepository _repository = AdminRepository();
  late Future<AdminHomeBannerModel> _future;

  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _buttonLabelController = TextEditingController();
  final TextEditingController _buttonLinkController = TextEditingController();
  final TextEditingController _productIdsController = TextEditingController();

  bool _enabled = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AdminHomeBannerModel> _load() async {
    final banner = await _repository.fetchHomeBanner();
    _enabled = banner.enabled;
    _imageController.text = banner.imageUrl;
    _titleController.text = banner.title;
    _subtitleController.text = banner.subtitle;
    _buttonLabelController.text = banner.buttonLabel;
    _buttonLinkController.text = banner.buttonLink;
    _productIdsController.text = banner.productIds.join(', ');
    return banner;
  }

  @override
  void dispose() {
    _imageController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _buttonLabelController.dispose();
    _buttonLinkController.dispose();
    _productIdsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repository.updateHomeBanner(
        AdminHomeBannerModel(
          enabled: _enabled,
          imageId: 0,
          imageUrl: _imageController.text.trim(),
          title: _titleController.text.trim(),
          subtitle: _subtitleController.text.trim(),
          buttonLabel: _buttonLabelController.text.trim(),
          buttonLink: _buttonLinkController.text.trim(),
          productIds: _productIdsController.text
              .split(',')
              .map((value) => int.tryParse(value.trim()) ?? 0)
              .where((value) => value > 0)
              .toList(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ البانر بنجاح.')));
    } catch (error) {
      if (!mounted) return;
      final safeMessage = ApiContract.safeMessageFromException(
        error,
        fallback: 'تعذر حفظ البانر حالياً. يرجى إعادة المحاولة.',
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
      title: 'بانر الرئيسية',
      body: FutureBuilder<AdminHomeBannerModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final safeMessage = ApiContract.safeMessageFromException(
              snapshot.error ?? const FormatException('unknown'),
              fallback: 'تعذر تحميل البانر حالياً. يرجى إعادة المحاولة.',
            );
            return AdminScreenError(
              message: safeMessage,
              onRetry: () => setState(() => _future = _load()),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 92, 16, 24),
            children: <Widget>[
              AdminSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                      title: const Text('تفعيل البانر'),
                    ),
                    TextField(
                      controller: _imageController,
                      decoration: const InputDecoration(
                        labelText: 'رابط الصورة',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'العنوان'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _subtitleController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'الوصف'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _buttonLabelController,
                      decoration: const InputDecoration(labelText: 'نص الزر'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _buttonLinkController,
                      decoration: const InputDecoration(labelText: 'رابط الزر'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _productIdsController,
                      decoration: const InputDecoration(
                        labelText: 'معرفات المنتجات',
                        hintText: '12, 34, 56',
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ البانر'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AdminHomeLayoutScreen extends StatefulWidget {
  const AdminHomeLayoutScreen({super.key});

  @override
  State<AdminHomeLayoutScreen> createState() => _AdminHomeLayoutScreenState();
}

class _AdminHomeLayoutScreenState extends State<AdminHomeLayoutScreen> {
  final AdminRepository _repository = AdminRepository();
  late Future<AdminHomeLayoutModel> _future;

  String _version = '1.0.0';
  int _cacheTtl = 3600;
  List<Map<String, dynamic>> _sections = <Map<String, dynamic>>[];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AdminHomeLayoutModel> _load() async {
    final layout = await _repository.fetchHomeLayout();
    _version = layout.version;
    _cacheTtl = layout.cacheTtl;
    _sections = layout.sections
        .map((section) => Map<String, dynamic>.from(section))
        .toList();
    return layout;
  }

  void _addSection() {
    setState(() {
      _sections.add(<String, dynamic>{'type': 'products', 'title': 'قسم جديد'});
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repository.updateHomeLayout(
        AdminHomeLayoutModel(
          version: _version,
          cacheTtl: _cacheTtl,
          sections: _sections,
          raw: '',
          updatedAt: '',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ تخطيط الصفحة الرئيسية.')),
      );
    } catch (error) {
      if (!mounted) return;
      final safeMessage = ApiContract.safeMessageFromException(
        error,
        fallback: 'تعذر حفظ تخطيط الصفحة حالياً. يرجى إعادة المحاولة.',
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
      title: 'تخطيط الرئيسية',
      floatingActionButton: FloatingActionButton(
        onPressed: _addSection,
        child: const Icon(Icons.add_rounded),
      ),
      body: FutureBuilder<AdminHomeLayoutModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final safeMessage = ApiContract.safeMessageFromException(
              snapshot.error ?? const FormatException('unknown'),
              fallback: 'تعذر تحميل التخطيط حالياً. يرجى إعادة المحاولة.',
            );
            return AdminScreenError(
              message: safeMessage,
              onRetry: () => setState(() => _future = _load()),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 92, 16, 24),
            children: <Widget>[
              AdminSectionCard(
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: TextEditingController(text: _version),
                      onChanged: (value) => _version = value.trim(),
                      decoration: const InputDecoration(labelText: 'الإصدار'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: TextEditingController(text: '$_cacheTtl'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          _cacheTtl = int.tryParse(value.trim()) ?? 3600,
                      decoration: const InputDecoration(labelText: 'Cache TTL'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ..._sections.asMap().entries.map((entry) {
                final index = entry.key;
                final section = entry.value;
                final typeController = TextEditingController(
                  text: '${section['type'] ?? ''}',
                );
                final titleController = TextEditingController(
                  text: '${section['title'] ?? ''}',
                );
                final jsonController = TextEditingController(
                  text: const JsonEncoder.withIndent('  ').convert(section),
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AdminSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'القسم ${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  setState(() => _sections.removeAt(index)),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                        TextField(
                          controller: typeController,
                          onChanged: (value) => section['type'] = value.trim(),
                          decoration: const InputDecoration(labelText: 'النوع'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: titleController,
                          onChanged: (value) => section['title'] = value.trim(),
                          decoration: const InputDecoration(
                            labelText: 'العنوان',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: jsonController,
                          minLines: 4,
                          maxLines: 8,
                          onChanged: (value) {
                            try {
                              final decoded = jsonDecode(value);
                              if (decoded is Map<String, dynamic>) {
                                _sections[index] = decoded;
                              } else if (decoded is Map) {
                                _sections[index] = Map<String, dynamic>.from(
                                  decoded,
                                );
                              }
                            } catch (_) {}
                          },
                          decoration: const InputDecoration(
                            labelText: 'بيانات القسم',
                            hintText: '{"type":"products","title":"قسم"}',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_rounded),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ التخطيط'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AdminAppThemeScreen extends StatefulWidget {
  const AdminAppThemeScreen({super.key});

  @override
  State<AdminAppThemeScreen> createState() => _AdminAppThemeScreenState();
}

class _AdminAppThemeScreenState extends State<AdminAppThemeScreen> {
  final AdminRepository _repository = AdminRepository();
  late Future<AdminThemeModel> _future;

  bool _enabled = true;
  Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AdminThemeModel> _load() async {
    final theme = await _repository.fetchAppTheme();
    _enabled = theme.enabled;
    _controllers = {
      for (final entry in theme.colors.entries)
        entry.key: TextEditingController(text: entry.value),
    };
    return theme;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repository.updateAppTheme(
        AdminThemeModel(
          enabled: _enabled,
          colors: {
            for (final entry in _controllers.entries)
              entry.key: entry.value.text.trim(),
          },
          updatedAt: '',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ الثيم بنجاح.')));
    } catch (error) {
      if (!mounted) return;
      final safeMessage = ApiContract.safeMessageFromException(
        error,
        fallback: 'تعذر حفظ الثيم حالياً. يرجى إعادة المحاولة.',
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
      title: 'ثيم التطبيق',
      body: FutureBuilder<AdminThemeModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final safeMessage = ApiContract.safeMessageFromException(
              snapshot.error ?? const FormatException('unknown'),
              fallback: 'تعذر تحميل الثيم حالياً. يرجى إعادة المحاولة.',
            );
            return AdminScreenError(
              message: safeMessage,
              onRetry: () => setState(() => _future = _load()),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 92, 16, 24),
            children: <Widget>[
              AdminSectionCard(
                child: Column(
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                      title: const Text('تفعيل الثيم'),
                    ),
                    const SizedBox(height: 10),
                    ..._controllers.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: entry.value,
                          decoration: InputDecoration(labelText: entry.key),
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الثيم'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AdminPopupConfigScreen extends StatefulWidget {
  const AdminPopupConfigScreen({super.key});

  @override
  State<AdminPopupConfigScreen> createState() => _AdminPopupConfigScreenState();
}

class _AdminPopupConfigScreenState extends State<AdminPopupConfigScreen> {
  final AdminRepository _repository = AdminRepository();
  late Future<AdminPopupConfigModel> _future;

  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  bool _enabled = false;
  String _actionType = 'none';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AdminPopupConfigModel> _load() async {
    final popup = await _repository.fetchPopupConfig();
    _enabled = popup.enabled;
    _imageController.text = popup.imageUrl;
    _valueController.text = popup.actionValue;
    _actionType = popup.actionType;
    return popup;
  }

  @override
  void dispose() {
    _imageController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repository.updatePopupConfig(
        AdminPopupConfigModel(
          enabled: _enabled,
          imageUrl: _imageController.text.trim(),
          actionType: _actionType,
          actionValue: _valueController.text.trim(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات النافذة المنبثقة.')),
      );
    } catch (error) {
      if (!mounted) return;
      final safeMessage = ApiContract.safeMessageFromException(
        error,
        fallback: 'تعذر حفظ النافذة المنبثقة حالياً. يرجى إعادة المحاولة.',
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
      title: 'النافذة المنبثقة',
      body: FutureBuilder<AdminPopupConfigModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final safeMessage = ApiContract.safeMessageFromException(
              snapshot.error ?? const FormatException('unknown'),
              fallback:
                  'تعذر تحميل إعدادات النافذة المنبثقة حالياً. يرجى إعادة المحاولة.',
            );
            return AdminScreenError(
              message: safeMessage,
              onRetry: () => setState(() => _future = _load()),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 92, 16, 24),
            children: <Widget>[
              AdminSectionCard(
                child: Column(
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                      title: const Text('تفعيل الإعلان المنبثق'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _imageController,
                      decoration: const InputDecoration(
                        labelText: 'رابط الصورة',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _actionType,
                      decoration: const InputDecoration(
                        labelText: 'نوع الإجراء',
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                          value: 'none',
                          child: Text('بدون إجراء'),
                        ),
                        DropdownMenuItem(value: 'product', child: Text('منتج')),
                        DropdownMenuItem(
                          value: 'category',
                          child: Text('تصنيف'),
                        ),
                        DropdownMenuItem(
                          value: 'url',
                          child: Text('رابط خارجي'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _actionType = value ?? 'none'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _valueController,
                      decoration: const InputDecoration(
                        labelText: 'قيمة الإجراء',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الإعدادات'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AdminOrderingScreen extends StatefulWidget {
  const AdminOrderingScreen({super.key});

  @override
  State<AdminOrderingScreen> createState() => _AdminOrderingScreenState();
}

class _AdminOrderingScreenState extends State<AdminOrderingScreen> {
  final AdminRepository _repository = AdminRepository();
  late Future<AdminOrderingConfigModel> _future;
  AdminOrderingConfigModel? _current;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AdminOrderingConfigModel> _load() async {
    final config = await _repository.fetchOrderingConfig();
    _current = config;
    return config;
  }

  List<T> _ordered<T>(
    List<T> allItems,
    List<int> orderedIds,
    int Function(T item) idOf,
  ) {
    final orderMap = {
      for (var i = 0; i < orderedIds.length; i++) orderedIds[i]: i,
    };
    final sorted = [...allItems];
    sorted.sort((a, b) {
      final aOrder = orderMap[idOf(a)] ?? 9999;
      final bOrder = orderMap[idOf(b)] ?? 9999;
      return aOrder.compareTo(bOrder);
    });
    return sorted;
  }

  Future<void> _save() async {
    final config = _current;
    if (config == null) return;
    setState(() => _saving = true);
    try {
      final saved = await _repository.updateOrderingConfig(config);
      if (mounted) {
        setState(() {
          _current = config.copyWith(updatedAt: saved.updatedAt);
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ ترتيب الواجهة بنجاح.')),
      );
    } catch (error) {
      if (!mounted) return;
      final safeMessage = ApiContract.safeMessageFromException(
        error,
        fallback: 'تعذر حفظ ترتيب الواجهة حالياً. يرجى إعادة المحاولة.',
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
      title: 'ترتيب الواجهة',
      body: FutureBuilder<AdminOrderingConfigModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final safeMessage = ApiContract.safeMessageFromException(
              snapshot.error ?? const FormatException('unknown'),
              fallback: 'تعذر تحميل الترتيب حالياً. يرجى إعادة المحاولة.',
            );
            return AdminScreenError(
              message: safeMessage,
              onRetry: () => setState(() => _future = _load()),
            );
          }

          final config = _current ?? snapshot.data;
          if (config == null) {
            return const AdminScreenEmpty(label: 'لا توجد بيانات ترتيب.');
          }

          final orderedCategories = _ordered<AdminTermModel>(
            config.availableCategories,
            config.categories,
            (item) => item.id,
          );
          final orderedBrands = _ordered<AdminTermModel>(
            config.availableBrands,
            config.brands,
            (item) => item.id,
          );
          final orderedProducts = _ordered<AdminProductOrderOptionModel>(
            config.availableFeaturedProducts,
            config.featuredProducts,
            (item) => item.id,
          );
          final categoryLockedHiddenIds = orderedCategories
              .where(
                (item) =>
                    item.hidden && !config.hiddenCategories.contains(item.id),
              )
              .map((item) => item.id)
              .toList(growable: false);
          final brandLockedHiddenIds = orderedBrands
              .where(
                (item) => item.hidden && !config.hiddenBrands.contains(item.id),
              )
              .map((item) => item.id)
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 92, 16, 24),
            children: <Widget>[
              _OrderingSection<AdminTermModel>(
                title: 'ترتيب التصنيفات',
                items: orderedCategories,
                selectedIds: config.categories,
                idOf: (item) => item.id,
                labelOf: (item) => item.name,
                onChanged: (ids) => setState(() {
                  _current = config.copyWith(categories: ids);
                }),
              ),
              const SizedBox(height: 12),
              _VisibilitySection<AdminTermModel>(
                title: 'ظهور التصنيفات داخل التطبيق',
                helperText:
                    'هذا الإعداد يخص التطبيق فقط، ولن يخفي التصنيف من الموقع.',
                items: orderedCategories,
                hiddenIds: config.hiddenCategories,
                lockedHiddenIds: categoryLockedHiddenIds,
                idOf: (item) => item.id,
                labelOf: (item) => item.name,
                onChanged: (hiddenIds) => setState(() {
                  _current = config.copyWith(hiddenCategories: hiddenIds);
                }),
              ),
              const SizedBox(height: 12),
              _OrderingSection<AdminTermModel>(
                title: 'ترتيب العلامات التجارية',
                items: orderedBrands,
                selectedIds: config.brands,
                idOf: (item) => item.id,
                labelOf: (item) => item.name,
                onChanged: (ids) => setState(() {
                  _current = config.copyWith(brands: ids);
                }),
              ),
              const SizedBox(height: 12),
              _VisibilitySection<AdminTermModel>(
                title: 'ظهور العلامات التجارية داخل التطبيق',
                helperText:
                    'يمكنك هنا إخفاء علامات محددة من التطبيق فقط مع إبقائها ظاهرة في الموقع.',
                items: orderedBrands,
                hiddenIds: config.hiddenBrands,
                lockedHiddenIds: brandLockedHiddenIds,
                idOf: (item) => item.id,
                labelOf: (item) => item.name,
                onChanged: (hiddenIds) => setState(() {
                  _current = config.copyWith(hiddenBrands: hiddenIds);
                }),
              ),
              const SizedBox(height: 12),
              _OrderingSection<AdminProductOrderOptionModel>(
                title: 'ترتيب المنتجات المميزة',
                items: orderedProducts,
                selectedIds: config.featuredProducts,
                idOf: (item) => item.id,
                labelOf: (item) => item.name,
                onChanged: (ids) => setState(() {
                  _current = config.copyWith(featuredProducts: ids);
                }),
              ),
              const SizedBox(height: 12),
              if (config.updatedAt.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'آخر تحديث: ${config.updatedAt}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF667085),
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_rounded),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الترتيب'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderingSection<T> extends StatelessWidget {
  const _OrderingSection({
    required this.title,
    required this.items,
    required this.selectedIds,
    required this.idOf,
    required this.labelOf,
    required this.onChanged,
  });

  final String title;
  final List<T> items;
  final List<int> selectedIds;
  final int Function(T item) idOf;
  final String Function(T item) labelOf;
  final ValueChanged<List<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedItems = items
        .where((item) => selectedIds.contains(idOf(item)))
        .toList();
    final unselectedItems = items
        .where((item) => !selectedIds.contains(idOf(item)))
        .toList();

    return AdminSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) {
              final next = [...selectedIds];
              if (newIndex > oldIndex) newIndex -= 1;
              final item = next.removeAt(oldIndex);
              next.insert(newIndex, item);
              onChanged(next);
            },
            children: selectedItems
                .map(
                  (item) => ListTile(
                    key: ValueKey(idOf(item)),
                    leading: const Icon(Icons.drag_handle_rounded),
                    title: Text(labelOf(item)),
                    trailing: IconButton(
                      onPressed: () => onChanged(
                        selectedIds.where((id) => id != idOf(item)).toList(),
                      ),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                  ),
                )
                .toList(),
          ),
          const Divider(height: 24),
          const Text(
            'إضافة عناصر',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...unselectedItems
              .take(12)
              .map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(labelOf(item)),
                  trailing: IconButton(
                    onPressed: () => onChanged([...selectedIds, idOf(item)]),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _VisibilitySection<T> extends StatelessWidget {
  const _VisibilitySection({
    required this.title,
    required this.helperText,
    required this.items,
    required this.hiddenIds,
    this.lockedHiddenIds = const <int>[],
    required this.idOf,
    required this.labelOf,
    required this.onChanged,
  });

  final String title;
  final String helperText;
  final List<T> items;
  final List<int> hiddenIds;
  final List<int> lockedHiddenIds;
  final int Function(T item) idOf;
  final String Function(T item) labelOf;
  final ValueChanged<List<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final hiddenSet = hiddenIds.toSet();
    final lockedHiddenSet = lockedHiddenIds.toSet();
    final effectiveHiddenSet = <int>{...hiddenSet, ...lockedHiddenSet};
    final visibleCount = items
        .where((item) => !effectiveHiddenSet.contains(idOf(item)))
        .length;

    return AdminSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            helperText,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'الظاهر الآن: $visibleCount من ${items.length}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...items.map((item) {
            final id = idOf(item);
            final isLocked = lockedHiddenSet.contains(id);
            final isVisible = !effectiveHiddenSet.contains(id);
            return SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: isVisible,
              title: Text(labelOf(item)),
              subtitle: Text(
                isLocked
                    ? 'مخفي من إعداد آخر'
                    : (isVisible ? 'ظاهر في التطبيق' : 'مخفي من التطبيق'),
              ),
              onChanged: isLocked
                  ? null
                  : (value) {
                      final next = hiddenSet.toSet();
                      if (value) {
                        next.remove(id);
                      } else {
                        next.add(id);
                      }
                      onChanged(
                        items
                            .map(idOf)
                            .where(next.contains)
                            .toList(growable: false),
                      );
                    },
            );
          }),
        ],
      ),
    );
  }
}
