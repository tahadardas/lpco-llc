import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:lpco_llc/app/app_keys.dart';
import 'package:lpco_llc/app/router/app_router.dart';
import 'package:lpco_llc/app/theme/lpco_theme.dart';
import 'package:lpco_llc/core/network/network_cubit.dart';
import 'package:lpco_llc/core/network/reachability_service.dart';
import 'package:lpco_llc/core/services/push_notification_service.dart';
import 'package:lpco_llc/core/sync/sync_coordinator.dart';
import 'package:lpco_llc/core/widgets/network_banner_wrapper.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:lpco_llc/features/auth/presentation/screens/security_setup_screen.dart';
import 'package:lpco_llc/features/auth/presentation/screens/unlock_screen.dart';
import 'package:lpco_llc/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lpco_llc/features/notifications/presentation/cubit/notifications_badge_cubit.dart';
import 'package:lpco_llc/features/products/presentation/cubit/product_cubit.dart';
import 'package:lpco_llc/firebase_options.dart';

Future<void> _configureCrashlytics() async {
  bool isTransientWebInsetsError(Object error) {
    if (!kIsWeb) {
      return false;
    }
    final message = error.toString();
    return message.contains('ViewInsets cannot be negative');
  }

  FlutterError.onError = (details) {
    final error = details.exception;
    if (isTransientWebInsetsError(error)) {
      debugPrint('Ignored transient web insets error: $error');
      return;
    }
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (isTransientWebInsetsError(error)) {
      debugPrint('Ignored transient web insets error: $error');
      return true;
    }
    debugPrint('Uncaught platform error: $error\n$stack');
    return false;
  };

  if (kIsWeb) {
    return;
  }

  if (!DefaultFirebaseOptions.isConfigured || Firebase.apps.isEmpty) {
    return;
  }

  try {
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      try {
        crashlytics.recordFlutterFatalError(details);
      } catch (error, stack) {
        debugPrint('Crashlytics FlutterError hook failed: $error\n$stack');
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      try {
        crashlytics.recordError(error, stack, fatal: true);
      } catch (innerError, innerStack) {
        debugPrint(
          'Crashlytics PlatformDispatcher hook failed: $innerError\n$innerStack',
        );
      }
      return true;
    };
  } catch (error, stack) {
    debugPrint('Crashlytics init failed: $error\n$stack');
  }
}

class LpcoWholesaleApp extends StatefulWidget {
  const LpcoWholesaleApp({super.key});

  @override
  State<LpcoWholesaleApp> createState() => _LpcoWholesaleAppState();
}

class _LpcoWholesaleAppState extends State<LpcoWholesaleApp>
    with WidgetsBindingObserver {
  final PushNotificationService _pushNotificationService =
      PushNotificationService();
  final NetworkCubit _networkCubit = NetworkCubit();
  final CartCubit _cartCubit = CartCubit();
  final AuthCubit _authCubit = AuthCubit();
  final ProductCubit _productCubit = ProductCubit();
  final NotificationsBadgeCubit _notificationsBadgeCubit =
      NotificationsBadgeCubit();
  bool _runtimeBootstrapStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapRuntimeServices());
    });
  }

  Future<void> _bootstrapRuntimeServices() async {
    if (_runtimeBootstrapStarted) {
      return;
    }
    _runtimeBootstrapStarted = true;

    try {
      await ReachabilityService().initialize();
    } catch (error, stack) {
      debugPrint('Reachability bootstrap skipped: $error\n$stack');
    }

    try {
      await SyncCoordinator().start(networkCubit: _networkCubit);
    } catch (error, stack) {
      debugPrint('Sync bootstrap skipped: $error\n$stack');
    }

    if (!DefaultFirebaseOptions.isConfigured) {
      if (kDebugMode) {
        debugPrint(
          'Firebase services are disabled in this build because firebase_options contains placeholder values.',
        );
      }
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (error, stack) {
      debugPrint('Firebase bootstrap skipped: $error\n$stack');
      return;
    }

    await _configureCrashlytics();
    await _pushNotificationService.initialize();
    await _notificationsBadgeCubit.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _networkCubit.close();
    _cartCubit.close();
    _authCubit.close();
    _productCubit.close();
    _notificationsBadgeCubit.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _authCubit.onAppPaused();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _authCubit.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<NetworkCubit>.value(value: _networkCubit),
        BlocProvider<CartCubit>.value(value: _cartCubit),
        BlocProvider<AuthCubit>.value(value: _authCubit),
        BlocProvider<ProductCubit>.value(value: _productCubit),
        BlocProvider<NotificationsBadgeCubit>.value(
          value: _notificationsBadgeCubit,
        ),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<AuthCubit, AuthState>(
            listenWhen: (previous, current) {
              return current is Authenticated ||
                  current is GuestAuthenticated ||
                  current is Unauthenticated;
            },
            listener: (context, state) {
              _pushNotificationService.syncDeviceRegistration();

              if (state is Authenticated) {
                final user = state.user;
                final userScope = 'user_${user.id ?? user.username}';
                _cartCubit.setScope(userScope);
                SyncCoordinator().triggerSync();
                _notificationsBadgeCubit.refresh();
                return;
              }

              if (state is GuestAuthenticated) {
                _cartCubit.setScope('guest');
                _notificationsBadgeCubit.refresh();
                return;
              }

              if (state is Unauthenticated) {
                _cartCubit.setScope('guest');
                _notificationsBadgeCubit.clear();
              }
            },
          ),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'متجر LPCO',
          theme: LpcoTheme.light,
          darkTheme: LpcoTheme.dark,
          themeMode: LpcoTheme.mode,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          routerConfig: AppRouter.router,
          builder: (context, child) {
            final easyBuilder = EasyLoading.init();
            final authState = context.watch<AuthCubit>().state;
            final appChild = child ?? const SizedBox.shrink();
            Widget? lockLayer;

            if (authState is AuthLocked) {
              lockLayer = _FullScreenLockNavigator(
                child: UnlockScreen(state: authState),
              );
            } else if (authState is AuthSecuritySetupRequired) {
              lockLayer = _FullScreenLockNavigator(
                child: SecuritySetupScreen(state: authState),
              );
            }

            final wrapped = NetworkBannerWrapper(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    appChild,
                    if (lockLayer != null) Positioned.fill(child: lockLayer),
                  ],
                ),
              ),
            );
            return easyBuilder(context, wrapped);
          },
        ),
      ),
    );
  }
}

class _FullScreenLockNavigator extends StatelessWidget {
  final Widget child;

  const _FullScreenLockNavigator({required this.child});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'security-overlay'),
        builder: (_) => child,
      ),
    );
  }
}
