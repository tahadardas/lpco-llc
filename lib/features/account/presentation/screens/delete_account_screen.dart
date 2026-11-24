import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/l10n/app_review_strings.dart';
import 'package:lpco_llc/features/account/data/repositories/account_repository.dart';
import 'package:lpco_llc/features/account/domain/services/account_deletion_service.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';

class DeleteAccountScreen extends StatefulWidget {
  final AccountDeletionService? deletionService;

  const DeleteAccountScreen({super.key, this.deletionService});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  late final AccountDeletionService _deletionService;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _deletionService = widget.deletionService ?? AccountDeletionService();
  }

  Future<void> _beginDeletion() async {
    if (_deleting) return;
    final password = await _requestPassword();
    if (!mounted || password == null) return;
    final confirmed = await _requestFinalConfirmation();
    if (!mounted || !confirmed) return;
    await _deleteAccount(password);
  }

  Future<String?> _requestPassword() async {
    final strings = AppReviewStrings.of(context);
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.confirmIdentity),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: strings.password),
          onSubmitted: (password) {
            if (password.isNotEmpty) Navigator.of(dialogContext).pop(password);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () {
              final password = controller.text;
              if (password.isNotEmpty) {
                Navigator.of(dialogContext).pop(password);
              }
            },
            child: Text(strings.continueDeleteAccount),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<bool> _requestFinalConfirmation() async {
    final strings = AppReviewStrings.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(strings.deleteAccountPermanently),
            content: Text(strings.finalDeletionConfirmation),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(strings.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(strings.deleteAccountPermanently),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteAccount(String password) async {
    final strings = AppReviewStrings.of(context);
    final authCubit = context.read<AuthCubit>();
    final user = authCubit.currentUser;
    if (user == null || user.isGuest) return;

    setState(() => _deleting = true);
    try {
      await _deletionService.deleteAccount(user: user, password: password);
      if (!mounted) return;
      authCubit.markAccountDeleted();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.deleteAccountSucceeded)));
      context.go(AppRoutePaths.login);
    } on AccountDeletionOfflineException {
      if (!mounted) return;
      _showFailure(strings.deletionRequiresInternet);
    } on AccountDeletionException catch (error) {
      if (!mounted) return;
      _showFailure(error.message);
    } catch (_) {
      if (!mounted) return;
      _showFailure(strings.deleteAccountFailed);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showFailure(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppReviewStrings.of(context);
    return PopScope(
      canPop: !_deleting,
      child: Scaffold(
        appBar: AppBar(title: Text(strings.deleteAccount)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 72,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 20),
              Text(
                strings.deletionExplanation,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text(
                strings.deletionRetainedRecords,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _deleting ? null : _beginDeletion,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _deleting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(strings.continueDeleteAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
