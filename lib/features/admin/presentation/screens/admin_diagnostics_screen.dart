import 'package:flutter/material.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/features/admin/data/models/admin_models.dart';
import 'package:lpco_llc/features/admin/data/repositories/admin_repository.dart';
import 'package:lpco_llc/features/admin/presentation/widgets/admin_module_widgets.dart';

class AdminDiagnosticsScreen extends StatefulWidget {
  const AdminDiagnosticsScreen({super.key});

  @override
  State<AdminDiagnosticsScreen> createState() => _AdminDiagnosticsScreenState();
}

class _AdminDiagnosticsScreenState extends State<AdminDiagnosticsScreen> {
  final AdminRepository _repository = AdminRepository();
  late Future<AdminDiagnosticsModel> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchDiagnostics();
  }

  @override
  Widget build(BuildContext context) {
    return AdminModuleScaffold(
      title: 'التشخيص والعمليات',
      body: FutureBuilder<AdminDiagnosticsModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final safeMessage = ApiContract.safeMessageFromException(
              snapshot.error ?? const FormatException('unknown'),
              fallback: 'تعذر تحميل التشخيص حالياً. يرجى إعادة المحاولة.',
            );
            return AdminScreenError(
              message: safeMessage,
              onRetry: () =>
                  setState(() => _future = _repository.fetchDiagnostics()),
            );
          }
          final diagnostics = snapshot.data;
          if (diagnostics == null) {
            return const AdminScreenEmpty(label: 'لا توجد بيانات تشخيص.');
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 92, 16, 24),
            children: <Widget>[
              ...diagnostics.sections.map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AdminSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          section.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...section.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  Icons.circle,
                                  size: 12,
                                  color: switch (item.status) {
                                    'ok' => const Color(0xFF138A3F),
                                    'warning' => const Color(0xFFC98106),
                                    'error' => Colors.red,
                                    _ => const Color(0xFF1D6FD8),
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  item.value,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (diagnostics.warnings.isNotEmpty)
                AdminSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'تحذيرات',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...diagnostics.warnings.map(
                        (warning) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            warning,
                            style: const TextStyle(fontWeight: FontWeight.w700),
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
