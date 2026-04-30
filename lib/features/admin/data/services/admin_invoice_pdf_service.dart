import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:lpco_llc/features/admin/data/models/admin_order_details_model.dart';
import 'package:lpco_llc/shared/commerce/product_identity/product_identity_formatter.dart';

class AdminInvoicePdfService {
  Future<Uint8List> generate(
    AdminOrderDetailsModel order, {
    String? warehouseCode,
    String? warehouseLabel,
  }) async {
    final baseFont = await _loadFont();
    final logoBytes = await _loadLogo();

    // Filter items if warehouseCode is provided
    final items = warehouseCode != null
        ? order.items.where((i) => i.warehouseCode == warehouseCode).toList()
        : order.items;

    final productImages = await _loadProductImages(items);

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: baseFont),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        textDirection: pw.TextDirection.rtl,
        build: (context) {
          return <pw.Widget>[
            _buildHeader(order, logoBytes, warehouseLabel: warehouseLabel),
            pw.SizedBox(height: 16),
            ..._buildSection(
              title: 'معلومات العميل',
              child: _buildCustomerInfo(order),
            ),
            pw.SizedBox(height: 12),
            ..._buildSection(
              title: 'المنتجات المطلوبة',
              child: _buildItemsTableRtl(order, items, productImages),
              boxed: false, // Allow table to split across pages
            ),
            pw.SizedBox(height: 12),
            ..._buildSection(
              title: 'الحساب النهائي',
              child: _buildTotals(order, items, warehouseCode != null),
            ),
            pw.SizedBox(height: 14),
            _buildFooter(order),
          ];
        },
      ),
    );

    return doc.save();
  }

  Future<File?> saveToDevice({
    required AdminOrderDetailsModel order,
    required Uint8List bytes,
  }) async {
    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'invoice-${order.number}.pdf',
      );
      return null;
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/invoice-${order.number}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> share({
    required AdminOrderDetailsModel order,
    required Uint8List bytes,
  }) async {
    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'invoice-${order.number}.pdf',
      );
      return;
    }

    final file = await saveToDevice(order: order, bytes: bytes);
    if (file == null) {
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        text: 'فاتورة الطلب #${order.number}',
        subject: 'فاتورة طلب #${order.number}',
      ),
    );
  }

  Future<pw.Font> _loadFont() async {
    try {
      final regularData = await rootBundle.load('assets/Cairo-Regular.ttf');
      return pw.Font.ttf(regularData);
    } catch (_) {
      final fallbackData = await rootBundle.load('assets/Cairo-Bold.ttf');
      return pw.Font.ttf(fallbackData);
    }
  }

  Future<Uint8List?> _loadLogo() async {
    try {
      final logoData = await rootBundle.load('assets/logo.png');
      return logoData.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<Map<int, pw.ImageProvider>> _loadProductImages(
    List<AdminOrderItem> items,
  ) async {
    final images = <int, pw.ImageProvider>{};
    for (var i = 0; i < items.length; i++) {
      final url = items[i].imageUrl.trim();
      if (url.isEmpty) {
        debugPrint(
          '[AdminInvoicePdfService] Missing image URL for order item ${items[i].id}',
        );
        continue;
      }
      try {
        final uri = Uri.tryParse(url);
        if (uri == null || !uri.hasScheme) {
          debugPrint(
            '[AdminInvoicePdfService] Invalid image URL for order item ${items[i].id}: $url',
          );
          continue;
        }
        images[i] = await networkImage(uri.toString());
      } catch (error) {
        debugPrint(
          '[AdminInvoicePdfService] Failed to load image for order item ${items[i].id}: $error',
        );
      }
    }
    return images;
  }

  pw.Widget _buildHeader(
    AdminOrderDetailsModel order,
    Uint8List? logoBytes, {
    String? warehouseLabel,
  }) {
    final title = warehouseLabel != null
        ? 'فاتورة مبيعات - $warehouseLabel'
        : 'فاتورة طلب المبيعات';
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        // Right side: Logo and Title
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            if (logoBytes != null)
              pw.Image(
                pw.MemoryImage(logoBytes),
                width: 120,
                height: 50,
                fit: pw.BoxFit.contain,
              ),
            pw.SizedBox(height: 10),
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFFC00000),
              ),
            ),
          ],
        ),
        // Left side: Order Details
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF5F5F5),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: <pw.Widget>[
              _detailRow('رقم الفاتورة:', '#${order.number}'),
              _detailRow('التاريخ:', order.dateCreated),
              _detailRow(
                'الحالة:',
                order.statusLabel.isEmpty ? order.status : order.statusLabel,
              ),
              _detailRow(
                'طريقة الدفع:',
                order.paymentMethod.isEmpty ? '-' : order.paymentMethod,
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _detailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: <pw.Widget>[
          pw.Text(
            value,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.SizedBox(width: 4),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildSection({
    required String title,
    required pw.Widget child,
    bool boxed = true,
  }) {
    final header = pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: PdfColor.fromInt(0xFFC00000),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );

    if (!boxed) {
      return [
        header,
        child,
      ];
    }

    return [
      header,
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(
            color: PdfColor.fromInt(0xFFC00000),
            width: 1,
          ),
        ),
        child: child,
      ),
    ];
  }

  pw.Widget _buildCustomerInfo(AdminOrderDetailsModel order) {
    final customer = order.customer;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              _customerField('العميل:', customer.name),
              if (customer.company.isNotEmpty)
                _customerField('الشركة:', customer.company),
              _customerField('الهاتف:', customer.phone),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              _customerField(
                'العنوان:',
                <String>[
                  customer.address,
                  customer.city,
                  customer.state,
                  customer.country,
                ].where((p) => p.trim().isNotEmpty).join(', '),
              ),
              _customerField('البريد:', customer.email),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _customerField(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
            pw.TextSpan(
              text: value.isEmpty ? '-' : value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  pw.Widget _buildItemsTable(
    AdminOrderDetailsModel order,
    List<AdminOrderItem> items,
    Map<int, pw.ImageProvider> productImages,
  ) {
    final headers = ['الصورة', 'المنتج', 'الكمية', 'الوحدة', 'المجموع'];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FixedColumnWidth(50),
        1: pw.FlexColumnWidth(3),
        2: pw.FixedColumnWidth(50),
        3: pw.FixedColumnWidth(80),
        4: pw.FixedColumnWidth(90),
      },
      children: [
        // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: headers
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Center(
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        // Data Rows
        ...List.generate(items.length, (i) {
          final item = items[i];
          return pw.TableRow(
            children: [
              pw.Container(
                width: 40,
                height: 40,
                padding: const pw.EdgeInsets.all(2),
                child: _imageCell(productImages[i]),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item.name,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (item.attributes.isNotEmpty)
                      pw.Text(
                        item.attributes
                            .map((e) => '${e['key']}: ${e['value']}')
                            .join(' | '),
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey700,
                        ),
                      ),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Center(
                  child: pw.Text(
                    '${item.quantity}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Center(
                  child: pw.Text(
                    _unitLabel(item),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Container(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    _money(item.total, order.currency),
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildItemsTableRtl(
    AdminOrderDetailsModel order,
    List<AdminOrderItem> items,
    Map<int, pw.ImageProvider> productImages,
  ) {
    final headers = <String>[
      'السعر الإجمالي',
      'الكمية',
      'الوحدة',
      'اسم المنتج',
      'الصورة',
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FixedColumnWidth(92),
        1: pw.FixedColumnWidth(54),
        2: pw.FixedColumnWidth(88),
        3: pw.FlexColumnWidth(3),
        4: pw.FixedColumnWidth(52),
      },
      children: <pw.TableRow>[
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: headers
              .map(
                (header) => pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Center(
                    child: pw.Text(
                      header,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        ...List<pw.TableRow>.generate(items.length, (i) {
          final item = items[i];
          final attributesText = item.attributes
              .map((entry) => '${entry['key']}: ${entry['value']}')
              .join(' | ');
          return pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: <pw.Widget>[
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Center(
                  child: pw.Text(
                    _money(item.total, order.currency),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Center(
                  child: pw.Text(
                    '${item.quantity}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Center(
                  child: pw.Text(
                    _unitLabel(item),
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: <pw.Widget>[
                    pw.Text(
                      item.name.isEmpty ? '-' : item.name,
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (attributesText.isNotEmpty)
                      pw.Text(
                        attributesText,
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey700,
                        ),
                      ),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.SizedBox(
                  width: 42,
                  height: 42,
                  child: _rtlImageCell(productImages[i]),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _imageCell(pw.ImageProvider? image) {
    if (image == null) return pw.SizedBox();
    return pw.Image(image, fit: pw.BoxFit.contain);
  }

  pw.Widget _rtlImageCell(pw.ImageProvider? image) {
    return pw.Container(
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: const pw.EdgeInsets.all(2),
      child: image == null
          ? pw.Text(
              'لا صورة',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            )
          : pw.Image(image, fit: pw.BoxFit.contain),
    );
  }

  pw.Widget _buildTotals(
    AdminOrderDetailsModel order,
    List<AdminOrderItem> items,
    bool isWarehouseInvoice,
  ) {
    if (isWarehouseInvoice) {
      final subtotal = items.fold<num>(0, (prev, element) => prev + element.total);
      return pw.Column(
        children: <pw.Widget>[
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  _money(subtotal, order.currency),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFFC00000),
                  ),
                ),
                pw.Text(
                  'إجمالي هذا المستودع:',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final totals = order.totals;
    return pw.Column(
      children: <pw.Widget>[
        _totalEntry(
          'الإجمالي الفرعي:',
          _money(totals.subtotal, order.currency),
        ),
        if (totals.discountTotal > 0)
          _totalEntry(
            'الخصم:',
            '- ${_money(totals.discountTotal, order.currency)}',
          ),
        if (totals.shippingTotal > 0)
          _totalEntry('الشحن:', _money(totals.shippingTotal, order.currency)),
        if (totals.taxTotal > 0)
          _totalEntry('الضريبة:', _money(totals.taxTotal, order.currency)),
        pw.Divider(color: PdfColors.grey300),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                _money(totals.total, order.currency),
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFFC00000),
                ),
              ),
              pw.Text(
                'الإجمالي النهائي:',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _totalEntry(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(AdminOrderDetailsModel order) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1, color: PdfColors.grey300),
        pw.SizedBox(height: 10),
        pw.Text(
          'شكراً لتعاملكم مع شركة LPCO',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'هذه الفاتورة تم إنشاؤها عبر التطبيق',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    );
  }

  bool _isSyp(String currencyCode) => currencyCode.toLowerCase() == 'syp';

  String _money(num value, String currencyCode) {
    if (_isSyp(currencyCode)) {
      return '${value.toStringAsFixed(0)} ل.س';
    }
    return '\$${value.toStringAsFixed(2)}';
  }

  String _unitLabel(AdminOrderItem item) {
    return ProductIdentityFormatter.formatUnitLabel(
      unitLabel: item.unitName,
      unitType: item.unitType,
      piecesCount: int.tryParse(item.unitPieces),
    );
  }
}
