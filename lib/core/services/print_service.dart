import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/product.dart';
import '../../models/salary_payment.dart';
import '../../features/settings/settings_provider.dart';

class PrintService {
  /// جلب كافة الطابعات المعرفة والمكتشفة على جهاز الكمبيوتر
  /// جلب كافة الطابعات المعرفة والمكتشفة على جهاز الكمبيوتر مستخدمين الحزمة الرسمية للنظام
  static Future<List<Printer>> getSystemPrinters() async {
    try {
      final printers = await Printing.listPrinters();
      debugPrint(
        'Total discovered system printers via native plugin: ${printers.length}',
      );
      return printers;
    } catch (e) {
      debugPrint('Error listing system printers via Printing package: $e');
      return [];
    }
  }

  /// البحث عن طابعة محددة بالاسم أو إرجاع الطابعة الافتراضية
  static Future<Printer?> findTargetPrinter(String printerName) async {
    final printers = await getSystemPrinters();
    if (printers.isEmpty) return null;

    final rawName = printerName.trim();
    if (rawName.isEmpty) {
      return printers.where((p) => p.isDefault).firstOrNull ?? printers.first;
    }

    final rawLower = rawName.toLowerCase();

    // 1. Check if name has text inside parentheses e.g. "طابعة الكاشير الرئيسية (Xprinter XP-365B)" -> "Xprinter XP-365B"
    final matchInParen = RegExp(r'\((.*?)\)').firstMatch(rawName);
    if (matchInParen != null) {
      final inside = matchInParen
          .group(1)!
          .trim()
          .toLowerCase()
          .replaceAll('_', ' ')
          .replaceAll('-', ' ');
      if (inside.isNotEmpty && inside != 'default printer') {
        final parenMatch = printers.where((p) {
          final pName = p.name
              .toLowerCase()
              .replaceAll('_', ' ')
              .replaceAll('-', ' ');
          final pUrl = p.url
              .toLowerCase()
              .replaceAll('_', ' ')
              .replaceAll('-', ' ');
          return pName.contains(inside) ||
              pUrl.contains(inside) ||
              inside.contains(pName);
        }).firstOrNull;
        if (parenMatch != null) return parenMatch;
      }
    }

    // 2. Strip common Arabic prefixes to leave clean printer model name
    String cleanName = rawName
        .replaceAll(
          RegExp(r'طابعة\s*الكاشير\s*الرئيسية', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'طابعة\s*الكاشير', caseSensitive: false), '')
        .replaceAll(RegExp(r'طابعة\s*المطبخ', caseSensitive: false), '')
        .replaceAll(RegExp(r'طابعة\s*التقارير', caseSensitive: false), '')
        .replaceAll(RegExp(r'طابعة', caseSensitive: false), '')
        .replaceAll(RegExp(r'الرئيسية', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\(\)]'), '')
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');

    if (cleanName.isNotEmpty) {
      final match = printers.where((p) {
        final pName = p.name
            .toLowerCase()
            .replaceAll('_', ' ')
            .replaceAll('-', ' ');
        final pUrl = p.url
            .toLowerCase()
            .replaceAll('_', ' ')
            .replaceAll('-', ' ');
        return pName == cleanName ||
            pName.contains(cleanName) ||
            cleanName.contains(pName) ||
            pUrl.contains(cleanName);
      }).firstOrNull;
      if (match != null) return match;
    }

    // 3. Exact match on raw string
    final exact = printers
        .where(
          (p) =>
              p.name.toLowerCase() == rawLower ||
              p.url.toLowerCase() == rawLower,
        )
        .firstOrNull;
    if (exact != null) return exact;

    // 4. Substring match on raw string
    final cleanTrimmed = rawLower.replaceAll('_', ' ').replaceAll('-', ' ');
    final matchPartial = printers.where((p) {
      final pNameLower = p.name
          .toLowerCase()
          .replaceAll('_', ' ')
          .replaceAll('-', ' ');
      final pUrlLower = p.url
          .toLowerCase()
          .replaceAll('_', ' ')
          .replaceAll('-', ' ');
      return cleanTrimmed.contains(pNameLower) ||
          pNameLower.contains(cleanTrimmed) ||
          pUrlLower.contains(cleanTrimmed);
    }).firstOrNull;
    if (matchPartial != null) return matchPartial;

    // 5. Smart auto-detect thermal / receipt / label printer models
    final thermalKeywords = [
      'xprinter',
      'xp-',
      '365b',
      '420b',
      'pos',
      'receipt',
      'thermal',
      'tsc',
      'epson',
      'star',
      'gprinter',
      'bixolon',
      'citizen',
      'sam4s',
    ];
    final thermalPrinter = printers.where((p) {
      final name = p.name.toLowerCase();
      final url = p.url.toLowerCase();
      return thermalKeywords.any((kw) => name.contains(kw) || url.contains(kw));
    }).firstOrNull;
    if (thermalPrinter != null) return thermalPrinter;

    // 6. Check explicitly if user requested default printer
    if (rawLower.contains('الافتراضية') || rawLower.contains('default')) {
      return printers.where((p) => p.isDefault).firstOrNull ?? printers.first;
    }

    // 7. Fallback to default printer or first available printer
    return printers.where((p) => p.isDefault).firstOrNull ?? printers.first;
  }

  /// إرسال مستند PDF للطباعة مع دعم متكامل ومضمون 100% لنظام macOS و Windows و Linux
  static Future<bool> sendPdfToPrinter({
    required Uint8List pdfBytes,
    required String printerNameConfig,
    required String docName,
  }) async {
    try {
      final targetPrinter = await findTargetPrinter(printerNameConfig);

      if (targetPrinter != null) {
        try {
          final success = await Printing.directPrintPdf(
            printer: targetPrinter,
            onLayout: (format) async => pdfBytes,
            name: docName,
            format: PdfPageFormat.roll80,
            usePrinterSettings: true,
          );
          if (success) {
            debugPrint(
              'Successfully printed directly to ${targetPrinter.name}',
            );
            return true;
          }
        } catch (e) {
          debugPrint(
            'Printing.directPrintPdf failed on ${targetPrinter.name}: $e',
          );
        }
      }

      // Fallback: System Print Sheet
      debugPrint('Opening System Print Dialog for $docName');
      return await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: docName,
      );
    } catch (e) {
      debugPrint('Error in sendPdfToPrinter: $e');
      return false;
    }
  }

  /// طباعة الفاتورة للزبون أوتوماتيكياً على طابعة الكاشير المحددة
  static Future<bool> printCustomerReceipt({
    required OrderModel order,
    required List<OrderItemModel> items,
    required SettingsProvider settings,
    String? tableName,
    double cashPaid = 0.0,
    double changeDue = 0.0,
  }) async {
    try {
      pw.Font arabicFont;
      pw.Font arabicFontBold;
      try {
        arabicFont = await PdfGoogleFonts.amiriRegular();
        arabicFontBold = await PdfGoogleFonts.amiriBold();
      } catch (_) {
        arabicFont = await PdfGoogleFonts.cairoRegular();
        arabicFontBold = await PdfGoogleFonts.cairoBold();
      }

      // Load logo image if path exists
      pw.MemoryImage? logoImage;
      if (settings.storeLogoPath.isNotEmpty) {
        try {
          final logoFile = File(settings.storeLogoPath);
          if (logoFile.existsSync()) {
            final logoBytes = await logoFile.readAsBytes();
            logoImage = pw.MemoryImage(logoBytes);
          }
        } catch (e) {
          debugPrint('Error loading logo for receipt PDF: $e');
        }
      }

      // Parse Date & Time
      String formattedDate = '';
      String formattedTime = '';
      try {
        final dt = DateTime.parse(order.createdAt);
        formattedDate =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        final hourStr = dt.hour.toString().padLeft(2, '0');
        final minStr = dt.minute.toString().padLeft(2, '0');
        final secStr = dt.second.toString().padLeft(2, '0');
        formattedTime = '$hourStr:$minStr:$secStr';
      } catch (_) {
        final parts = order.createdAt.split('T');
        formattedDate = parts.first;
        formattedTime = parts.length > 1 ? parts.last.split('.').first : '';
      }

      // Format Table Name & Order Type
      String cleanTable = tableName ?? '';
      if (cleanTable.startsWith('طاولة')) {
        cleanTable = cleanTable.replaceFirst('طاولة', '').trim();
      }

      String typeText = 'طاولة (محلي)';
      if (order.orderType == 'TAKEAWAY') typeText = 'سفري';
      if (order.orderType == 'DELIVERY') typeText = 'توصيل دليفري';

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.only(
            right: 34,
            left: 16,
            top: 6,
            bottom: 6,
          ),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // 1. Logo & Store Header Info
                    if (logoImage != null)
                      pw.Center(
                        child: pw.Container(
                          height: 80,
                          margin: const pw.EdgeInsets.only(bottom: 6),
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),
                      ),

                    pw.Center(
                      child: pw.Text(
                        settings.storeName,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    if (settings.storeAddress.isNotEmpty)
                      pw.Center(
                        child: pw.Text(
                          settings.storeAddress,
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    if (settings.storePhone.isNotEmpty)
                      pw.Center(
                        child: pw.Text(
                          settings.storePhone,
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    if (settings.receiptHeader.isNotEmpty)
                      pw.Center(
                        child: pw.Text(
                          settings.receiptHeader,
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),

                    pw.SizedBox(height: 6),

                    // 2. Structured Rounded Metadata Boxes
                    // Box 1: Invoice # & Customer/Table
                    pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 3),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 0.8),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                              child: pw.Text(
                                cleanTable.isNotEmpty ? 'طاولة: $cleanTable' : 'الطلب: $typeText',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                          ),
                          pw.Container(width: 0.8, height: 18, color: PdfColors.black),
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                              child: pw.Text(
                                'رقم: ${order.id ?? 1}',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Box 2: Date & Time
                    pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 3),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 0.8),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                              child: pw.Text(
                                'الوقت: $formattedTime',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                          ),
                          pw.Container(width: 0.8, height: 18, color: PdfColors.black),
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                              child: pw.Text(
                                'التاريخ: $formattedDate',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Box 3: Cashier Name
                    pw.Container(
                      width: double.infinity,
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 0.8),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Text(
                        'المستخدم / الكاشير: ${order.cashierName != null && order.cashierName!.isNotEmpty ? order.cashierName! : 'الرئيسي'}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),

                    // Delivery Customer Info Block (if applicable)
                    if (order.orderType == 'DELIVERY' ||
                        (order.customerPhone != null && order.customerPhone!.isNotEmpty) ||
                        (order.customerAddress != null && order.customerAddress!.isNotEmpty)) ...[
                      pw.Container(
                        width: double.infinity,
                        margin: const pw.EdgeInsets.only(bottom: 6),
                        padding: const pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.black, width: 0.8),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              '--- بيانات التوصيل والزبون ---',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                              textAlign: pw.TextAlign.center,
                            ),
                            if (order.customerName != null && order.customerName!.isNotEmpty)
                              pw.Text('اسم الزبون: ${order.customerName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                            if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                              pw.Text('هاتف الزبون: ${order.customerPhone}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                            if (order.customerAddress != null && order.customerAddress!.isNotEmpty)
                              pw.Text('عنوان التوصيل: ${order.customerAddress}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                          ],
                        ),
                      ),
                    ],

                    // 3. Grid Table with cell borders for items
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
                      columnWidths: const {
                        0: pw.FixedColumnWidth(16), // ت
                        1: pw.FlexColumnWidth(3.5), // المادة
                        2: pw.FixedColumnWidth(26), // الكمية
                        3: pw.FixedColumnWidth(34), // السعر
                        4: pw.FixedColumnWidth(38), // القيمة
                      },
                      children: [
                        // Header Row
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(2),
                              child: pw.Text('ت', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5), textAlign: pw.TextAlign.center),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(2),
                              child: pw.Text('المادة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5), textAlign: pw.TextAlign.center),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(2),
                              child: pw.Text('الكمية', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5), textAlign: pw.TextAlign.center),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(2),
                              child: pw.Text('السعر', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5), textAlign: pw.TextAlign.center),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(2),
                              child: pw.Text('القيمة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5), textAlign: pw.TextAlign.center),
                            ),
                          ],
                        ),

                        // Item Rows
                        ...items.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final item = entry.value;
                          final rawName = (item.productName != null && item.productName!.isNotEmpty)
                              ? item.productName!
                              : 'صنف #${item.productId}';
                          final pName = rawName.replaceAll(RegExp(r'\s+'), ' ').trim();

                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(2),
                                child: pw.Text('$idx', style: const pw.TextStyle(fontSize: 8.5), textAlign: pw.TextAlign.center),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(2),
                                child: pw.Text(pName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5), textAlign: pw.TextAlign.right),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(2),
                                child: pw.Text(item.formattedQuantity, style: const pw.TextStyle(fontSize: 8.5), textAlign: pw.TextAlign.center),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(2),
                                child: pw.Text(item.price.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 8.5), textAlign: pw.TextAlign.center),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(2),
                                child: pw.Text(item.subtotal.toStringAsFixed(0), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5), textAlign: pw.TextAlign.center),
                              ),
                            ],
                          );
                        }),

                        // Table Summary Row (Total Items Count)
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(2),
                              child: pw.Text('', style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(2),
                              child: pw.Text('مجموع عدد المواد', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5), textAlign: pw.TextAlign.right),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(2),
                              child: pw.Text(
                                items.fold<double>(0, (sum, i) => sum + i.quantity).toStringAsFixed(0),
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(2),
                              child: pw.Text('', style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(2),
                              child: pw.Text('', style: const pw.TextStyle(fontSize: 8)),
                            ),
                          ],
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 6),

                    // 4. Financial Totals in Rounded Border Boxes
                    if (order.discountAmount > 0 || (order.subtotal > order.total && order.subtotal > 0)) ...[
                      pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 3),
                        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.black, width: 0.8),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('المجموع قبل الخصم:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                            pw.Text('${(order.subtotal > 0 ? order.subtotal : (order.total + order.discountAmount)).toStringAsFixed(0)} ${settings.currencySymbol}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                          ],
                        ),
                      ),
                      pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 3),
                        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.black, width: 0.8),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('مبلغ الخصم:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                            pw.Text('-${order.discountAmount.toStringAsFixed(0)} ${settings.currencySymbol}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                          ],
                        ),
                      ),
                    ],

                    // Main Net Total Box (الصافي)
                    pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 4),
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 1.5),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'الصافي:',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                          ),
                          pw.Text(
                            '${order.total.toStringAsFixed(0)} ${settings.currencySymbol}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                    if (cashPaid > 0) ...[
                      pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 3),
                        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.black, width: 0.8),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('المدفوع:', style: const pw.TextStyle(fontSize: 9)),
                            pw.Text('${cashPaid.toStringAsFixed(0)} ${settings.currencySymbol}', style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                      ),
                      pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 3),
                        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.black, width: 0.8),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('المتبقي:', style: const pw.TextStyle(fontSize: 9)),
                            pw.Text('${changeDue.toStringAsFixed(0)} ${settings.currencySymbol}', style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                      ),
                    ],

                    pw.SizedBox(height: 4),

                    // Footer message
                    if (settings.receiptFooter.isNotEmpty) ...[
                      pw.Center(
                        child: pw.Text(
                          settings.receiptFooter,
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                    ],

                    // Order ID at the very bottom
                    pw.Center(
                      child: pw.Text(
                        '${order.id ?? 1}',
                        style: const pw.TextStyle(fontSize: 7.5),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();

      // 1. Send instant raw cash drawer pulse BEFORE PDF spooling locks the printer port
      openCashDrawer(settings).catchError((e) {
        debugPrint('Pre-spool open cash drawer error: $e');
        return false;
      });

      // 2. Send Customer Invoice PDF to printer
      final printResult = await sendPdfToPrinter(
        pdfBytes: pdfBytes,
        printerNameConfig: settings.cashierPrinter,
        docName: 'Invoice_${order.id ?? 1}',
      );

      // 3. Backup attempt: retry cash drawer pulse after PDF spooling releases printer handle
      Future.delayed(const Duration(milliseconds: 700), () async {
        for (int attempt = 0; attempt < 3; attempt++) {
          final success = await openCashDrawer(settings);
          if (success) break;
          await Future.delayed(const Duration(milliseconds: 500));
        }
      });

      return printResult;
    } catch (e) {
      debugPrint('Error printing receipt: $e');
      return false;
    }
  }

  /// طباعة تذكرة المطبخ (KOT)
  static Future<bool> printKitchenTicket({
    required OrderModel order,
    required List<OrderItemModel> items,
    required SettingsProvider settings,
    String? tableName,
  }) async {
    try {
      final kitchenItems = items.where((item) => item.printToKitchen).toList();
      if (kitchenItems.isEmpty) {
        debugPrint(
          'No items in this order have printToKitchen enabled. Skipping kitchen printing.',
        );
        return true;
      }

      pw.Font arabicFont;
      pw.Font arabicFontBold;
      try {
        arabicFont = await PdfGoogleFonts.amiriRegular();
        arabicFontBold = await PdfGoogleFonts.amiriBold();
      } catch (_) {
        arabicFont = await PdfGoogleFonts.cairoRegular();
        arabicFontBold = await PdfGoogleFonts.cairoBold();
      }

      // Group items by target kitchen printer
      final Map<String, List<OrderItemModel>> itemsByPrinter = {};
      for (var item in kitchenItems) {
        final targetPrinter =
            (item.kitchenPrinter != null && item.kitchenPrinter!.isNotEmpty)
            ? item.kitchenPrinter!
            : settings.kitchenPrinter;
        itemsByPrinter.putIfAbsent(targetPrinter, () => []).add(item);
      }

      bool allSuccess = true;

      for (var entry in itemsByPrinter.entries) {
        final printerName = entry.key;
        final printerGroupItems = entry.value;

        final pdf = pw.Document(
          theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
        );

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.roll80,
            margin: const pw.EdgeInsets.only(
              right: 34,
              left: 16,
              top: 6,
              bottom: 6,
            ),
            build: (pw.Context context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Center(
                      child: pw.Text(
                        '*** أمر مطبخ (KOT) ***',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Center(
                      child: pw.Text(
                        'طلب #${order.id ?? 1} - ${order.orderType}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    if (tableName != null)
                      pw.Center(
                        child: pw.Text(
                          'طاولة: $tableName',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    pw.Divider(thickness: 1),

                    ...printerGroupItems.map((item) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              '[ ${item.formattedQuantity} × ] ',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    item.productName ?? '',
                                    style: pw.TextStyle(
                                      fontSize: 12,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  if (item.notes != null &&
                                      item.notes!.isNotEmpty)
                                    pw.Text(
                                      'ملاحظة المطبخ: ${item.notes}',
                                      style: pw.TextStyle(
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    pw.Divider(thickness: 1),
                  ],
                ),
              );
            },
          ),
        );

        final pdfBytes = await pdf.save();
        final success = await sendPdfToPrinter(
          pdfBytes: pdfBytes,
          printerNameConfig: printerName,
          docName: 'KOT_${order.id ?? 1}',
        );
        if (!success) allSuccess = false;
      }

      return allSuccess;
    } catch (e) {
      debugPrint('Error printing KOT ticket: $e');
      return false;
    }
  }

  /// طباعة تقرير إداري أو مالي شامل
  static Future<bool> printReport({
    required String reportTitle,
    required String dateRangeText,
    required String generatedBy,
    required double totalSales,
    double totalExpenses = 0.0,
    required int totalOrders,
    required double netProfit,
    List<Map<String, dynamic>> productBreakdown = const [],
    String? tableTitle,
    List<String>? customHeaders,
    List<List<String>>? customDataRows,
    String? firstInvoiceTime,
    String? dayClosingTime,
    required SettingsProvider settings,
  }) async {
    try {
      final arabicFont = await PdfGoogleFonts.cairoRegular();
      final arabicFontBold = await PdfGoogleFonts.cairoBold();

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.only(
            right: 10,
            left: 10,
            top: 6,
            bottom: 6,
          ),
          build: (pw.Context context) {
            final headersList = customHeaders ?? ['اسم الصنف / المنتج', 'الكمية', 'المجموع'];
            final rowsList = customDataRows ??
                productBreakdown
                    .map(
                      (p) => [
                        p['name'].toString(),
                        '${p['qty']}',
                        '${(p['total'] as double).toStringAsFixed(0)} ${settings.currencySymbol}',
                      ],
                    )
                    .toList();

            final int colCount = headersList.length;

            Map<int, pw.TableColumnWidth> colWidths = {};
            Map<int, pw.Alignment> cellAligns = {};
            Map<int, pw.Alignment> headerAligns = {};

            if (colCount == 3) {
              colWidths = {
                0: const pw.FlexColumnWidth(2.8),
                1: const pw.FlexColumnWidth(2.2),
                2: const pw.FlexColumnWidth(1.4),
              };
              cellAligns = {
                0: pw.Alignment.centerRight,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
              };
              headerAligns = {
                0: pw.Alignment.centerRight,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
              };
            } else if (colCount == 7) {
              colWidths = {
                0: const pw.FlexColumnWidth(2.0),
                1: const pw.FlexColumnWidth(1.0),
                2: const pw.FlexColumnWidth(1.3),
                3: const pw.FlexColumnWidth(1.3),
                4: const pw.FlexColumnWidth(1.3),
                5: const pw.FlexColumnWidth(1.3),
                6: const pw.FlexColumnWidth(1.5),
              };
              for (int i = 0; i < colCount; i++) {
                cellAligns[i] = i == 0 ? pw.Alignment.centerRight : pw.Alignment.center;
                headerAligns[i] = i == 0 ? pw.Alignment.centerRight : pw.Alignment.center;
              }
            } else {
              for (int i = 0; i < colCount; i++) {
                cellAligns[i] = i == 0 ? pw.Alignment.centerRight : pw.Alignment.centerLeft;
                headerAligns[i] = i == 0 ? pw.Alignment.centerRight : pw.Alignment.centerLeft;
              }
            }

            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // 1. Store & Report Header (Centered)
                    pw.Center(
                      child: pw.Text(
                        settings.storeName,
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Center(
                      child: pw.Text(
                        reportTitle,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Center(
                      child: pw.Text(
                        'الفترة: $dateRangeText',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    if (firstInvoiceTime != null && firstInvoiceTime.isNotEmpty)
                      pw.Center(
                        child: pw.Text(
                          'تاريخ أول فاتورة: $firstInvoiceTime',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    if (dayClosingTime != null && dayClosingTime.isNotEmpty)
                      pw.Center(
                        child: pw.Text(
                          'إغلاق اليوم: $dayClosingTime',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    pw.Center(
                      child: pw.Text(
                        'المنفذ: $generatedBy | ${DateTime.now().toString().substring(0, 16)}',
                        style: const pw.TextStyle(fontSize: 7.5),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Divider(thickness: 1),

                    // 2. Financial Summary Box (Centered with safe inner margins)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'إجمالي المبيعات:',
                                style: const pw.TextStyle(fontSize: 8.5),
                              ),
                              pw.Text(
                                '${totalSales.toStringAsFixed(0)} ${settings.currencySymbol}',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (totalExpenses > 0) ...[
                            pw.SizedBox(height: 2),
                            pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  'إجمالي المصروفات:',
                                  style: const pw.TextStyle(fontSize: 8.5),
                                ),
                                pw.Text(
                                  '${totalExpenses.toStringAsFixed(0)} ${settings.currencySymbol}',
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          pw.SizedBox(height: 2),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'عدد الفواتير:',
                                style: const pw.TextStyle(fontSize: 8.5),
                              ),
                              pw.Text(
                                '$totalOrders فاتورة',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          pw.Divider(thickness: 0.5),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'صافي الوارد / الربح:',
                                style: pw.TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                '${netProfit.toStringAsFixed(0)} ${settings.currencySymbol}',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 8),

                    // 3. Breakdown Table Title
                    pw.Center(
                      child: pw.Text(
                        tableTitle ?? 'تفاصيل الأصناف المباعة:',
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.SizedBox(height: 4),

                    // 4. Product Breakdown Table (Balanced column widths to prevent overflow)
                    pw.TableHelper.fromTextArray(
                      headers: headersList,
                      data: rowsList,
                      headerStyle: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8,
                      ),
                      cellStyle: const pw.TextStyle(fontSize: 7.5),
                      border: pw.TableBorder.all(
                        color: PdfColors.grey400,
                        width: 0.5,
                      ),
                      headerDecoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                      cellAlignments: cellAligns,
                      headerAlignments: headerAligns,
                      columnWidths: colWidths.isNotEmpty ? colWidths : null,
                    ),

                    pw.SizedBox(height: 10),
                    pw.Divider(thickness: 0.5),
                    pw.Center(
                      child: pw.Text(
                        'نظام HAPPY DAY POS للتقارير',
                        style: const pw.TextStyle(fontSize: 7.5),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      return await sendPdfToPrinter(
        pdfBytes: pdfBytes,
        printerNameConfig: settings.reportsPrinter,
        docName: 'Report_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      debugPrint('Error printing report: $e');
      return false;
    }
  }

  /// إرسال أوراق بايتات خامة مباشرة (RAW Binary Stream) إلى طابعة الكاشير أو الشبكة
  static Future<bool> sendRawBytesToPrinter({
    required List<int> bytes,
    required SettingsProvider settings,
  }) async {
    final printerNameConfig = settings.cashierPrinter;

    // 1. Check if config is a network IP address (e.g. 192.168.1.200 or 192.168.1.200:9100)
    final ipRegex = RegExp(
      r'^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(?::(\d+))?$',
    );
    final match = ipRegex.firstMatch(printerNameConfig.trim());
    if (match != null) {
      try {
        final host = match.group(1)!;
        final port = int.tryParse(match.group(2) ?? '9100') ?? 9100;
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 3),
        );
        socket.add(bytes);
        await socket.flush();
        await socket.close();
        debugPrint('Raw bytes sent via TCP socket to $host:$port');
        return true;
      } catch (e) {
        debugPrint('Failed to send raw bytes to TCP printer: $e');
      }
    }

    final targetPrinter = await findTargetPrinter(printerNameConfig);
    final pName = targetPrinter?.name ?? printerNameConfig.trim();

    // 2. Windows Win32 Print Spooler RAW Sending via PowerShell script
    if (Platform.isWindows) {
      try {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}\\drawer_kick.bin');
        await file.writeAsBytes(bytes);

        final escapedPath = file.path.replaceAll('\\', '\\\\');
        final escapedPrinter = pName.replaceAll("'", "''");
        final rawConfig = printerNameConfig.trim().replaceAll("'", "''");

        final psScript =
            '''
\$printerNameConfig = '$rawConfig'
\$resolvedPrinter = '$escapedPrinter'
\$filePath = '$escapedPath'

\$code = @"
using System;
using System.IO;
using System.Runtime.InteropServices;
public class WinRawPrinter {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public class DOCINFOW {
    [MarshalAs(UnmanagedType.LPWStr)] public string pDocName;
    [MarshalAs(UnmanagedType.LPWStr)] public string pOutputFile;
    [MarshalAs(UnmanagedType.LPWStr)] public string pDataType;
  }
  [DllImport("winspool.Drv", EntryPoint = "OpenPrinterW", SetLastError = true, CharSet = CharSet.Unicode, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool OpenPrinter([MarshalAs(UnmanagedType.LPWStr)] string szPrinter, out IntPtr hPrinter, IntPtr pd);
  [DllImport("winspool.Drv", EntryPoint = "ClosePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool ClosePrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint = "StartDocPrinterW", SetLastError = true, CharSet = CharSet.Unicode, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool StartDocPrinter(IntPtr hPrinter, Int32 level, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOW di);
  [DllImport("winspool.Drv", EntryPoint = "EndDocPrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool EndDocPrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint = "StartPagePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool StartPagePrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint = "EndPagePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool EndPagePrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint = "WritePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, Int32 dwCount, out Int32 dwWritten);
  public static bool PrintRawBytes(string pName, string path) {
    if (string.IsNullOrWhiteSpace(pName) || !File.Exists(path)) return false;
    byte[] bytes = File.ReadAllBytes(path);
    IntPtr hPrinter = IntPtr.Zero;
    DOCINFOW di = new DOCINFOW { pDocName = "OpenCashDrawer", pOutputFile = null, pDataType = "RAW" };
    if (OpenPrinter(pName, out hPrinter, IntPtr.Zero)) {
      if (StartDocPrinter(hPrinter, 1, di)) {
        if (StartPagePrinter(hPrinter)) {
          IntPtr pUnmanagedBytes = Marshal.AllocHGlobal(bytes.Length);
          Marshal.Copy(bytes, 0, pUnmanagedBytes, bytes.Length);
          int dwWritten = 0;
          bool success = WritePrinter(hPrinter, pUnmanagedBytes, bytes.Length, out dwWritten);
          Marshal.FreeHGlobal(pUnmanagedBytes);
          EndPagePrinter(hPrinter);
          EndDocPrinter(hPrinter);
          ClosePrinter(hPrinter);
          return success;
        }
        EndDocPrinter(hPrinter);
      }
      ClosePrinter(hPrinter);
    }
    return false;
  }
}
"@
Add-Type -TypeDefinition \$code -ErrorAction SilentlyContinue

\$candidates = @()
if (-not [string]::IsNullOrWhiteSpace(\$resolvedPrinter)) { \$candidates += \$resolvedPrinter }
if (-not [string]::IsNullOrWhiteSpace(\$printerNameConfig)) {
  \$candidates += \$printerNameConfig
  if (\$printerNameConfig -match '\\((.*?)\\)') {
    \$candidates += \$matches[1].Trim()
  }
  \$clean = \$printerNameConfig -replace '[\\u0600-\\u06FF]', ''
  \$clean = \$clean.Trim(' ()-_')
  if (-not [string]::IsNullOrWhiteSpace(\$clean)) { \$candidates += \$clean }
}

# Add default printer
try {
  \$def = (Get-WmiObject -Class Win32_Printer -ErrorAction SilentlyContinue | Where-Object {\$_ .Default -eq \$true}).Name
  if (\$def) { \$candidates += \$def }
} catch {}

# Add all thermal/POS printers installed on Windows
try {
  \$posPrinters = (Get-WmiObject -Class Win32_Printer -ErrorAction SilentlyContinue | Where-Object {\$_ .Name -match 'POS|Receipt|Thermal|Xprinter|XP|Epson|Star|Citizen|TSC|Gprinter|Bixolon|Zonerich'}).Name
  if (\$posPrinters) { \$candidates += \$posPrinters }
} catch {}

# Add all available installed printers as final fallback
try {
  \$allP = (Get-WmiObject -Class Win32_Printer -ErrorAction SilentlyContinue).Name
  if (\$allP) { \$candidates += \$allP }
} catch {}

foreach (\$p in \$candidates | Select-Object -Unique) {
  if ([WinRawPrinter]::PrintRawBytes(\$p, \$filePath)) {
    Write-Output "True"
    exit 0
  }
}
Write-Output "False"
''';

        final psFile = File('${tempDir.path}\\send_raw_drawer.ps1');
        await psFile.writeAsString(psScript);

        final result = await Process.run('powershell', [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          psFile.path,
        ]);
        debugPrint(
          'Windows PowerShell raw spool result: exit=${result.exitCode}, out=${result.stdout}',
        );
        if (result.exitCode == 0 &&
            result.stdout.toString().trim().toLowerCase() == 'true') {
          return true;
        }
      } catch (e) {
        debugPrint('Windows Win32 spool failed: $e');
      }

      // Windows secondary fallback: Native print.exe, PowerShell Out-Printer, and cmd spool copy
      try {
        final tempDir = await getTemporaryDirectory();
        final binPath = '${tempDir.path}\\drawer_kick.bin';

        final printerCandidates = <String>{};
        if (pName.isNotEmpty) printerCandidates.add(pName);
        if (printerNameConfig.isNotEmpty) printerCandidates.add(printerNameConfig.trim());

        for (var p in printerCandidates) {
          // Attempt 1: print.exe /D:"PrinterName" file.bin (Built-in Windows RAW print command)
          var res = await Process.run('print', ['/D:$p', binPath]);
          if (res.exitCode == 0) return true;

          // Attempt 2: PowerShell Get-Content | Out-Printer
          res = await Process.run('powershell', [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            'Get-Content -Path "$binPath" -Encoding Byte -Raw | Out-Printer -Name "$p"',
          ]);
          if (res.exitCode == 0) return true;

          // Attempt 3: cmd copy /b to local spooler share
          res = await Process.run('cmd', [
            '/c',
            'copy',
            '/b',
            '"$binPath"',
            '"\\\\127.0.0.1\\$p"',
          ]);
          if (res.exitCode == 0) return true;
        }
      } catch (e) {
        debugPrint('Windows secondary RAW fallback failed: $e');
      }
    }

    // 3. macOS & Linux CUPS Raw Spooling via lpr/lp
    if (Platform.isMacOS || Platform.isLinux) {
      try {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/drawer_kick.bin');
        await file.writeAsBytes(bytes);

        String queueName = pName;
        if (queueName.contains('الافتراضية') ||
            queueName.contains('Default') ||
            queueName.contains('طابعة')) {
          if (targetPrinter != null &&
              !targetPrinter.name.contains('الافتراضية') &&
              !targetPrinter.name.contains('طابعة')) {
            queueName = targetPrinter.name;
          } else {
            queueName = '';
          }
        }

        final queueNames = <String>{};
        if (queueName.isNotEmpty) {
          queueNames.add(queueName);
          queueNames.add(queueName.replaceAll(' ', '_'));
        }

        // 1. Get system default CUPS printer queue destination via lpstat -d
        try {
          final resDef = await Process.run('lpstat', ['-d']);
          if (resDef.exitCode == 0) {
            final out = resDef.stdout.toString();
            final matchDef = RegExp(r':\s*(.+)').firstMatch(out);
            if (matchDef != null) {
              final dName = matchDef.group(1)!.trim();
              if (dName.isNotEmpty) {
                queueNames.add(dName);
                queueNames.add(dName.replaceAll(' ', '_'));
              }
            }
          }
        } catch (_) {}

        // 2. Get exact system CUPS queue names via lpstat -e & lpstat -p
        try {
          final res = await Process.run('lpstat', ['-e']);
          if (res.exitCode == 0) {
            final lines = res.stdout.toString().split('\n');
            for (var l in lines) {
              final q = l.trim();
              if (q.isNotEmpty) {
                queueNames.add(q);
                queueNames.add(q.replaceAll(' ', '_'));
              }
            }
          }
        } catch (_) {}

        try {
          final systemPrinters = await Printing.listPrinters();
          for (var p in systemPrinters) {
            if (p.name.isNotEmpty && !p.name.contains('الافتراضية')) {
              queueNames.add(p.name);
              queueNames.add(p.name.replaceAll(' ', '_'));
            }
          }
        } catch (_) {}

        // Auto-enable & accept any paused or offline CUPS queues on macOS/Linux
        for (var q in queueNames) {
          try {
            await Process.run('cupsenable', [q]);
            await Process.run('cupsaccept', [q]);
          } catch (_) {}
        }

        bool anySuccess = false;
        for (var qName in queueNames) {
          final List<List<String>> commandsToTry = [
            ['lpr', '-P', qName, '-o', 'raw', file.path],
            ['lpr', '-P', qName, file.path],
            ['lp', '-d', qName, '-o', 'raw', file.path],
            ['lp', '-d', qName, file.path],
          ];

          for (var cmd in commandsToTry) {
            final res = await Process.run(cmd[0], cmd.sublist(1));
            debugPrint(
              'macOS/Linux print attempt ${cmd.join(" ")}: exit=${res.exitCode}',
            );
            if (res.exitCode == 0) {
              anySuccess = true;
              break;
            }
          }
        }

        // Fallback default lpr/lp
        if (!anySuccess) {
          for (var cmd in [
            ['lpr', '-o', 'raw', file.path],
            ['lpr', file.path],
            ['lp', '-o', 'raw', file.path],
            ['lp', file.path],
          ]) {
            final res = await Process.run(cmd[0], cmd.sublist(1));
            if (res.exitCode == 0) {
              anySuccess = true;
              break;
            }
          }
        }

        if (anySuccess) return true;
      } catch (e) {
        debugPrint('macOS/Linux raw spool failed: $e');
      }
    }

    return false;
  }

  /// إرسال إشارة نبض كهربائي لفتح درج النقدية الإلكتروني (ESC/POS & Star & TSPL Cash Drawer Kick)
  static Future<bool> openCashDrawer(SettingsProvider settings) async {
    try {
      // 1. Send RAW Kick Pulse Bytes (27.112.0.148.49) directly to printer queue
      final List<int> drawerBytes = [
        // Exact user pulse code (Pin 2 & Pin 5)
        27, 112, 0, 148, 49,
        27, 112, 1, 148, 49,
        27, 112, 48, 148, 49,
        27, 112, 49, 148, 49,

        // Standard ESC p 0 (Pin 2)
        27, 112, 0, 25, 250,
        27, 112, 0, 50, 250,
        27, 112, 0, 100, 250,
        27, 112, 0, 60, 120,

        // Standard ESC p 1 (Pin 5)
        27, 112, 1, 25, 250,
        27, 112, 1, 50, 250,
        27, 112, 1, 100, 250,

        // DLE DC4 Real-time pulse commands
        16, 20, 1, 0, 8,
        16, 20, 1, 1, 8,

        // Star Micronics & FS pulse
        7,
        27, 7, 10, 50, 7,
        27, 118, 0,

        // Line feeds
        10, 10,
      ];

      await sendRawBytesToPrinter(
        bytes: drawerBytes,
        settings: settings,
      );

      // 2. Trigger Printer Driver Open Drawer via Micro PDF Print Job
      // (This activates the driver's "Open Cash Drawer" feature which opens upon printing invoices)
      try {
        final pdf = pw.Document();
        pdf.addPage(
          pw.Page(
            pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, 2 * PdfPageFormat.mm),
            margin: pw.EdgeInsets.zero,
            build: (context) => pw.Container(height: 1),
          ),
        );
        final pdfBytes = await pdf.save();
        await sendPdfToPrinter(
          pdfBytes: pdfBytes,
          printerNameConfig: settings.cashierPrinter,
          docName: 'OpenCashDrawer',
        );
      } catch (e) {
        debugPrint('Driver PDF drawer kick attempt error: $e');
      }

      return true;
    } catch (e) {
      debugPrint('openCashDrawer error: $e');
      return false;
    }
  }

  /// طباعة ملصق الباركود المخصص للصنف على طابعة ملصقات الباركود
  static Future<bool> printBarcodeLabel({
    required ProductModel product,
    int labelCount = 1,
    required SettingsProvider settings,
  }) async {
    try {
      final arabicFont = await PdfGoogleFonts.cairoRegular();
      final arabicFontBold = await PdfGoogleFonts.cairoBold();

      final barcodeData =
          (product.barcode != null && product.barcode!.isNotEmpty)
          ? product.barcode!
          : product.id.toString().padLeft(6, '0');

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
      );

      // Label Page Format: 50mm x 30mm standard label sticker
      const labelFormat = PdfPageFormat(
        50 * PdfPageFormat.mm,
        30 * PdfPageFormat.mm,
      );

      for (int i = 0; i < labelCount; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: labelFormat,
            margin: const pw.EdgeInsets.all(2),
            build: (pw.Context context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      settings.storeName,
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      product.name,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 1),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: barcodeData,
                      width: 110,
                      height: 26,
                      drawText: true,
                      textStyle: const pw.TextStyle(fontSize: 6.5),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      'السعر: ${product.price.toStringAsFixed(0)} ${settings.currencySymbol}',
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }

      final pdfBytes = await pdf.save();
      return await sendPdfToPrinter(
        pdfBytes: pdfBytes,
        printerNameConfig: settings.barcodePrinter,
        docName: 'Barcode_${product.name}',
      );
    } catch (e) {
      debugPrint('Error printing barcode label: $e');
      return false;
    }
  }

  /// طباعة سند صرف الراتب الشهري للموظف
  static Future<bool> printSalarySlip({
    required SalaryPaymentModel payment,
    required SettingsProvider settings,
  }) async {
    try {
      pw.Font arabicFont;
      pw.Font arabicFontBold;
      try {
        arabicFont = await PdfGoogleFonts.amiriRegular();
        arabicFontBold = await PdfGoogleFonts.amiriBold();
      } catch (_) {
        arabicFont = await PdfGoogleFonts.cairoRegular();
        arabicFontBold = await PdfGoogleFonts.cairoBold();
      }

      final pdf = pw.Document();
      final pageFormat = PdfPageFormat(220, double.infinity, marginAll: 8);

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Theme(
                data: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      settings.storeName,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text('سند صرف راتب شهري', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    pw.Divider(thickness: 1),
                    pw.SizedBox(height: 4),

                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('اسم الموظف:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                        pw.Text(payment.employeeName ?? 'موظف', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('عن شهر / سنة:', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.Text(payment.monthYear, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('تاريخ الصرف:', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.Text(payment.paymentDate, style: const pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),
                    if (payment.paidBy != null && payment.paidBy!.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('منفذ الصرف:', style: const pw.TextStyle(fontSize: 8.5)),
                          pw.Text(payment.paidBy!, style: const pw.TextStyle(fontSize: 8.5)),
                        ],
                      ),
                    ],

                    pw.SizedBox(height: 6),
                    pw.Divider(thickness: 0.5),

                    // Financial details
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('الراتب الأساسي:', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.Text('${payment.baseSalary.toStringAsFixed(0)} ${settings.currencySymbol}', style: const pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),
                    if (payment.totalBonuses > 0) ...[
                      pw.SizedBox(height: 2),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('+ المكافآت:', style: const pw.TextStyle(fontSize: 8.5)),
                          pw.Text('+${payment.totalBonuses.toStringAsFixed(0)} ${settings.currencySymbol}', style: const pw.TextStyle(fontSize: 8.5)),
                        ],
                      ),
                    ],
                    if (payment.totalAdvances > 0) ...[
                      pw.SizedBox(height: 2),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('- مجموع السُلف التسوية:', style: const pw.TextStyle(fontSize: 8.5)),
                          pw.Text('-${payment.totalAdvances.toStringAsFixed(0)} ${settings.currencySymbol}', style: const pw.TextStyle(fontSize: 8.5)),
                        ],
                      ),
                    ],
                    if (payment.totalDeductions > 0) ...[
                      pw.SizedBox(height: 2),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('- مجموع الخصومات:', style: const pw.TextStyle(fontSize: 8.5)),
                          pw.Text('-${payment.totalDeductions.toStringAsFixed(0)} ${settings.currencySymbol}', style: const pw.TextStyle(fontSize: 8.5)),
                        ],
                      ),
                    ],

                    pw.SizedBox(height: 6),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 1.2),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('صافي الراتب المدفوع:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text('${payment.netSalary.toStringAsFixed(0)} ${settings.currencySymbol}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 14),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('توقيع الموظف: ...................', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('توقيع المحاسب/المدير: ...................', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      return await sendPdfToPrinter(
        pdfBytes: pdfBytes,
        printerNameConfig: settings.cashierPrinter,
        docName: 'SalarySlip_${payment.employeeName}',
      );
    } catch (e) {
      debugPrint('Error printing salary slip: $e');
      return false;
    }
  }
}
