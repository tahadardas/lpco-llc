import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:lpco_llc/app/router/app_routes.dart';

import 'package:lpco_llc/core/config/app_config.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/navigation/app_back_scope.dart';
import 'package:lpco_llc/core/utils/formatters.dart';
import 'package:lpco_llc/core/widgets/brand_app_bar.dart';
import 'package:lpco_llc/core/widgets/checkout_wizard_stepper.dart';
import 'package:lpco_llc/features/auth/data/models/user_model.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:lpco_llc/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lpco_llc/features/checkout/application/checkout_cubit.dart';
import 'package:lpco_llc/features/checkout/application/checkout_state.dart';
import 'package:lpco_llc/features/checkout/domain/models/checkout_form.dart';
import 'package:lpco_llc/features/checkout/domain/services/checkout_orchestrator.dart';
import 'package:lpco_llc/features/checkout/presentation/widgets/checkout_bottom_bar.dart';
import 'package:lpco_llc/features/checkout/presentation/widgets/checkout_cart_step.dart';
import 'package:lpco_llc/features/checkout/presentation/widgets/checkout_completion_dialog.dart';
import 'package:lpco_llc/features/checkout/presentation/widgets/checkout_confirm_step.dart';
import 'package:lpco_llc/features/checkout/presentation/widgets/checkout_payment_step.dart';
import 'package:lpco_llc/features/checkout/presentation/widgets/checkout_progress_header.dart';
import 'package:lpco_llc/features/checkout/presentation/widgets/checkout_shipping_step.dart';
import 'package:lpco_llc/features/checkout/presentation/widgets/sham_cash_payment_sheet.dart';
import 'package:lpco_llc/features/orders/data/models/order_model.dart';
import 'package:lpco_llc/features/orders/data/repositories/order_repository.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();

  final CheckoutCubit _checkoutCubit = CheckoutCubit();
  final CheckoutOrchestrator _checkoutOrchestrator = CheckoutOrchestrator();
  final OrderRepository _orderRepository = OrderRepository();

  bool _userSeeded = false;
  int? _seededUserId;

  void _setControllerText(TextEditingController controller, String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  @override
  void initState() {
    super.initState();
    _checkoutCubit.initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authState = context.read<AuthCubit>().state;
    if (authState is Authenticated) {
      _seedUserData(authState.user);
    }
  }

  @override
  void dispose() {
    _checkoutCubit.close();
    _fullName.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final cartState = context.watch<CartCubit>().state;

    if (authState is! Authenticated) {
      return _guardScaffold(
        title: 'إتمام الطلب',
        message: 'يجب تسجيل الدخول لإكمال الطلب.',
        actionLabel: 'تسجيل الدخول',
        onAction: () => context.go(AppRoutePaths.login),
      );
    }

    if (cartState is! CartLoaded || cartState.items.isEmpty) {
      return _guardScaffold(
        title: 'إتمام الطلب',
        message: 'السلة فارغة حالياً.',
        actionLabel: 'العودة إلى السلة',
        onAction: () => context.go(AppRoutePaths.cart),
      );
    }

    final user = authState.user;

    return AppBackScope(
      fallbackLocation: AppRoutePaths.cart,
      child: BlocProvider.value(
        value: _checkoutCubit,
        child: BlocBuilder<CheckoutCubit, CheckoutState>(
          builder: (context, checkoutState) {
            return Scaffold(
              extendBody: true,
              appBar: const BrandAppBar(title: 'إتمام الطلب', showBack: true),
              body: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: CheckoutWizardStepper(
                        currentStep: checkoutState.currentStep + 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: CheckoutProgressHeader(
                        currentStep: checkoutState.currentStep,
                        status: checkoutState.status,
                      ),
                    ),
                    if (checkoutState.status == CheckoutStatus.failure &&
                        (checkoutState.errorMessage ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: _errorBanner(checkoutState.errorMessage!),
                      ),
                    if (checkoutState.status ==
                        CheckoutStatus.awaitingPaymentConfirmation)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: _infoBanner(
                          message:
                              'بانتظار تأكيد الحوالة. يمكنك متابعة الحالة من شاشة الطلبات.',
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: SingleChildScrollView(
                          key: ValueKey<int>(checkoutState.currentStep),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _buildStepContent(
                            checkoutState: checkoutState,
                            cartState: cartState,
                            user: user,
                          ),
                        ),
                      ),
                    ),
                    CheckoutBottomBar(
                      currentStep: checkoutState.currentStep,
                      disableActions: checkoutState.isBusy,
                      submitting: checkoutState.isSubmitting,
                      onBack: _checkoutCubit.previousStep,
                      onPrimaryAction: () => _handlePrimaryAction(
                        cartState: cartState,
                        user: user,
                        state: checkoutState,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Scaffold _guardScaffold({
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Scaffold(
      appBar: BrandAppBar(title: title, showBack: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline_rounded, size: 34),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: onAction, child: Text(actionLabel)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDEC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCACA)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF8D2020),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoBanner({required String message, required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent({
    required CheckoutState checkoutState,
    required CartLoaded cartState,
    required UserModel user,
  }) {
    switch (checkoutState.currentStep) {
      case 0:
        return CheckoutCartStep(
          cartState: cartState,
          onRemove: (itemKey) async {
            await context.read<CartCubit>().removeByKey(itemKey);
          },
          onIncrement: (itemKey) async {
            await context.read<CartCubit>().incrementItem(itemKey);
          },
          onDecrement: (itemKey) async {
            await context.read<CartCubit>().decrementItem(itemKey);
          },
        );
      case 1:
        return CheckoutShippingStep(
          formKey: _formKey,
          fullNameController: _fullName,
          phoneController: _phone,
          addressController: _address,
          cityController: _city,
          stateController: _state,
          emailController: _email,
          notesController: _notes,
          detectingLocation: checkoutState.detectingLocation,
          latitude: checkoutState.latitude,
          longitude: checkoutState.longitude,
          onUseCurrentLocation: _fillAddressFromGps,
          requiredValidator: _required,
        );
      case 2:
        return CheckoutPaymentStep(
          subtotal: cartState.subtotal,
          currency: cartState.currency,
          paymentMethod: checkoutState.paymentMethod,
          onSelectPaymentMethod: _checkoutCubit.selectPaymentMethod,
        );
      case 3:
      default:
        return CheckoutConfirmStep(
          cartState: cartState,
          user: user,
          form: _buildCheckoutFormSnapshot(checkoutState),
        );
    }
  }

  CheckoutForm _buildCheckoutFormSnapshot(CheckoutState state) {
    return CheckoutForm(
      fullName: _fullName.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      email: _email.text.trim(),
      notes: _notes.text.trim(),
      paymentMethod: state.paymentMethod,
      paymentMethodTitle: _paymentMethodTitle(state.paymentMethod),
      latitude: state.latitude,
      longitude: state.longitude,
    );
  }

  Future<void> _handlePrimaryAction({
    required CartLoaded cartState,
    required UserModel user,
    required CheckoutState state,
  }) async {
    if (state.currentStep == 1) {
      _checkoutCubit.validating();
      if (_formKey.currentState?.validate() != true) {
        _checkoutCubit.clearFailure();
        return;
      }
    }

    if (state.currentStep < 3) {
      _checkoutCubit.nextStep();
      return;
    }

    await _submit(cartState: cartState, user: user, state: state);
  }

  Future<void> _fillAddressFromGps() async {
    _checkoutCubit.startLocationDetection();
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _checkoutCubit.finishLocationDetection();
        _showSnack('خدمة الموقع غير مفعلة في الجهاز');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _checkoutCubit.finishLocationDetection();
        _showSnack('تم رفض إذن الوصول للموقع');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _checkoutCubit.finishLocationDetection();
        _showSnack('إذن الموقع مرفوض نهائياً. فعّله من إعدادات الجهاز');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final addressParts = <String>[
          place.street ?? '',
          place.subLocality ?? '',
          place.locality ?? '',
          place.administrativeArea ?? '',
        ].where((value) => value.trim().isNotEmpty).toList();

        _setControllerText(
          _address,
          addressParts.isNotEmpty
              ? addressParts.join('، ')
              : 'خط العرض ${position.latitude}, خط الطول ${position.longitude}',
        );

        if ((place.locality ?? '').trim().isNotEmpty) {
          _setControllerText(_city, place.locality!.trim());
        }
        if ((place.administrativeArea ?? '').trim().isNotEmpty) {
          _setControllerText(_state, place.administrativeArea!.trim());
        }
      } else {
        _setControllerText(
          _address,
          'خط العرض ${position.latitude}, خط الطول ${position.longitude}',
        );
      }

      _checkoutCubit.finishLocationDetection(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _showSnack('تم جلب العنوان من الموقع الحالي', isError: false);
    } catch (_) {
      _checkoutCubit.finishLocationDetection();
      _showSnack('تعذر جلب الموقع الحالي');
    }
  }

  Future<void> _submit({
    required CartLoaded cartState,
    required UserModel user,
    required CheckoutState state,
  }) async {
    final form = _buildCheckoutFormSnapshot(state);
    if (!form.hasValidShippingData) {
      _checkoutCubit.goToStep(1);
      _showSnack('يرجى استكمال بيانات الشحن المطلوبة');
      return;
    }

    if (!_checkoutCubit.beginSubmit()) {
      return;
    }

    final cartCubit = context.read<CartCubit>();

    try {
      final result = await _checkoutOrchestrator.submitOrder(
        user: user,
        cartState: cartState,
        form: form,
        lineItems: cartCubit.getLineItems(),
      );

      final order = result.order;
      final isQueuedOrder = order.isPendingSync || order.id <= 0;
      if (!mounted) {
        return;
      }

      await cartCubit.clear();
      final awaitingShamCashConfirmation =
          form.paymentMethod == 'instant_barcode' && !isQueuedOrder;

      if (awaitingShamCashConfirmation) {
        _checkoutCubit.setAwaitingPaymentConfirmation();
        await _showShamCashInstructions(
          order,
          preferredCurrency: user.currency,
          fallbackCurrency: cartState.currency,
        );
        if (!mounted) {
          return;
        }
      }

      _checkoutCubit.setSuccess();
      await _showOrderCompletionDialog(
        order: order,
        isQueuedOrder: isQueuedOrder,
        reusedExisting: result.reusedExisting,
        awaitingShamCashConfirmation: awaitingShamCashConfirmation,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      final message = ApiContract.safeMessageFromException(e);
      _checkoutCubit.setFailure(message);
      _showSnack(message);
    } finally {
      if (mounted && _checkoutCubit.state.status == CheckoutStatus.submitting) {
        _checkoutCubit.clearFailure();
      }
    }
  }

  Future<void> _showShamCashInstructions(
    OrderModel order, {
    required String preferredCurrency,
    required String fallbackCurrency,
  }) async {
    final sham = order.shamCash;
    if (sham == null) {
      _showSnack('تم إنشاء الطلب لكن لا توجد بيانات شام كاش لهذا الطلب');
      return;
    }

    final preferred = AppCurrencies.normalizeCode(preferredCurrency);
    final amountCurrency = AppCurrencies.normalizeCode(
      preferred.isNotEmpty
          ? preferred
          : (sham.currency.isNotEmpty
                ? sham.currency
                : (order.currency.isNotEmpty
                      ? order.currency
                      : fallbackCurrency)),
    );
    final amountFormatted = PriceFormatter.format(
      sham.amount,
      currencyCode: amountCurrency,
    );

    final action = await showShamCashPaymentSheet(
      context: context,
      shamCash: sham,
      amountFormatted: amountFormatted,
    );

    if (!mounted || action == null || !action.confirmed) {
      return;
    }

    await _confirmShamCashTransfer(
      orderId: order.id,
      transactionId: action.transactionId,
    );
  }

  Future<void> _confirmShamCashTransfer({
    required int orderId,
    String transactionId = '',
  }) async {
    try {
      await _orderRepository.confirmShamCashTransfer(
        orderId: orderId,
        transactionId: transactionId,
      );
      _showSnack('تم إرسال إشعار التحويل بنجاح', isError: false);
    } catch (e) {
      _showSnack(ApiContract.safeMessageFromException(e));
    }
  }

  Future<void> _showOrderCompletionDialog({
    required OrderModel order,
    required bool isQueuedOrder,
    required bool reusedExisting,
    required bool awaitingShamCashConfirmation,
  }) async {
    final action = await showCheckoutCompletionDialog(
      context: context,
      order: order,
      isQueuedOrder: isQueuedOrder,
      reusedExisting: reusedExisting,
      awaitingShamCashConfirmation: awaitingShamCashConfirmation,
      orderReference: _resolveOrderReference(order),
    );

    if (!mounted) {
      return;
    }

    switch (action ?? CheckoutCompletionAction.home) {
      case CheckoutCompletionAction.viewOrder:
        context.go(AppRoutePaths.ordersDetails, extra: order);
        return;
      case CheckoutCompletionAction.home:
        context.go(AppRoutePaths.home);
        return;
    }
  }

  String _resolveOrderReference(OrderModel order) {
    final orderNumber = order.orderNumber.trim();
    if (orderNumber.isNotEmpty && orderNumber.toUpperCase() != 'PENDING') {
      return orderNumber;
    }
    if (order.id > 0) {
      return order.id.toString();
    }

    final queueId = order.localQueueId.trim();
    if (queueId.isNotEmpty) {
      final short = queueId.length > 10 ? queueId.substring(0, 10) : queueId;
      return short.toUpperCase();
    }

    final key = order.idempotencyKey.trim();
    if (key.isNotEmpty) {
      final short = key.length > 10 ? key.substring(0, 10) : key;
      return 'REF-${short.toUpperCase()}';
    }

    return '-';
  }

  String _paymentMethodTitle(String method) {
    if (method == 'bacs') {
      return 'حوالة مصرفية';
    }
    if (method == 'instant_barcode') {
      return 'شام كاش - الباركود الفوري';
    }
    return 'الدفع عند الاستلام';
  }

  void _seedUserData(UserModel user) {
    if (_userSeeded && _seededUserId == user.id) {
      return;
    }

    _userSeeded = true;
    _seededUserId = user.id;

    _setControllerText(_fullName, user.fullName);
    _setControllerText(_phone, user.phone);
    _setControllerText(_address, user.address);

    final city = user.city.trim();
    if (city.isNotEmpty) {
      _setControllerText(_city, city);
      _setControllerText(_state, city);
    }
    _setControllerText(_email, user.email);
  }

  void _showSnack(String message, {bool isError = true}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'حقل مطلوب';
    }
    return null;
  }
}
