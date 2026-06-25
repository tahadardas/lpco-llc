import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/features/admin/data/models/admin_models.dart';
import 'package:lpco_llc/features/admin/data/repositories/admin_repository.dart';
import 'package:lpco_llc/features/admin/presentation/widgets/admin_module_widgets.dart';
import 'package:lpco_llc/features/products/presentation/cubit/product_cubit.dart';

class AdminHomeBannerScreen extends StatefulWidget {
  const AdminHomeBannerScreen({super.key});

  @override
  State<AdminHomeBannerScreen> createState() => _AdminHomeBannerScreenState();
}

class _AdminHomeBannerScreenState extends State<AdminHomeBannerScreen> {
  final AdminRepository _repository = AdminRepository();
  late Future<AdminHomeBannersModel> _future;

  List<AdminHomeBannerItemModel> _banners = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AdminHomeBannersModel> _load() async {
    final model = await _repository.fetchHomeBanners();
    setState(() {
      _banners = List.from(model.items);
      _banners.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    });
    return model;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Re-assign sortOrder based on list position
      final updatedList = <AdminHomeBannerItemModel>[];
      for (int i = 0; i < _banners.length; i++) {
        final b = _banners[i];
        updatedList.add(
          AdminHomeBannerItemModel(
            id: b.id,
            enabled: b.enabled,
            imageId: b.imageId,
            imageUrl: b.imageUrl,
            title: b.title,
            subtitle: b.subtitle,
            buttonLabel: b.buttonLabel,
            buttonLink: b.buttonLink,
            actionType: b.actionType,
            actionValue: b.actionValue,
            sortOrder: i,
            startsAt: b.startsAt,
            endsAt: b.endsAt,
            productIds: b.productIds,
            updatedAt: b.updatedAt,
            showTitle: b.showTitle,
            showSubtitle: b.showSubtitle,
            showButton: b.showButton,
            contentAlignment: b.contentAlignment,
            contentVerticalAlignment: b.contentVerticalAlignment,
            imageFit: b.imageFit,
            overlayOpacity: b.overlayOpacity,
            titleColor: b.titleColor,
            subtitleColor: b.subtitleColor,
            buttonBackgroundColor: b.buttonBackgroundColor,
            buttonTextColor: b.buttonTextColor,
          ),
        );
      }

      final saved = await _repository.updateHomeBanners(
        AdminHomeBannersModel(items: updatedList, updatedAt: '', revision: ''),
      );
      if (kDebugMode) {
        debugPrint(
          '[BANNER_ADMIN_SAVE] sent payload ${jsonEncode(updatedList.map((item) => item.toJson()).toList())}',
        );
        debugPrint(
          '[BANNER_ADMIN_SAVE] persisted payload ${jsonEncode(saved.toJson())}',
        );
      }
      final persisted = await _repository.fetchHomeBanners();
      Map<String, dynamic> comparableBanner(AdminHomeBannerItemModel item) {
        final json = item.toJson()..remove('updated_at');
        if ('${json['starts_at'] ?? ''}'.isEmpty) json.remove('starts_at');
        if ('${json['ends_at'] ?? ''}'.isEmpty) json.remove('ends_at');
        return json;
      }

      final expectedJson = updatedList
          .map(comparableBanner)
          .toList(growable: false);
      final persistedJson = persisted.items
          .map(comparableBanner)
          .toList(growable: false);
      if (jsonEncode(expectedJson) != jsonEncode(persistedJson) ||
          saved.revision.isEmpty ||
          persisted.revision != saved.revision) {
        if (kDebugMode) {
          debugPrint('[BANNER_ADMIN_VERIFY] failure');
        }
        throw const FormatException('Banner persistence verification failed');
      }
      if (kDebugMode) {
        debugPrint('[BANNER_ADMIN_VERIFY] success');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ البانرات بنجاح.')));
      setState(() {
        _banners = persisted.items;
      });
    } catch (error) {
      if (!mounted) return;
      final safeMessage = ApiContract.safeMessageFromException(
        error,
        fallback: 'تعذر حفظ البانرات حالياً. يرجى إعادة المحاولة.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(safeMessage)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addBanner() {
    setState(() {
      _banners.insert(
        0,
        AdminHomeBannerItemModel(
          id: 'new_${DateTime.now().millisecondsSinceEpoch}',
          enabled: true,
          imageId: 0,
          imageUrl: '',
          title: 'بانر جديد',
          subtitle: '',
          buttonLabel: 'تسوق الآن',
          actionType: AdminBannerActionType.none,
          buttonLink: '',
          actionValue: '',
          sortOrder: 0,
          productIds: const [],
          updatedAt: '',
        ),
      );
    });
  }

  void _deleteBanner(int index) {
    setState(() {
      _banners.removeAt(index);
    });
  }

  Future<void> _editBanner(int index) async {
    final banner = _banners[index];
    final result = await showDialog<AdminHomeBannerItemModel>(
      context: context,
      builder: (context) => _AdminBannerEditDialog(banner: banner),
    );
    if (result != null) {
      setState(() {
        _banners[index] = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminModuleScaffold(
      title: 'بانرات الرئيسية',
      floatingActionButton: FloatingActionButton(
        onPressed: _addBanner,
        tooltip: 'إضافة بانر',
        child: const Icon(Icons.add_rounded),
      ),
      body: FutureBuilder<AdminHomeBannersModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final safeMessage = ApiContract.safeMessageFromException(
              snapshot.error ?? const FormatException('unknown'),
              fallback: 'تعذر تحميل البانرات. يرجى إعادة المحاولة.',
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
                    const Text(
                      'ترتيب البانرات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'يمكنك تغيير ترتيب البانرات عبر السحب والإفلات، وإيقاف أو تفعيل البانر عبر مفتاح التفعيل.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    if (_banners.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text('لا توجد بانرات حالياً.'),
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _banners.length,
                        onReorderItem: (oldIndex, newIndex) {
                          setState(() {
                            final item = _banners.removeAt(oldIndex);
                            _banners.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final banner = _banners[index];
                          return Card(
                            key: ValueKey(banner.id),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.drag_handle_rounded),
                              title: Text(
                                banner.title.isNotEmpty
                                    ? banner.title
                                    : 'بدون عنوان',
                              ),
                              subtitle: Text(
                                banner.enabled ? 'مُفعل' : 'مُعطل',
                                style: TextStyle(
                                  color: banner.enabled
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_rounded,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () => _editBanner(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_rounded,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteBanner(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_rounded),
                        label: Text(
                          _saving ? 'جارٍ الحفظ...' : 'حفظ التعديلات',
                        ),
                      ),
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

class _AdminBannerEditDialog extends StatefulWidget {
  final AdminHomeBannerItemModel banner;
  const _AdminBannerEditDialog({required this.banner});

  @override
  State<_AdminBannerEditDialog> createState() => _AdminBannerEditDialogState();
}

class _AdminBannerEditDialogState extends State<_AdminBannerEditDialog> {
  late bool _enabled;
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _imageController;
  late TextEditingController _buttonLabelController;
  late TextEditingController _buttonLinkController;
  late AdminBannerActionType _actionType;
  late TextEditingController _actionValueController;
  late TextEditingController _productIdsController;

  @override
  void initState() {
    super.initState();
    _enabled = widget.banner.enabled;
    _titleController = TextEditingController(text: widget.banner.title);
    _subtitleController = TextEditingController(text: widget.banner.subtitle);
    _imageController = TextEditingController(text: widget.banner.imageUrl);
    _buttonLabelController = TextEditingController(
      text: widget.banner.buttonLabel,
    );
    _buttonLinkController = TextEditingController(
      text: widget.banner.buttonLink,
    );
    _actionType = widget.banner.actionType;
    _actionValueController = TextEditingController(
      text: widget.banner.actionValue,
    );
    _productIdsController = TextEditingController(
      text: widget.banner.productIds.join(', '),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<ProductCubit>();
      if (cubit.state.categories.isEmpty || cubit.state.brands.isEmpty) {
        cubit.initialize(forceRefresh: false);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _imageController.dispose();
    _buttonLabelController.dispose();
    _buttonLinkController.dispose();
    _actionValueController.dispose();
    _productIdsController.dispose();
    super.dispose();
  }

  void _save() {
    final result = AdminHomeBannerItemModel(
      id: widget.banner.id,
      enabled: _enabled,
      imageId: widget.banner.imageId,
      imageUrl: _imageController.text.trim(),
      title: _titleController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      buttonLabel: _buttonLabelController.text.trim(),
      buttonLink: _buttonLinkController.text.trim(),
      actionType: _actionType,
      actionValue: _actionValueController.text.trim(),
      sortOrder: widget.banner.sortOrder,
      startsAt: widget.banner.startsAt,
      endsAt: widget.banner.endsAt,
      productIds: _productIdsController.text
          .split(',')
          .map((value) => int.tryParse(value.trim()) ?? 0)
          .where((value) => value > 0)
          .toList(),
      updatedAt: widget.banner.updatedAt,
      showTitle: widget.banner.showTitle,
      showSubtitle: widget.banner.showSubtitle,
      showButton: widget.banner.showButton,
      contentAlignment: widget.banner.contentAlignment,
      contentVerticalAlignment: widget.banner.contentVerticalAlignment,
      imageFit: widget.banner.imageFit,
      overlayOpacity: widget.banner.overlayOpacity,
      titleColor: widget.banner.titleColor,
      subtitleColor: widget.banner.subtitleColor,
      buttonBackgroundColor: widget.banner.buttonBackgroundColor,
      buttonTextColor: widget.banner.buttonTextColor,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تعديل البانر',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              onChanged: (val) => setState(() => _enabled = val),
              title: const Text('مُفعل'),
            ),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'العنوان'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _subtitleController,
              decoration: const InputDecoration(labelText: 'الوصف'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _imageController,
              decoration: const InputDecoration(labelText: 'رابط الصورة'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _buttonLabelController,
              decoration: const InputDecoration(
                labelText: 'نص الزر (مثال: تسوق الآن)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _buttonLinkController,
              decoration: const InputDecoration(
                labelText:
                    '\u0631\u0627\u0628\u0637 \u0627\u0644\u0632\u0631 \u0627\u0644\u0628\u062f\u064a\u0644',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<AdminBannerActionType>(
              initialValue: _actionType,
              decoration: const InputDecoration(labelText: 'إجراء الزر'),
              items: AdminBannerActionType.values.map((type) {
                String label = '';
                switch (type) {
                  case AdminBannerActionType.none:
                    label = 'لا شيء';
                    break;
                  case AdminBannerActionType.category:
                    label = 'تصنيف';
                    break;
                  case AdminBannerActionType.brand:
                    label = 'علامة تجارية';
                    break;
                  case AdminBannerActionType.product:
                    label = 'منتج';
                    break;
                  case AdminBannerActionType.search:
                    label = 'بحث';
                    break;
                  case AdminBannerActionType.internalRoute:
                    label = 'رابط داخلي';
                    break;
                  case AdminBannerActionType.externalUrl:
                    label = 'رابط خارجي';
                    break;
                }
                return DropdownMenuItem(value: type, child: Text(label));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _actionType = val);
              },
            ),
            const SizedBox(height: 10),
            _AdminBannerActionValueField(
              actionType: _actionType,
              controller: _actionValueController,
              decoration: const InputDecoration(
                labelText: 'قيمة الإجراء (معرف التصنيف، Slug، الخ)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _productIdsController,
              decoration: const InputDecoration(
                labelText: 'معرفات منتجات (اختياري للظهور فوق البانر)',
                hintText: '12, 34, 56',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: const Text('حفظ')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminBannerActionValueField extends StatelessWidget {
  const _AdminBannerActionValueField({
    required this.actionType,
    required this.controller,
    required this.decoration,
  });

  final AdminBannerActionType actionType;
  final TextEditingController controller;
  final InputDecoration decoration;

  @override
  Widget build(BuildContext context) {
    final productState = context.watch<ProductCubit>().state;
    if (actionType == AdminBannerActionType.category) {
      final selected =
          productState.categories.any(
            (category) => '${category.id}' == controller.text,
          )
          ? controller.text
          : null;
      return DropdownButtonFormField<String>(
        initialValue: selected,
        decoration: const InputDecoration(
          labelText: '\u0627\u0644\u062a\u0635\u0646\u064a\u0641',
        ),
        items: productState.categories
            .where((category) => category.id > 0)
            .map(
              (category) => DropdownMenuItem<String>(
                value: '${category.id}',
                child: Text(category.name),
              ),
            )
            .toList(growable: false),
        onChanged: (value) => controller.text = value ?? '',
      );
    }
    if (actionType == AdminBannerActionType.brand) {
      final selected =
          productState.brands.any((brand) => brand.slug == controller.text)
          ? controller.text
          : null;
      return DropdownButtonFormField<String>(
        initialValue: selected,
        decoration: const InputDecoration(
          labelText:
              '\u0627\u0644\u0639\u0644\u0627\u0645\u0629 \u0627\u0644\u062a\u062c\u0627\u0631\u064a\u0629',
        ),
        items: productState.brands
            .where((brand) => brand.slug.trim().isNotEmpty)
            .map(
              (brand) => DropdownMenuItem<String>(
                value: brand.slug,
                child: Text(brand.name),
              ),
            )
            .toList(growable: false),
        onChanged: (value) => controller.text = value ?? '',
      );
    }
    if (actionType == AdminBannerActionType.none) {
      return const SizedBox.shrink();
    }
    return TextField(
      controller: controller,
      keyboardType: actionType == AdminBannerActionType.product
          ? TextInputType.number
          : actionType == AdminBannerActionType.externalUrl
          ? TextInputType.url
          : TextInputType.text,
      decoration: decoration,
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
  const AdminOrderingScreen({super.key, this.repository});

  final AdminRepository? repository;

  @override
  State<AdminOrderingScreen> createState() => _AdminOrderingScreenState();
}

class _AdminOrderingScreenState extends State<AdminOrderingScreen> {
  late final AdminRepository _repository;
  late Future<AdminOrderingConfigModel> _future;
  AdminOrderingConfigModel? _current;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AdminRepository();
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
      await _repository.updateOrderingConfig(config);
      final persisted = await _repository.fetchOrderingConfig();
      final expected = jsonEncode(config.toJson());
      final actual = jsonEncode(persisted.toJson());
      if (expected != actual) {
        throw const FormatException(
          'Home layout persistence verification failed',
        );
      }
      if (mounted) {
        setState(() {
          _current = persisted;
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
      title: 'محتوى الصفحة الرئيسية',
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
          final orderedSliderProducts = _ordered<AdminProductOrderOptionModel>(
            config.availableFeaturedProducts,
            config.sliderProducts,
            (item) => item.id,
          );
          final orderedLatestProducts = _ordered<AdminProductOrderOptionModel>(
            config.availableFeaturedProducts,
            config.latestProducts,
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
              const AdminSectionCard(
                child: Text(
                  'أي تغيير تحفظه هنا يُرسل إلى WordPress عبر API ويصبح مصدر الصفحة الرئيسية لجميع الأعضاء بعد التحديث.',
                  style: TextStyle(fontWeight: FontWeight.w800, height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
              _ProductOrderingSection(
                title:
                    '\u0645\u0646\u062a\u062c\u0627\u062a \u0627\u0644\u0633\u0644\u0627\u064a\u062f\u0631',
                items: orderedSliderProducts,
                selectedIds: config.sliderProducts,
                emptyLabel: 'لم يتم اختيار منتجات للسلايدر.',
                onChanged: (ids) => setState(() {
                  _current = config.copyWith(sliderProducts: ids);
                }),
              ),
              const SizedBox(height: 12),
              _ProductOrderingSection(
                title: 'المنتجات المميزة',
                items: orderedProducts,
                selectedIds: config.featuredProducts,
                emptyLabel: 'لم يتم اختيار منتجات مميزة.',
                onChanged: (ids) => setState(() {
                  _current = config.copyWith(featuredProducts: ids);
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: config.latestMode,
                decoration: const InputDecoration(
                  labelText:
                      '\u0648\u0636\u0639 \u0623\u062d\u062f\u062b \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a',
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(
                    value: 'auto',
                    child: Text(
                      '\u062a\u0644\u0642\u0627\u0626\u064a \u062d\u0633\u0628 \u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0625\u0636\u0627\u0641\u0629',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'manual',
                    child: Text('\u064a\u062f\u0648\u064a'),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _current = config.copyWith(latestMode: value ?? 'auto');
                }),
              ),
              const SizedBox(height: 12),
              if (config.latestMode == 'manual')
                _ProductOrderingSection(
                  title:
                      '\u0623\u062d\u062f\u062b \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a \u0627\u0644\u064a\u062f\u0648\u064a\u0629',
                  items: orderedLatestProducts,
                  selectedIds: config.latestProducts,
                  emptyLabel: 'لم يتم اختيار أحدث منتجات يدويًا.',
                  onChanged: (ids) => setState(() {
                    _current = config.copyWith(
                      latestProducts: ids,
                      latestMode: 'manual',
                    );
                  }),
                )
              else
                const AdminSectionCard(
                  child: Text(
                    'الوضع التلقائي مفعّل: سيعرض التطبيق أحدث المنتجات المنشورة في WooCommerce حسب تاريخ الإضافة.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                title: const Text(
                  'إعدادات ترتيب التصنيفات والعلامات',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text(
                  'إعدادات إضافية لا تؤثر على اختيارات السلايدر والمميزة والأحدث.',
                ),
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
                ],
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
                label: Text(
                  _saving ? 'جارٍ الحفظ...' : 'حفظ ونشر لجميع الأعضاء',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AdminBrandCategoryLayoutScreen extends StatefulWidget {
  const AdminBrandCategoryLayoutScreen({super.key, this.repository});

  final AdminRepository? repository;

  @override
  State<AdminBrandCategoryLayoutScreen> createState() =>
      _AdminBrandCategoryLayoutScreenState();
}

class _AdminBrandCategoryLayoutScreenState
    extends State<AdminBrandCategoryLayoutScreen> {
  late final AdminRepository _repository;
  late Future<AdminBrandCategoryLayoutModel> _future;
  AdminBrandCategoryLayoutModel? _current;
  String? _selectedBrandSlug;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AdminRepository();
    _future = _load();
  }

  Future<AdminBrandCategoryLayoutModel> _load() async {
    final layout = await _repository.fetchBrandCategoryLayout();
    _current = layout;
    _selectedBrandSlug =
        _selectedBrandSlug ??
        (layout.availableBrands.isEmpty
            ? null
            : layout.availableBrands.first.slug);
    return layout;
  }

  AdminBrandCategoryLayoutEntry _entryFor(String brandSlug) {
    return _current?.layout[brandSlug] ??
        AdminBrandCategoryLayoutEntry(
          brandSlug: brandSlug,
          categoryIds: const <int>[],
          hiddenCategoryIds: const <int>[],
        );
  }

  void _updateEntry(AdminBrandCategoryLayoutEntry entry) {
    final current = _current;
    if (current == null) return;
    setState(() {
      _current = current.copyWith(
        layout: <String, AdminBrandCategoryLayoutEntry>{
          ...current.layout,
          entry.brandSlug: entry,
        },
      );
    });
  }

  List<AdminTermModel> _orderedCategories(
    List<AdminTermModel> categories,
    List<int> selectedIds,
  ) {
    final orderMap = {
      for (var i = 0; i < selectedIds.length; i++) selectedIds[i]: i,
    };
    final sorted = [...categories];
    sorted.sort((a, b) {
      final aOrder = orderMap[a.id] ?? 9999;
      final bOrder = orderMap[b.id] ?? 9999;
      if (aOrder != bOrder) return aOrder.compareTo(bOrder);
      if (a.menuOrder != b.menuOrder) {
        return a.menuOrder.compareTo(b.menuOrder);
      }
      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  Future<void> _save() async {
    final current = _current;
    if (current == null) return;
    setState(() => _saving = true);
    try {
      final saved = await _repository.updateBrandCategoryLayout(current);
      final refreshed = await _repository.fetchBrandCategoryLayout();
      if (!mounted) return;
      setState(() {
        _current = refreshed.copyWith(
          availableBrands: saved.availableBrands.isEmpty
              ? refreshed.availableBrands
              : saved.availableBrands,
          availableCategories: saved.availableCategories.isEmpty
              ? refreshed.availableCategories
              : saved.availableCategories,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ تصنيفات العلامة التجارية.')),
      );
    } catch (error) {
      if (!mounted) return;
      final safeMessage = ApiContract.safeMessageFromException(
        error,
        fallback: 'تعذر حفظ تصنيفات العلامة التجارية حالياً.',
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
      title: 'تصنيفات العلامات التجارية',
      body: FutureBuilder<AdminBrandCategoryLayoutModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final safeMessage = ApiContract.safeMessageFromException(
              snapshot.error ?? const FormatException('unknown'),
              fallback: 'تعذر تحميل تصنيفات العلامات التجارية حالياً.',
            );
            return AdminScreenError(
              message: safeMessage,
              onRetry: () => setState(() => _future = _load()),
            );
          }

          final current = _current ?? snapshot.data;
          if (current == null || current.availableBrands.isEmpty) {
            return const AdminScreenEmpty(
              label: 'لا توجد علامات تجارية قابلة للإدارة.',
            );
          }

          final selectedBrandSlug =
              _selectedBrandSlug ?? current.availableBrands.first.slug;
          final selectedBrand = current.availableBrands.firstWhere(
            (brand) => brand.slug == selectedBrandSlug,
            orElse: () => current.availableBrands.first,
          );
          final entry = _entryFor(selectedBrand.slug);
          final categories = _orderedCategories(
            current.availableCategories,
            entry.categoryIds,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 92, 16, 24),
            children: <Widget>[
              const AdminSectionCard(
                child: Text(
                  'اختر علامة تجارية ثم رتّب التصنيفات التي ستظهر داخل صفحة العلامة في التطبيق. عند ترك القائمة فارغة يستخدم التطبيق التصنيفات المحسوبة من منتجات العلامة.',
                  style: TextStyle(fontWeight: FontWeight.w800, height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
              AdminSectionCard(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedBrand.slug,
                  decoration: const InputDecoration(
                    labelText: 'العلامة التجارية',
                  ),
                  items: current.availableBrands
                      .map(
                        (brand) => DropdownMenuItem<String>(
                          value: brand.slug,
                          child: Text(brand.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null || value.isEmpty) return;
                    setState(() => _selectedBrandSlug = value);
                  },
                ),
              ),
              const SizedBox(height: 12),
              _OrderingSection<AdminTermModel>(
                title: 'تصنيفات ${selectedBrand.name}',
                items: categories,
                selectedIds: entry.categoryIds,
                idOf: (item) => item.id,
                labelOf: (item) => item.name,
                onChanged: (ids) =>
                    _updateEntry(entry.copyWith(categoryIds: ids)),
              ),
              const SizedBox(height: 12),
              _VisibilitySection<AdminTermModel>(
                title: 'إخفاء تصنيفات داخل ${selectedBrand.name}',
                helperText:
                    'الإخفاء هنا خاص بصفحة هذه العلامة فقط ولا يغيّر ظهور التصنيف العام.',
                items: categories,
                hiddenIds: entry.hiddenCategoryIds,
                idOf: (item) => item.id,
                labelOf: (item) => item.name,
                onChanged: (ids) =>
                    _updateEntry(entry.copyWith(hiddenCategoryIds: ids)),
              ),
              const SizedBox(height: 12),
              if (entry.updatedAt.isNotEmpty)
                Text(
                  'آخر تحديث: ${entry.updatedAt}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_rounded),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ التصنيفات'),
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
            onReorderItem: (oldIndex, newIndex) {
              final next = [...selectedIds];
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: unselectedItems.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = unselectedItems[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(labelOf(item)),
                  trailing: IconButton(
                    onPressed: () => onChanged([...selectedIds, idOf(item)]),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductOrderingSection extends StatefulWidget {
  const _ProductOrderingSection({
    required this.title,
    required this.items,
    required this.selectedIds,
    required this.emptyLabel,
    required this.onChanged,
  });

  final String title;
  final List<AdminProductOrderOptionModel> items;
  final List<int> selectedIds;
  final String emptyLabel;
  final ValueChanged<List<int>> onChanged;

  @override
  State<_ProductOrderingSection> createState() =>
      _ProductOrderingSectionState();
}

class _ProductOrderingSectionState extends State<_ProductOrderingSection> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final byId = <int, AdminProductOrderOptionModel>{
      for (final item in widget.items) item.id: item,
    };
    final selectedItems = widget.selectedIds
        .map((id) => byId[id])
        .whereType<AdminProductOrderOptionModel>()
        .toList(growable: false);
    final query = _searchController.text.trim().toLowerCase();
    final availableItems = widget.items
        .where((item) => !widget.selectedIds.contains(item.id))
        .where(
          (item) =>
              query.isEmpty ||
              item.name.toLowerCase().contains(query) ||
              '${item.id}'.contains(query),
        )
        .toList(growable: false);

    return AdminSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${widget.selectedIds.length} مختار',
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (selectedItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(widget.emptyLabel),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selectedItems.length,
              onReorderItem: (oldIndex, newIndex) {
                final next = [...widget.selectedIds];
                final id = next.removeAt(oldIndex);
                next.insert(newIndex, id);
                widget.onChanged(next);
              },
              itemBuilder: (context, index) {
                final item = selectedItems[index];
                return ListTile(
                  key: ValueKey<String>('selected_${widget.title}_${item.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: _ProductOptionImage(item.imageUrl),
                  title: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('ID: ${item.id}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'إزالة',
                        onPressed: () => widget.onChanged(
                          widget.selectedIds
                              .where((id) => id != item.id)
                              .toList(growable: false),
                        ),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                      const Icon(Icons.drag_handle_rounded),
                    ],
                  ),
                );
              },
            ),
          const Divider(height: 28),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'ابحث لإضافة منتج',
              hintText: 'اسم المنتج أو ID',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          if (availableItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('لا توجد منتجات مطابقة للبحث.'),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: availableItems.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = availableItems[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _ProductOptionImage(item.imageUrl),
                    title: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('ID: ${item.id}'),
                    trailing: IconButton(
                      tooltip: 'إضافة',
                      onPressed: () =>
                          widget.onChanged([...widget.selectedIds, item.id]),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductOptionImage extends StatelessWidget {
  const _ProductOptionImage(this.imageUrl);

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 44,
        child: imageUrl.trim().isEmpty
            ? const ColoredBox(
                color: Color(0xFFF1F4F8),
                child: Icon(Icons.inventory_2_outlined),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFFF1F4F8),
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
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
