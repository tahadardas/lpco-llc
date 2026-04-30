import 'package:flutter/material.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/features/admin/data/models/admin_models.dart';
import 'package:lpco_llc/features/admin/data/repositories/admin_repository.dart';
import 'package:lpco_llc/features/admin/presentation/widgets/admin_module_widgets.dart';

class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  final AdminRepository _repository = AdminRepository();
  final TextEditingController _searchController = TextEditingController();

  String _status = '';
  int _rating = 0;
  int _page = 1;
  late Future<AdminPagedResponse<AdminReviewModel>> _future;

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

  Future<AdminPagedResponse<AdminReviewModel>> _load() {
    return _repository.fetchReviews(
      page: _page,
      search: _searchController.text.trim(),
      status: _status,
      rating: _rating > 0 ? _rating : null,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _moderate(AdminReviewModel review, String action) async {
    try {
      await _repository.updateReviewStatus(review.id, action);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث حالة التقييم.')));
      _refresh();
    } catch (error) {
      if (!mounted) return;
      final safeMessage = ApiContract.safeMessageFromException(
        error,
        fallback: 'تعذر تحديث التقييم حالياً. يرجى إعادة المحاولة.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(safeMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminModuleScaffold(
      title: 'مراجعة التقييمات',
      body: FutureBuilder<AdminPagedResponse<AdminReviewModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final safeMessage = ApiContract.safeMessageFromException(
              snapshot.error ?? const FormatException('unknown'),
              fallback: 'تعذر تحميل التقييمات حالياً. يرجى إعادة المحاولة.',
            );
            return AdminScreenError(message: safeMessage, onRetry: _refresh);
          }
          final result = snapshot.data;
          if (result == null) {
            return const AdminScreenEmpty(label: 'لا توجد تقييمات.');
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
                          hintText: 'ابحث في محتوى التقييم أو اسم المستخدم',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _status,
                              decoration: const InputDecoration(
                                labelText: 'الحالة',
                              ),
                              items: <DropdownMenuItem<String>>[
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('الكل'),
                                ),
                                const DropdownMenuItem(
                                  value: 'approved',
                                  child: Text('معتمد'),
                                ),
                                const DropdownMenuItem(
                                  value: 'hold',
                                  child: Text('موقوف'),
                                ),
                                const DropdownMenuItem(
                                  value: 'trash',
                                  child: Text('مهمل'),
                                ),
                                if (_status.isNotEmpty &&
                                    ![
                                      '',
                                      'approved',
                                      'hold',
                                      'trash',
                                    ].contains(_status))
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
                            child: DropdownButtonFormField<int>(
                              initialValue: _rating,
                              decoration: const InputDecoration(
                                labelText: 'التقييم',
                              ),
                              items: const <DropdownMenuItem<int>>[
                                DropdownMenuItem(value: 0, child: Text('الكل')),
                                DropdownMenuItem(
                                  value: 5,
                                  child: Text('5 نجوم'),
                                ),
                                DropdownMenuItem(
                                  value: 4,
                                  child: Text('4 نجوم'),
                                ),
                                DropdownMenuItem(
                                  value: 3,
                                  child: Text('3 نجوم'),
                                ),
                                DropdownMenuItem(
                                  value: 2,
                                  child: Text('2 نجمتان'),
                                ),
                                DropdownMenuItem(
                                  value: 1,
                                  child: Text('نجمة واحدة'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _rating = value ?? 0;
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
                  const AdminScreenEmpty(label: 'لا توجد تقييمات مطابقة.')
                else
                  ...result.items.map(
                    (review) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AdminSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              review.productName.isEmpty
                                  ? 'منتج غير معروف'
                                  : review.productName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('${review.user} • ${review.date}'),
                            const SizedBox(height: 6),
                            Text(review.content),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                _ActionButton(
                                  label: 'اعتماد',
                                  onTap: () => _moderate(review, 'approve'),
                                ),
                                _ActionButton(
                                  label: 'إيقاف',
                                  onTap: () => _moderate(review, 'unapprove'),
                                ),
                                _ActionButton(
                                  label: 'مهمل',
                                  onTap: () => _moderate(review, 'trash'),
                                ),
                              ],
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: onTap, child: Text(label));
  }
}
