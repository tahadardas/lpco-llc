import 'package:lpco_llc/features/auth/data/models/user_model.dart';
import 'package:lpco_llc/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lpco_llc/features/checkout/domain/models/checkout_form.dart';
import 'package:lpco_llc/features/orders/data/repositories/order_repository.dart';

class CheckoutOrchestrator {
  final OrderRepository _orderRepository;

  CheckoutOrchestrator({OrderRepository? orderRepository})
    : _orderRepository = orderRepository ?? OrderRepository();

  Future<OrderCreateResult> submitOrder({
    required UserModel user,
    required CartLoaded cartState,
    required CheckoutForm form,
    required List<Map<String, dynamic>> lineItems,
  }) async {
    final customerId = user.id;
    if (customerId == null || customerId <= 0) {
      throw Exception('تعذر تحديد المستخدم الحالي');
    }

    if (!form.hasValidShippingData) {
      throw Exception('يرجى استكمال بيانات الشحن المطلوبة');
    }

    final fallbackCity = user.city.trim().isEmpty ? 'دمشق' : user.city.trim();
    final city = form.city.trim().isEmpty ? fallbackCity : form.city.trim();
    final state = form.state.trim().isEmpty ? fallbackCity : form.state.trim();

    final email = form.email.trim().isNotEmpty
        ? form.email.trim()
        : (user.email.trim().isNotEmpty
              ? user.email.trim()
              : '${user.username}@lpco-temp.com');

    return _orderRepository.createOrderResult(
      customerId: customerId,
      currency: user.currency,
      userGroup: user.group,
      contactName: form.fullName.trim(),
      phone: form.phone.trim(),
      address: form.address.trim(),
      city: city,
      state: state,
      email: email,
      paymentMethod: form.paymentMethod,
      paymentMethodTitle: form.paymentMethodTitle,
      lineItems: lineItems,
      orderComments: form.buildOrderComment(),
      company: user.companyName,
      country: 'SY',
      postcode: '00000',
    );
  }
}
