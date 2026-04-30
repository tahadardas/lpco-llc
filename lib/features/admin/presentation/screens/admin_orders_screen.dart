import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/utils/formatters.dart';
import 'package:lpco_llc/features/admin/data/models/admin_models.dart';
import 'package:lpco_llc/features/admin/data/repositories/admin_repository.dart';
import 'package:lpco_llc/features/admin/presentation/widgets/admin_module_widgets.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final AdminRepository _repository = AdminRepository();
  final TextEditingController _searchController = TextEditingController();

  String _status = '';
  String _sort = 'date_desc';
  String _warehouse = '';
  String? _dateFrom;
  String? _dateTo;
  int _page = 1;
  late Future<AdminPagedResponse<AdminOrderSummaryModel>> _future;

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

  Future<AdminPagedResponse<AdminOrderSummaryModel>> _load() {
    return _repository.fetchOrders(
      page: _page,
      search: _searchController.text.trim(),
      status: _status,
      sort: _sort,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      warehouseCode: _warehouse,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _pickDate({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      final value =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      if (from) {
        _dateFrom = value;
      } else {
        _dateTo = value;
      }
      _page = 1;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminModuleScaffold(
      title: 'إدارة الطلبات',
      body: FutureBuilder<AdminPagedResponse<AdminOrderSummaryModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final safeMessage = ApiContract.safeMessageFromException(
              snapshot.error ?? const FormatException('unknown'),
              fallback: 'تعذر تحميل الطلبات حالياً. يرجى إعادة المحاولة.',
            );
            return AdminScreenError(message: safeMessage, onRetry: _refresh);
          }

          final result = snapshot.data;
          if (result == null) {
            return const AdminScreenEmpty(label: 'لا توجد بيانات طلبات.');
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
                          hintText: 'بحث برقم الطلب أو اسم العميل أو الهاتف',
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
                                  value: 'pending',
                                  child: Text('معلق'),
                                ),
                                const DropdownMenuItem(
                                  value: 'processing',
                                  child: Text('قيد المعالجة'),
                                ),
                                const DropdownMenuItem(
                                  value: 'completed',
                                  child: Text('مكتمل'),
                                ),
                                const DropdownMenuItem(
                                  value: 'cancelled',
                                  child: Text('ملغي'),
                                ),
                                if (_status.isNotEmpty &&
                                    ![
                                      '',
                                      'pending',
                                      'processing',
                                      'completed',
                                      'cancelled',
                                    ].contains(_status))
                                  DropdownMenuItem(
                                    value: _status,
                                    child: Text(_status),
                                  ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _status = value ?? '';
                                  _page = 1;
                                  _future = _load();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _sort,
                              decoration: const InputDecoration(
                                labelText: 'الترتيب',
                              ),
                              items: <DropdownMenuItem<String>>[
                                const DropdownMenuItem(
                                  value: 'date_desc',
                                  child: Text('الأحدث أولاً'),
                                ),
                                const DropdownMenuItem(
                                  value: 'date_asc',
                                  child: Text('الأقدم أولاً'),
                                ),
                                const DropdownMenuItem(
                                  value: 'total_desc',
                                  child: Text('الأعلى قيمة'),
                                ),
                                const DropdownMenuItem(
                                  value: 'total_asc',
                                  child: Text('الأقل قيمة'),
                                ),
                                if (![
                                  'date_desc',
                                  'date_asc',
                                  'total_desc',
                                  'total_asc',
                                ].contains(_sort))
                                  DropdownMenuItem(
                                    value: _sort,
                                    child: Text(_sort),
                                  ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _sort = value ?? 'date_desc';
                                  _page = 1;
                                  _future = _load();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _warehouse,
                        decoration: const InputDecoration(
                          labelText: 'المستودع',
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: '',
                            child: Text('كل المستودعات'),
                          ),
                          DropdownMenuItem(
                            value: 'warehouse_a',
                            child: Text('Lexi + Zidny + Zero + Stationery'),
                          ),
                          DropdownMenuItem(
                            value: 'warehouse_b',
                            child: Text('Daily + Yumor'),
                          ),
                          DropdownMenuItem(value: 'bags', child: Text('Bags')),
                          DropdownMenuItem(
                            value: 'mixed',
                            child: Text('متعدد المستودعات'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _warehouse = value ?? '';
                            _page = 1;
                            _future = _load();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickDate(from: true),
                              icon: const Icon(Icons.date_range_rounded),
                              label: Text(_dateFrom ?? 'من تاريخ'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickDate(from: false),
                              icon: const Icon(Icons.event_rounded),
                              label: Text(_dateTo ?? 'إلى تاريخ'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (result.items.isEmpty)
                  const AdminScreenEmpty(label: 'لا توجد طلبات مطابقة.')
                else
                  ...result.items.map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AdminSectionCard(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () =>
                              context.push(AppRoutePaths.adminOrder(order.id)),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'طلب #${order.number}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      order.customer,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${order.statusLabel} - ${order.date}',
                                      style: const TextStyle(
                                        color: Color(0xFF667085),
                                      ),
                                    ),
                                    if (order.warehouseLabel.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF4FF),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            order.warehouseLabel,
                                            style: const TextStyle(
                                              color: Color(0xFF1D4ED8),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  Text(
                                    PriceFormatter.format(
                                      order.total,
                                      currencyCode: order.currency,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Icon(Icons.chevron_left_rounded),
                                ],
                              ),
                            ],
                          ),
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
