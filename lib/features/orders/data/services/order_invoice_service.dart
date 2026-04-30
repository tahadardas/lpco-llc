import 'dart:typed_data';
import 'dart:io';

import 'package:lpco_llc/features/admin/data/models/admin_order_details_model.dart';
import 'package:lpco_llc/features/admin/data/services/admin_invoice_pdf_service.dart';
import 'package:lpco_llc/features/orders/data/models/order_model.dart';

class OrderInvoiceService {
  final AdminInvoicePdfService _pdfService;

  OrderInvoiceService({AdminInvoicePdfService? pdfService})
    : _pdfService = pdfService ?? AdminInvoicePdfService();

  Future<Uint8List> generate(OrderModel order) {
    return _pdfService.generate(_toAdminOrderModel(order));
  }

  Future<File?> saveToDevice({
    required OrderModel order,
    required Uint8List bytes,
  }) {
    return _pdfService.saveToDevice(
      order: _toAdminOrderModel(order),
      bytes: bytes,
    );
  }

  Future<void> share({required OrderModel order, required Uint8List bytes}) {
    return _pdfService.share(order: _toAdminOrderModel(order), bytes: bytes);
  }

  AdminOrderDetailsModel _toAdminOrderModel(OrderModel order) {
    final billing = order.billing;
    final customer = AdminOrderCustomer(
      name: (billing?.fullName ?? '').trim(),
      email: billing?.email ?? '',
      phone: billing?.phone ?? '',
      company: '',
      address: billing?.address ?? '',
      city: billing?.city ?? '',
      state: '',
      country: '',
    );

    final items = order.lineItems.map((item) {
      final attrs = item.attributes.entries
          .map((e) => <String, String>{'key': e.key, 'value': e.value})
          .toList();
      return AdminOrderItem(
        id: 0,
        productId: item.productId,
        variationId: item.variationId ?? 0,
        name: item.productName,
        quantity: item.quantity,
        subtotal: num.tryParse(item.total) ?? 0,
        total: num.tryParse(item.total) ?? 0,
        unitName: item.unit?.name ?? '',
        unitType: item.unit?.type ?? '',
        unitPieces: item.unit?.pieces?.toString() ?? '',
        imageUrl: item.imageUrl,
        warehouseCode: item.warehouseCode,
        warehouseLabel: item.warehouseLabel,
        attributes: attrs,
      );
    }).toList();

    final subtotal = items.fold<num>(0, (sum, e) => sum + e.total);
    final total = num.tryParse(order.total) ?? subtotal;

    return AdminOrderDetailsModel(
      id: order.id,
      number: order.orderNumber,
      status: order.status,
      statusLabel: order.status,
      currency: order.currency,
      dateCreated: order.date,
      paymentMethod: order.paymentMethod,
      customerId: 0,
      customer: customer,
      totals: AdminOrderTotals(
        subtotal: subtotal,
        shippingTotal: 0,
        taxTotal: 0,
        discountTotal: 0,
        total: total,
      ),
      items: items,
      invoiceUrl: order.invoiceUrl,
      warehouseCode: order.warehouseCode,
      warehouseLabel: order.warehouseLabel,
      warehouseCodes: order.warehouseCodes,
    );
  }
}
