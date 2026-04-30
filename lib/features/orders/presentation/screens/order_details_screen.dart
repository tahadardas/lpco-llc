import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/utils/formatters.dart';
import 'package:lpco_llc/core/widgets/brand_app_bar.dart';
import 'package:lpco_llc/core/widgets/glass.dart';
import 'package:lpco_llc/features/orders/data/models/order_model.dart';
import 'package:lpco_llc/features/orders/data/repositories/order_repository.dart';
import 'package:lpco_llc/features/orders/data/services/order_invoice_service.dart';
import 'package:lpco_llc/features/orders/presentation/utils/order_lifecycle_presenter.dart';
import 'package:lpco_llc/features/orders/presentation/widgets/order_status_widgets.dart';
import 'package:lpco_llc/shared/commerce/product_identity/product_identity_formatter.dart';

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final OrderRepository _repository = OrderRepository();
  final OrderInvoiceService _invoiceService = OrderInvoiceService();

  late OrderModel _order;
  bool _loadedFromServer = false;
  bool _loadingDetails = true;
  bool _pdfBusy = false;
  String _detailsError = '';

  double _bottomSafeInset(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return math.max(mediaQuery.padding.bottom, mediaQuery.viewPadding.bottom);
  }

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _refreshDetails();
  }

  @override
  void didUpdateWidget(covariant OrderDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_didOrderIdentityChange(oldWidget.order, widget.order)) {
      _order = widget.order;
      _loadedFromServer = false;
      _refreshDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDetails) {
      return Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: BrandAppBar(
          title: 'تفاصيل الطلب #${_order.orderNumber}',
          showBack: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_loadedFromServer) {
      return _errorScaffold(
        title: 'تفاصيل الطلب #${_order.orderNumber}',
        message: _detailsError.trim().isEmpty
            ? 'تعذر تحميل تفاصيل الطلب من الخادم. تحقق من الاتصال ثم أعد المحاولة.'
            : _detailsError,
      );
    }

    final order = _order;
    final total = num.tryParse(order.total) ?? 0;
    final billing = order.billing;
    final lifecycle = presentOrderLifecycle(order);
    final canAccessInvoice =
        lifecycle.canDownloadInvoice && order.isConfirmedServerSide;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: BrandAppBar(
        title: 'تفاصيل الطلب #${order.orderNumber}',
        showBack: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDetails,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            90,
            16,
            24 + _bottomSafeInset(context),
          ),
          children: <Widget>[
            if (_detailsError.trim().isNotEmpty) ...<Widget>[
              _section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'تعذر تحديث تفاصيل الطلب من الخادم',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: GlassStyle.fireRed,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_detailsError),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: _refreshDetails,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'طلب #${order.orderNumber}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      OrderLifecycleBadge(lifecycle: lifecycle),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _kv('التاريخ', _displayDate(order)),
                  _kv('طريقة الدفع', _paymentLabel(order.paymentMethod)),
                  if (order.isConfirmedServerSide)
                    _kv(
                      'حالة المعالجة',
                      presentServerOrderStatus(order.status),
                    ),
                  _kv(
                    'إجمالي الطلب',
                    PriceFormatter.format(total, currencyCode: order.currency),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OrderLifecyclePanel(
              lifecycle: lifecycle,
              errorMessage: order.syncError.trim().isEmpty
                  ? null
                  : order.syncError,
            ),
            const SizedBox(height: 8),
            _section(child: OrderSyncMeta(order: order)),
            if (billing != null) ...<Widget>[
              const SizedBox(height: 12),
              _sectionTitle('بيانات الاستلام'),
              const SizedBox(height: 8),
              _section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _kv(
                      'الاسم',
                      billing.fullName.isNotEmpty ? billing.fullName : '-',
                    ),
                    _kv(
                      'الهاتف',
                      billing.phone.isNotEmpty ? billing.phone : '-',
                    ),
                    _kv(
                      'البريد',
                      billing.email.isNotEmpty ? billing.email : '-',
                    ),
                    _kv(
                      'العنوان',
                      '${billing.address} ${billing.city}'.trim().isEmpty
                          ? '-'
                          : '${billing.address} ${billing.city}'.trim(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _sectionTitle('عناصر الطلب'),
            const SizedBox(height: 8),
            if (order.lineItems.isEmpty)
              _section(child: const Text('لا تتوفر تفاصيل عناصر هذا الطلب'))
            else
              ...order.lineItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _lineItemCard(item, order.currency),
                ),
              ),
            const SizedBox(height: 12),
            _sectionTitle('الفاتورة'),
            const SizedBox(height: 8),
            _section(
              child: !canAccessInvoice
                  ? Text(
                      order.syncError.trim().isNotEmpty
                          ? order.syncError
                          : 'هذا الطلب غير مؤكد من الخادم بعد. ${lifecycle.description}',
                    )
                  : Column(
                      children: <Widget>[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _pdfBusy
                                ? null
                                : () => _withPdf(order, (bytes) async {
                                    if (!mounted) return;
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => _InvoicePreviewScreen(
                                          order: order,
                                          bytes: bytes,
                                        ),
                                      ),
                                    );
                                  }),
                            icon: const Icon(Icons.preview),
                            label: const Text('معاينة الفاتورة'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: _pdfBusy
                                ? null
                                : () => _withPdf(order, (bytes) async {
                                    final file = await _invoiceService
                                        .saveToDevice(
                                          order: order,
                                          bytes: bytes,
                                        );
                                    if (!mounted) return;
                                    final msg = file == null
                                        ? 'تم تشغيل الحفظ/المشاركة حسب نظام التشغيل'
                                        : 'تم الحفظ في: ${file.path}';
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      SnackBar(content: Text(msg)),
                                    );
                                  }),
                            icon: const Icon(Icons.download),
                            label: const Text('حفظ في الجهاز'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: _pdfBusy
                                ? null
                                : () => _withPdf(order, (bytes) async {
                                    await _invoiceService.share(
                                      order: order,
                                      bytes: bytes,
                                    );
                                  }),
                            icon: const Icon(Icons.share),
                            label: const Text('مشاركة الفاتورة'),
                          ),
                        ),
                        if (order.invoiceUrl.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: () async {
                                final uri = Uri.tryParse(order.invoiceUrl);
                                if (uri == null) return;
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              icon: const Icon(Icons.link),
                              label: const Text('فتح رابط الفاتورة من الخادم'),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorScaffold({required String title, required String message}) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: BrandAppBar(title: title, showBack: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _section(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'فشل تحميل تفاصيل الطلب',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: GlassStyle.fireRed,
                  ),
                ),
                const SizedBox(height: 8),
                Text(message),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _refreshDetails,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lineItemCard(OrderLineItem item, String currencyCode) {
    final total = num.tryParse(item.total) ?? 0;
    final attrs = item.attributes.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' | ');
    final unitLabel = ProductIdentityFormatter.formatUnitLabel(
      unitLabel: item.unit?.name,
      unitType: item.unit?.type,
      piecesCount: item.unit?.pieces,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: GlassStyle.acrylicDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.productName.isNotEmpty
                ? item.productName
                : 'منتج #${item.productId}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          _kv(
            'الكمية',
            ProductIdentityFormatter.formatQuantityLabel(
              quantity: item.quantity,
              unitLabel: item.unit?.name,
              unitType: item.unit?.type,
            ),
          ),
          _kv('الوحدة', unitLabel),
          if (attrs.isNotEmpty) _kv('الخصائص', attrs),
          _kv(
            'الإجمالي',
            PriceFormatter.format(total, currencyCode: currencyCode),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.w900));
  }

  Widget _section({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: GlassStyle.acrylicDecoration(radius: 18),
      child: child,
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: <InlineSpan>[
            TextSpan(
              text: '$key: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: value.isNotEmpty ? value : '-'),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshDetails() async {
    setState(() {
      _loadingDetails = true;
      _detailsError = '';
    });

    try {
      final refreshed = await _repository.getOrderDetails(seedOrder: _order);
      if (!mounted) return;
      setState(() {
        _order = refreshed;
        _loadedFromServer = true;
        _loadingDetails = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingDetails = false;
        _detailsError = _normalizeError(error);
      });
    }
  }

  Future<void> _withPdf(
    OrderModel order,
    Future<void> Function(Uint8List bytes) action,
  ) async {
    setState(() => _pdfBusy = true);
    try {
      final bytes = await _invoiceService.generate(order);
      await action(bytes);
    } catch (error) {
      if (!mounted) return;
      final safeMessage = ApiContract.safeMessageFromException(
        error,
        fallback: 'تعذر تجهيز الفاتورة حالياً. يرجى إعادة المحاولة.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(safeMessage)));
    } finally {
      if (mounted) {
        setState(() => _pdfBusy = false);
      }
    }
  }

  bool _didOrderIdentityChange(OrderModel previous, OrderModel next) {
    return previous.id != next.id ||
        previous.orderNumber != next.orderNumber ||
        previous.localQueueId != next.localQueueId ||
        previous.idempotencyKey != next.idempotencyKey;
  }

  String _displayDate(OrderModel order) {
    final primary = order.date.trim();
    if (primary.isNotEmpty) {
      return _formatDateString(primary);
    }

    final fallbackDates = <DateTime?>[
      order.confirmedAt,
      order.lastSyncAttemptAt,
      order.enqueuedAt,
      order.createdLocallyAt,
    ];
    for (final candidate in fallbackDates) {
      if (candidate != null) {
        return _formatDateTime(candidate.toLocal());
      }
    }
    return '-';
  }

  String _formatDateString(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    return _formatDateTime(parsed.toLocal());
  }

  String _formatDateTime(DateTime date) {
    String two(int part) => part.toString().padLeft(2, '0');
    return '${date.year}/${two(date.month)}/${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
  }

  String _normalizeError(Object error) {
    final message = ApiContract.safeMessageFromException(
      error,
      fallback: 'حدث خطأ غير متوقع أثناء تحميل الطلب.',
    ).trim();
    return message.isEmpty ? 'حدث خطأ غير متوقع أثناء تحميل الطلب.' : message;
  }

  String _paymentLabel(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'cod') return 'الدفع عند الاستلام';
    if (value == 'bacs') return 'حوالة مصرفية';
    if (value == 'instant_barcode') return 'شام كاش';
    return raw.trim().isEmpty ? '-' : raw;
  }
}

class _InvoicePreviewScreen extends StatelessWidget {
  final OrderModel order;
  final Uint8List bytes;

  const _InvoicePreviewScreen({required this.order, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandAppBar(
        title: 'معاينة فاتورة #${order.orderNumber}',
        showBack: true,
        onBack: () => context.pop(),
      ),
      body: PdfPreview(
        build: (format) async => bytes,
        allowSharing: true,
        allowPrinting: true,
        canDebug: false,
      ),
    );
  }
}
