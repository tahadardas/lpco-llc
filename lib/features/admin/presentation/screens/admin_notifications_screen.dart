import 'package:flutter/material.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/features/admin/data/models/admin_models.dart';
import 'package:lpco_llc/features/admin/data/repositories/admin_repository.dart';
import 'package:lpco_llc/features/admin/presentation/widgets/admin_module_widgets.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final AdminRepository _repository = AdminRepository();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _deepLinkController = TextEditingController();

  String _audience = 'all';
  AdminUserModel? _targetUser;
  int _page = 1;
  String _historySearch = '';
  String _historyAudience = '';
  late Future<AdminPagedResponse<AdminNotificationHistoryModel>> _future;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchNotificationsHistory(page: _page);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _imageController.dispose();
    _deepLinkController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(
      () => _future = _repository.fetchNotificationsHistory(
        page: _page,
        search: _historySearch,
        audience: _historyAudience,
      ),
    );
    await _future;
  }

  Future<void> _pickUser() async {
    final controller = TextEditingController();
    List<AdminUserModel> results = <AdminUserModel>[];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> search() async {
              final query = controller.text.trim();
              if (query.isEmpty) return;
              final response = await _repository.searchTargetUsers(query);
              setDialogState(() => results = response.items);
            }

            return AlertDialog(
              title: const Text('اختيار مستخدم'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: controller,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => search(),
                      decoration: const InputDecoration(
                        hintText: 'ابحث باسم المستخدم',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 260,
                      child: ListView(
                        children: results
                            .map(
                              (user) => ListTile(
                                title: Text(
                                  user.displayName.isEmpty
                                      ? user.username
                                      : user.displayName,
                                ),
                                subtitle: Text(user.email),
                                onTap: () {
                                  setState(() => _targetUser = user);
                                  Navigator.of(dialogContext).pop();
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('إغلاق'),
                ),
                FilledButton(onPressed: search, child: const Text('بحث')),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _send() async {
    if (_titleController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      return;
    }
    if (_audience == 'single_user' && _targetUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر مستخدمًا مستهدفًا أولًا.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await _repository.sendNotification(
        title: _titleController.text,
        body: _bodyController.text,
        audience: _audience,
        imageUrl: _imageController.text,
        deepLink: _deepLinkController.text,
        targetUserId: _targetUser?.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إرسال الإشعار بنجاح.')));
      _titleController.clear();
      _bodyController.clear();
      _imageController.clear();
      _deepLinkController.clear();
      _targetUser = null;
      _refresh();
    } catch (error) {
      if (!mounted) return;
      final safeMessage = ApiContract.safeMessageFromException(
        error,
        fallback: 'تعذر إرسال الإشعار حالياً. يرجى إعادة المحاولة.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(safeMessage)));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminModuleScaffold(
      title: 'مركز الإشعارات',
      body: FutureBuilder<AdminPagedResponse<AdminNotificationHistoryModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final safeMessage = ApiContract.safeMessageFromException(
              snapshot.error ?? const FormatException('unknown'),
              fallback: 'تعذر تحميل سجل الإشعارات حالياً. يرجى إعادة المحاولة.',
            );
            return AdminScreenError(message: safeMessage, onRetry: _refresh);
          }
          final result = snapshot.data;
          if (result == null) {
            return const AdminScreenEmpty(label: 'لا يوجد سجل إشعارات.');
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 92, 16, 24),
              children: <Widget>[
                AdminSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'إرسال إشعار جديد',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'العنوان'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _bodyController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'النص'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _audience,
                        decoration: const InputDecoration(labelText: 'الجمهور'),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: 'all', child: Text('الكل')),
                          DropdownMenuItem(
                            value: 'guests',
                            child: Text('الضيوف'),
                          ),
                          DropdownMenuItem(
                            value: 'logged_in',
                            child: Text('المستخدمون المسجلون'),
                          ),
                          DropdownMenuItem(
                            value: 'single_user',
                            child: Text('مستخدم واحد'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _audience = value ?? 'all';
                            if (_audience != 'single_user') {
                              _targetUser = null;
                            }
                          });
                        },
                      ),
                      if (_audience == 'single_user') ...<Widget>[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _pickUser,
                          icon: const Icon(Icons.person_search_rounded),
                          label: Text(
                            _targetUser == null
                                ? 'اختيار مستخدم'
                                : 'المستخدم: ${_targetUser!.displayName.isEmpty ? _targetUser!.username : _targetUser!.displayName}',
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: _imageController,
                        decoration: const InputDecoration(
                          labelText: 'رابط الصورة',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _deepLinkController,
                        decoration: const InputDecoration(
                          labelText: 'Deep Link',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.send_rounded),
                        label: Text(_sending ? 'جارٍ الإرسال...' : 'إرسال'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'السجل',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                AdminSectionCard(
                  child: Column(
                    children: <Widget>[
                      TextField(
                        textInputAction: TextInputAction.search,
                        onSubmitted: (value) {
                          setState(() {
                            _historySearch = value.trim();
                            _future = _repository.fetchNotificationsHistory(
                              page: 1,
                              search: _historySearch,
                              audience: _historyAudience,
                            );
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'بحث في عنوان أو نص الإشعار',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _historyAudience,
                        decoration: const InputDecoration(
                          labelText: 'فلترة الجمهور',
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: '', child: Text('الكل')),
                          DropdownMenuItem(value: 'all', child: Text('الكل')),
                          DropdownMenuItem(
                            value: 'guests',
                            child: Text('الضيوف'),
                          ),
                          DropdownMenuItem(
                            value: 'logged_in',
                            child: Text('المستخدمون المسجلون'),
                          ),
                          DropdownMenuItem(
                            value: 'single_user',
                            child: Text('مستخدم واحد'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _historyAudience = value ?? '';
                            _future = _repository.fetchNotificationsHistory(
                              page: 1,
                              search: _historySearch,
                              audience: _historyAudience,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (result.items.isEmpty)
                  const AdminScreenEmpty(label: 'لا يوجد سجل إرسال بعد.')
                else
                  ...result.items.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AdminSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              entry.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(entry.body),
                            const SizedBox(height: 6),
                            Text(
                              '${entry.audience} • ${entry.createdAt}',
                              style: const TextStyle(color: Color(0xFF667085)),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                _StatPill(
                                  label: 'تم التسليم',
                                  value: '${entry.deliveredCount}',
                                ),
                                _StatPill(
                                  label: 'مقروء',
                                  value: '${entry.readCount}',
                                ),
                                _StatPill(
                                  label: 'غير مقروء',
                                  value: '${entry.unreadCount}',
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
                            _future = _repository.fetchNotificationsHistory(
                              page: _page,
                              search: _historySearch,
                              audience: _historyAudience,
                            );
                          });
                        }
                      : null,
                  onNext: result.page < result.totalPages
                      ? () {
                          setState(() {
                            _page += 1;
                            _future = _repository.fetchNotificationsHistory(
                              page: _page,
                              search: _historySearch,
                              audience: _historyAudience,
                            );
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

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

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
