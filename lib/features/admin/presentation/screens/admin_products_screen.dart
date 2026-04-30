import 'package:flutter/material.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/utils/formatters.dart';
import 'package:lpco_llc/features/admin/data/models/admin_models.dart';
import 'package:lpco_llc/features/admin/data/repositories/admin_repository.dart';
import 'package:lpco_llc/features/admin/presentation/widgets/admin_module_widgets.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final AdminRepository _repository = AdminRepository();
  final TextEditingController _searchController = TextEditingController();

  int _page = 1;
  String _stockStatus = '';
  String _status = '';
  String _category = '';
  String _brand = '';
  bool? _featured;
  late Future<AdminPagedResponse<AdminProductModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<AdminPagedResponse<AdminProductModel>> _load() {
    return _repository.fetchProducts(
      page: _page,
      search: _searchController.text.trim(),
      category: _category,
      brand: _brand,
      stockStatus: _stockStatus,
      featured: _featured,
      status: _status,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _editProduct(AdminProductModel product) async {
    final nameController = TextEditingController(text: product.name);
    final skuController = TextEditingController(text: product.sku);
    final regularController = TextEditingController(text: product.regularPrice);
    final saleController = TextEditingController(text: product.salePrice);
    final stockController = TextEditingController(
      text: '${product.stockQuantity ?? 0}',
    );
    String status = product.status;
    bool featured = product.featured;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              setDialogState(() => saving = true);
              try {
                await _repository.updateProduct(product.id, <String, dynamic>{
                  'name': nameController.text.trim(),
                  'sku': skuController.text.trim(),
                  'regular_price': regularController.text.trim(),
                  'sale_price': saleController.text.trim(),
                  'stock_quantity':
                      int.tryParse(stockController.text.trim()) ?? 0,
                  'status': status,
                  'featured': featured,
                });
                if (!mounted || !dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تحديث المنتج بنجاح.')),
                );
                _refresh();
              } catch (error) {
                if (!mounted) return;
                final safeMessage = ApiContract.safeMessageFromException(
                  error,
                  fallback: 'تعذر تحديث المنتج حالياً. يرجى إعادة المحاولة.',
                );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(safeMessage)));
              } finally {
                if (mounted) {
                  setDialogState(() => saving = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('تعديل المنتج'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'الاسم'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: skuController,
                      decoration: const InputDecoration(labelText: 'SKU'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: regularController,
                      decoration: const InputDecoration(
                        labelText: 'السعر النظامي',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: saleController,
                      decoration: const InputDecoration(
                        labelText: 'سعر التخفيض',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'المخزون'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'الحالة'),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem(
                          value: 'publish',
                          child: Text('منشور'),
                        ),
                        const DropdownMenuItem(
                          value: 'draft',
                          child: Text('مسودة'),
                        ),
                        const DropdownMenuItem(
                          value: 'pending',
                          child: Text('معلق'),
                        ),
                        if (!['publish', 'draft', 'pending'].contains(status))
                          DropdownMenuItem(value: status, child: Text(status)),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => status = value ?? 'publish'),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: featured,
                      onChanged: (value) =>
                          setDialogState(() => featured = value),
                      title: const Text('منتج مميز'),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'جارٍ الحفظ...' : 'حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminModuleScaffold(
      title: 'إدارة المنتجات',
      body: FutureBuilder<AdminPagedResponse<AdminProductModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final safeMessage = ApiContract.safeMessageFromException(
              snapshot.error ?? const FormatException('unknown'),
              fallback: 'تعذر تحميل المنتجات حالياً. يرجى إعادة المحاولة.',
            );
            return AdminScreenError(message: safeMessage, onRetry: _refresh);
          }
          final result = snapshot.data;
          if (result == null) {
            return const AdminScreenEmpty(label: 'لا توجد بيانات منتجات.');
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 92, 16, 24),
              children: <Widget>[
                AdminSectionCard(
                  child: Column(
                    children: <Widget>[
                      TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) {
                          setState(() {
                            _page = 1;
                            _future = _load();
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'بحث بالاسم أو SKU',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'التصنيف',
                              ),
                              onSubmitted: (value) {
                                setState(() {
                                  _category = value.trim();
                                  _future = _load();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'العلامة التجارية',
                              ),
                              onSubmitted: (value) {
                                setState(() {
                                  _brand = value.trim();
                                  _future = _load();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _stockStatus,
                              decoration: const InputDecoration(
                                labelText: 'المخزون',
                              ),
                              items: <DropdownMenuItem<String>>[
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('الكل'),
                                ),
                                const DropdownMenuItem(
                                  value: 'instock',
                                  child: Text('متوفر'),
                                ),
                                const DropdownMenuItem(
                                  value: 'outofstock',
                                  child: Text('غير متوفر'),
                                ),
                                if (_stockStatus.isNotEmpty &&
                                    ![
                                      '',
                                      'instock',
                                      'outofstock',
                                    ].contains(_stockStatus))
                                  DropdownMenuItem(
                                    value: _stockStatus,
                                    child: Text(_stockStatus),
                                  ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _stockStatus = value ?? '';
                                  _future = _load();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _status,
                              decoration: const InputDecoration(
                                labelText: 'النشر',
                              ),
                              items: <DropdownMenuItem<String>>[
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('الكل'),
                                ),
                                const DropdownMenuItem(
                                  value: 'publish',
                                  child: Text('منشور'),
                                ),
                                const DropdownMenuItem(
                                  value: 'draft',
                                  child: Text('مسودة'),
                                ),
                                if (_status.isNotEmpty &&
                                    !['', 'publish', 'draft'].contains(_status))
                                  DropdownMenuItem(
                                    value: _status,
                                    child: Text(_status),
                                  ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _status = value ?? '';
                                  _future = _load();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _featured == null
                                  ? ''
                                  : (_featured! ? '1' : '0'),
                              decoration: const InputDecoration(
                                labelText: 'مميز',
                              ),
                              items: const <DropdownMenuItem<String>>[
                                DropdownMenuItem(
                                  value: '',
                                  child: Text('الكل'),
                                ),
                                DropdownMenuItem(
                                  value: '1',
                                  child: Text('نعم'),
                                ),
                                DropdownMenuItem(value: '0', child: Text('لا')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _featured = value == null || value.isEmpty
                                      ? null
                                      : value == '1';
                                  _future = _load();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (result.items.isEmpty)
                  const AdminScreenEmpty(label: 'لا توجد منتجات مطابقة.')
                else
                  ...result.items.map(
                    (product) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AdminSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'SKU: ${product.sku.isEmpty ? '-' : product.sku}',
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                _Pill(
                                  label: 'السعر',
                                  value: PriceFormatter.format(
                                    num.tryParse(product.effectivePrice) ?? 0,
                                    currencyCode: 'syp',
                                  ),
                                ),
                                _Pill(
                                  label: 'المخزون',
                                  value: product.stockStatus,
                                ),
                                _Pill(label: 'النشر', value: product.status),
                              ],
                            ),
                            const SizedBox(height: 10),
                            FilledButton.tonalIcon(
                              onPressed: () => _editProduct(product),
                              icon: const Icon(Icons.edit_rounded),
                              label: const Text('تعديل'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                AdminPaginationBar(
                  page: result.page,
                  totalPages: result.totalPages,
                  onPrevious: result.page > 1
                      ? () {
                          setState(() {
                            _page -= 1;
                            _future = _load();
                          });
                        }
                      : null,
                  onNext: result.page < result.totalPages
                      ? () {
                          setState(() {
                            _page += 1;
                            _future = _load();
                          });
                        }
                      : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
