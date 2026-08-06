import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/l10n/app_review_strings.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppReviewStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: Text(strings.accountManagement),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutePaths.accountManagement),
            ),
          ),
        ],
      ),
    );
  }
}
