import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/navigation/app_back_scope.dart';
import 'package:lpco_llc/core/services/push_notification_service.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';
import 'package:lpco_llc/core/widgets/app_skeleton.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:lpco_llc/features/notifications/presentation/cubit/notifications_badge_cubit.dart';
import 'package:lpco_llc/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:lpco_llc/core/widgets/brand_app_bar.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final canViewInbox =
        authState is Authenticated || authState is GuestAuthenticated;
    if (!canViewInbox) {
      return AppBackScope(
        child: Scaffold(
          appBar: AppBar(title: Text(TextSanitizer.fix('الإشعارات'))),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_off_outlined, size: 56),
                  const SizedBox(height: 10),
                  Text(
                    TextSanitizer.fix('يرجى تسجيل الدخول لعرض الإشعارات'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.push(
                      AppRoutePaths.loginRedirect(AppRoutePaths.notifications),
                    ),
                    child: Text(TextSanitizer.fix('تسجيل الدخول')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AppBackScope(
      child: BlocProvider(
        create: (_) => NotificationsCubit()..load(),
        child: BlocListener<NotificationsCubit, NotificationsState>(
          listener: (context, state) {
            if (state is NotificationsLoaded) {
              context.read<NotificationsBadgeCubit>().setCount(
                state.unreadCount,
              );
            }
          },
          child: Scaffold(
            appBar: BrandAppBar(
              title: 'الإشعارات',
              showBack: true,
              actions: [
                BlocBuilder<NotificationsCubit, NotificationsState>(
                  builder: (context, state) {
                    final unread = state is NotificationsLoaded
                        ? state.unreadCount
                        : 0;
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: Center(
                        child: Text(
                          TextSanitizer.fix('غير مقروء: $unread'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.done_all),
                  tooltip: TextSanitizer.fix('قراءة الكل'),
                  onPressed: () =>
                      context.read<NotificationsCubit>().markAllRead(),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: TextSanitizer.fix('تحديث'),
                  onPressed: () => context.read<NotificationsCubit>().load(),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: TextSanitizer.fix('حذف الكل'),
                  onPressed: () =>
                      context.read<NotificationsCubit>().deleteAll(),
                ),
              ],
            ),
            body: BlocBuilder<NotificationsCubit, NotificationsState>(
              builder: (context, state) {
                if (state is NotificationsLoading ||
                    state is NotificationsInitial) {
                  return AppSkeleton(
                    enabled: true,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: 6,
                      itemBuilder: (context, index) => const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: SkeletonBlock(height: 72),
                      ),
                    ),
                  );
                }

                if (state is NotificationsError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.notifications_off_outlined,
                            size: 52,
                            color: Color(0xFF8B95A5),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            TextSanitizer.fix(state.message),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () =>
                                context.read<NotificationsCubit>().load(),
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(TextSanitizer.fix('إعادة المحاولة')),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final loaded = state as NotificationsLoaded;
                if (loaded.notifications.isEmpty) {
                  return Center(
                    child: Text(TextSanitizer.fix('لا توجد إشعارات')),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: loaded.notifications.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = loaded.notifications[index];
                    return Card(
                      color: item.isRead
                          ? null
                          : Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.08),
                      child: ListTile(
                        onTap: () {
                          if (!item.isRead) {
                            context.read<NotificationsCubit>().markAsRead(
                              item.id,
                            );
                          }
                          final target = item.deepLink.trim();
                          if (target.isNotEmpty) {
                            PushNotificationService().handleNavigationTarget(
                              target,
                              context: context,
                            );
                          }
                        },
                        title: Text(TextSanitizer.fix(item.title)),
                        subtitle: Text(TextSanitizer.fix(item.body)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                item.isRead
                                    ? Icons.mark_email_unread_outlined
                                    : Icons.mark_email_read_outlined,
                              ),
                              tooltip: item.isRead
                                  ? TextSanitizer.fix('غير مقروء')
                                  : TextSanitizer.fix('مقروء'),
                              onPressed: () => context
                                  .read<NotificationsCubit>()
                                  .toggleRead(item.id),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => context
                                  .read<NotificationsCubit>()
                                  .deleteOne(item.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
