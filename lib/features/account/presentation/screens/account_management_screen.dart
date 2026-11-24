import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/l10n/app_review_strings.dart';

class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppReviewStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.accountManagement)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                strings.deleteAccount,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutePaths.deleteAccount),
            ),
          ),
        ],
      ),
    );
  }
}
