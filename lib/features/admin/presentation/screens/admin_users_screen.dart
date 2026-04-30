import 'package:flutter/material.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/features/admin/data/models/admin_models.dart';
import 'package:lpco_llc/features/admin/data/repositories/admin_repository.dart';
import 'package:lpco_llc/features/admin/presentation/widgets/admin_module_widgets.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminRepository _repository = AdminRepository();
  final TextEditingController _searchController = TextEditingController();

  int _page = 1;
  String _role = '';
  String _group = '';
  String _status = '';
  late Future<AdminPagedResponse<AdminUserModel>> _future;

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

  Future<AdminPagedResponse<AdminUserModel>> _load() {
    return _repository.fetchUsers(
      page: _page,
      search: _searchController.text.trim(),
      role: _role,
      group: _group,
      status: _status,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _showUserDetails(AdminUserModel user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user.displayName.isEmpty ? user.username : user.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text('اسم المستخدم: ${user.username}'),
                Text('البريد: ${user.email}'),
                Text('الأدوار: ${user.roles.join('، ')}'),
                Text('المجموعة: ${user.group}'),
                Text('الحالة: ${user.accountStatus}'),
                if (user.phone.isNotEmpty) Text('الهاتف: ${user.phone}'),
                if (user.governorate.isNotEmpty)
                  Text('المحافظة: ${user.governorate}'),
                if (user.registeredAt.isNotEmpty)
                  Text('تاريخ التسجيل: ${user.registeredAt}'),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminModuleScaffold(
      title: 'إدارة المستخدمين',
      body: FutureBuilder<AdminPagedResponse<AdminUserModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final safeMessage = ApiContract.safeMessageFromException(
              snapshot.error ?? const FormatException('unknown'),
              fallback: 'تعذر تحميل المستخدمين حالياً. يرجى إعادة المحاولة.',
            );
            return AdminScreenError(message: safeMessage, onRetry: _refresh);
          }

          final result = snapshot.data;
          if (result == null) {
            return const AdminScreenEmpty(label: 'لا توجد بيانات مستخدمين.');
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
                          hintText:
                              'بحث باسم المستخدم أو البريد أو الاسم الظاهر',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _role,
                              decoration: const InputDecoration(
                                labelText: 'الدور',
                              ),
                              items: const <DropdownMenuItem<String>>[
                                DropdownMenuItem(
                                  value: '',
                                  child: Text('الكل'),
                                ),
                                DropdownMenuItem(
                                  value: 'administrator',
                                  child: Text('Administrator'),
                                ),
                                DropdownMenuItem(
                                  value: 'shop_manager',
                                  child: Text('Shop Manager'),
                                ),
                                DropdownMenuItem(
                                  value: 'customer',
                                  child: Text('Customer'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _role = value ?? '';
                                  _page = 1;
                                  _future = _load();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _group,
                              decoration: const InputDecoration(
                                labelText: 'المجموعة',
                              ),
                              items: <DropdownMenuItem<String>>[
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('الكل'),
                                ),
                                const DropdownMenuItem(
                                  value: 'default',
                                  child: Text('افتراضي'),
                                ),
                                const DropdownMenuItem(
                                  value: 'wholesale',
                                  child: Text('جملة'),
                                ),
                                const DropdownMenuItem(
                                  value: 'vip',
                                  child: Text('VIP'),
                                ),
                                if (_group.isNotEmpty &&
                                    ![
                                      '',
                                      'default',
                                      'wholesale',
                                      'vip',
                                    ].contains(_group))
                                  DropdownMenuItem(
                                    value: _group,
                                    child: Text(_group),
                                  ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _group = value ?? '';
                                  _page = 1;
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
                              initialValue: _status,
                              decoration: const InputDecoration(
                                labelText: 'الحالة',
                              ),
                              items: const <DropdownMenuItem<String>>[
                                DropdownMenuItem(
                                  value: '',
                                  child: Text('الكل'),
                                ),
                                DropdownMenuItem(
                                  value: 'active',
                                  child: Text('نشط'),
                                ),
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Text('معلق'),
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
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (result.items.isEmpty)
                  const AdminScreenEmpty(label: 'لا يوجد مستخدمون مطابقون.')
                else
                  ...result.items.map(
                    (user) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AdminSectionCard(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _showUserDetails(user),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                user.displayName.isEmpty
                                    ? user.username
                                    : user.displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(user.email),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  _InfoPill(
                                    label: 'الدور',
                                    value: user.roles.join(', '),
                                  ),
                                  _InfoPill(
                                    label: 'المجموعة',
                                    value: user.group,
                                  ),
                                  _InfoPill(
                                    label: 'الحالة',
                                    value: user.accountStatus,
                                  ),
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

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
