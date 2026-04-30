import 'package:flutter/material.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/features/admin/data/models/admin_models.dart';
import 'package:lpco_llc/features/admin/data/repositories/admin_repository.dart';
import 'package:lpco_llc/features/admin/presentation/widgets/admin_module_widgets.dart';

class AdminMembersScreen extends StatefulWidget {
  const AdminMembersScreen({super.key});

  @override
  State<AdminMembersScreen> createState() => _AdminMembersScreenState();
}

class _AdminMembersScreenState extends State<AdminMembersScreen> {
  final AdminRepository _repository = AdminRepository();
  final TextEditingController _searchController = TextEditingController();

  int _page = 1;
  String _group = '';
  String _status = '';
  String _governorate = '';
  late Future<AdminPagedResponse<AdminMemberModel>> _future;

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

  Future<AdminPagedResponse<AdminMemberModel>> _load() {
    return _repository.fetchMembers(
      page: _page,
      search: _searchController.text.trim(),
      group: _group,
      status: _status,
      governorate: _governorate,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _openMemberForm({AdminMemberModel? member}) async {
    final usernameController = TextEditingController(
      text: member?.username ?? '',
    );
    final nameController = TextEditingController(text: member?.name ?? '');
    final emailController = TextEditingController(text: member?.email ?? '');
    final phoneController = TextEditingController(text: member?.phone ?? '');
    final companyController = TextEditingController(
      text: member?.company ?? '',
    );
    final governorateController = TextEditingController(
      text: member?.governorate ?? '',
    );
    final addressController = TextEditingController(
      text: member?.address ?? '',
    );
    String group = member?.group ?? 'default';
    String accountStatus = member?.accountStatus ?? 'pending';
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (emailController.text.trim().isEmpty ||
                  (member == null && usernameController.text.trim().isEmpty)) {
                return;
              }
              setDialogState(() => saving = true);
              try {
                final payload = <String, dynamic>{
                  if (member == null)
                    'username': usernameController.text.trim(),
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'company': companyController.text.trim(),
                  'governorate': governorateController.text.trim(),
                  'address': addressController.text.trim(),
                  'group': group,
                  'account_status': accountStatus,
                };

                if (member == null) {
                  await _repository.createMember(payload);
                } else {
                  await _repository.updateMember(member.id, payload);
                }
                if (!mounted || !dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      member == null
                          ? 'تم إنشاء العضو بنجاح.'
                          : 'تم تحديث العضو بنجاح.',
                    ),
                  ),
                );
                _refresh();
              } catch (error) {
                if (!mounted) return;
                final safeMessage = ApiContract.safeMessageFromException(
                  error,
                  fallback:
                      'تعذر حفظ بيانات العضو حالياً. يرجى إعادة المحاولة.',
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
              title: Text(member == null ? 'إضافة عضو' : 'تعديل العضو'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (member == null)
                      TextField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم المستخدم',
                        ),
                      ),
                    if (member == null) const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'الاسم'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'الهاتف'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: companyController,
                      decoration: const InputDecoration(labelText: 'الشركة'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: governorateController,
                      decoration: const InputDecoration(labelText: 'المحافظة'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'العنوان'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: group,
                      decoration: const InputDecoration(labelText: 'المجموعة'),
                      items: <DropdownMenuItem<String>>[
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
                        if (!['default', 'wholesale', 'vip'].contains(group))
                          DropdownMenuItem(value: group, child: Text(group)),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => group = value ?? 'default'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: accountStatus,
                      decoration: const InputDecoration(labelText: 'الحالة'),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem(
                          value: 'pending',
                          child: Text('معلق'),
                        ),
                        const DropdownMenuItem(
                          value: 'active',
                          child: Text('نشط'),
                        ),
                        const DropdownMenuItem(
                          value: 'inactive',
                          child: Text('غير نشط'),
                        ),
                        if (![
                          'pending',
                          'active',
                          'inactive',
                        ].contains(accountStatus))
                          DropdownMenuItem(
                            value: accountStatus,
                            child: Text(accountStatus),
                          ),
                      ],
                      onChanged: (value) => setDialogState(
                        () => accountStatus = value ?? 'pending',
                      ),
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

  Future<void> _deleteMember(AdminMemberModel member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف العضو'),
          content: Text(
            'هل تريد حذف ${member.name.isEmpty ? member.username : member.name}؟',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      await _repository.deleteMember(member.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف العضو بنجاح.')));
      _refresh();
    } catch (error) {
      if (!mounted) return;
      final safeMessage = ApiContract.safeMessageFromException(
        error,
        fallback: 'تعذر حذف العضو حالياً. يرجى إعادة المحاولة.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(safeMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminModuleScaffold(
      title: 'إدارة الأعضاء',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openMemberForm(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('عضو جديد'),
      ),
      body: FutureBuilder<AdminPagedResponse<AdminMemberModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final safeMessage = ApiContract.safeMessageFromException(
              snapshot.error ?? const FormatException('unknown'),
              fallback:
                  'تعذر تحميل بيانات الأعضاء حالياً. يرجى إعادة المحاولة.',
            );
            return AdminScreenError(message: safeMessage, onRetry: _refresh);
          }

          final result = snapshot.data;
          if (result == null) {
            return const AdminScreenEmpty(label: 'لا توجد بيانات أعضاء.');
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
                          hintText: 'بحث بالاسم أو البريد أو اسم المستخدم',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'المحافظة',
                              ),
                              onSubmitted: (value) {
                                setState(() {
                                  _governorate = value.trim();
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
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(
                          labelText: 'حالة الحساب',
                        ),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem(
                            value: '',
                            child: Text('الكل'),
                          ),
                          const DropdownMenuItem(
                            value: 'active',
                            child: Text('نشط'),
                          ),
                          const DropdownMenuItem(
                            value: 'pending',
                            child: Text('معلق'),
                          ),
                          const DropdownMenuItem(
                            value: 'inactive',
                            child: Text('غير نشط'),
                          ),
                          if (_status.isNotEmpty &&
                              ![
                                '',
                                'active',
                                'pending',
                                'inactive',
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
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (result.items.isEmpty)
                  const AdminScreenEmpty(label: 'لا يوجد أعضاء مطابقون.')
                else
                  ...result.items.map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AdminSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              member.name.isEmpty
                                  ? member.username
                                  : member.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(member.email),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                _Tag(label: 'المجموعة', value: member.group),
                                _Tag(
                                  label: 'الحالة',
                                  value: member.accountStatus,
                                ),
                                if (member.governorate.isNotEmpty)
                                  _Tag(
                                    label: 'المحافظة',
                                    value: member.governorate,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _openMemberForm(member: member),
                                    icon: const Icon(Icons.edit_rounded),
                                    label: const Text('تعديل'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _deleteMember(member),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                    label: const Text('حذف'),
                                  ),
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

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.value});

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
