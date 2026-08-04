import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/product.dart';
import '../../features/settings/settings_provider.dart';

class PrintService {
  /// جلب كافة الطابعات المعرفة والمكتشفة على جهاز الكمبيوتر
  /// جلب كافة الطابعات المعرفة والمكتشفة على جهاز الكمبيوتر مستخدمين الحزمة الرسمية للنظام
  static Future<List<Printer>> getSystemPrinters() async {
    try {
      final printers = await Printing.listPrinters();
      debugPrint('Total discovered system printers via native plugin: ${printers.length}');
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

    final trimmed = printerName.trim();
    if (trimmed.isEmpty) {
      return printers.where((p) => p.isDefault).firstOrNull ?? printers.first;
    }

    final trimmedLower = trimmed.toLowerCase();
    final cleanTrimmed = trimmedLower.replaceAll('_', ' ').replaceAll('-', ' ');

    // 1. Exact match on printer name or url
    final exact = printers.where((p) =>
      p.name.toLowerCase() == trimmedLower ||
      p.url.toLowerCase() == trimmedLower
    ).firstOrNull;
    if (exact != null) return exact;

    // 2. Match inside parentheses e.g. "طابعة الكاشير الرئيسية (Xprinter XP-365B)" -> "Xprinter XP-365B"
    final matchInParen = RegExp(r'\((.*?)\)').firstMatch(trimmed);
    if (matchInParen != null) {
      final inside = matchInParen.group(1)!.trim().toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
      if (inside.isNotEmpty && inside != 'pos-80' && inside != 'kot-kitchen' && inside != 'default printer') {
        final parenMatch = printers.where((p) {
          final pName = p.name.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
          final pUrl = p.url.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
          return pName.contains(inside) || pUrl.contains(inside);
        }).firstOrNull;
        if (parenMatch != null) return parenMatch;
      }
    }

    // 3. Partial substring match (ignoring underscores/dashes)
    final matches = printers.where((p) {
      final pNameLower = p.name.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
      final pUrlLower = p.url.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
      return cleanTrimmed.contains(pNameLower) ||
             pNameLower.contains(cleanTrimmed) ||
             pUrlLower.contains(cleanTrimmed);
    }).toList();

    if (matches.isNotEmpty) {
      return matches.where((p) => p.isDefault).firstOrNull ?? matches.first;
    }

    // 4. Smart auto-detect thermal / receipt / label printer models (e.g. Xprinter, XP-, 365B, POS, Receipt)
    final thermalKeywords = ['xprinter', 'xp-', '365b', '420b', 'pos', 'receipt', 'thermal', 'tsc', 'epson', 'star', 'gprinter'];
    final thermalPrinters = printers.where((p) {
      final name = p.name.toLowerCase();
      final url = p.url.toLowerCase();
      return thermalKeywords.any((kw) => name.contains(kw) || url.contains(kw));
    }).toList();
    if (thermalPrinters.isNotEmpty) {
      return thermalPrinters.where((p) => p.isDefault).firstOrNull ?? thermalPrinters.first;
    }

    // 5. Check explicitly if user requested default printer
    if (trimmedLower.contains('الافتراضية') || trimmedLower.contains('default')) {
      return printers.where((p) => p.isDefault).firstOrNull ?? printers.first;
    }

    // 6. Fallback to default printer or first available printer
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
            debugPrint('Successfully printed directly to ${targetPrinter.name}');
            return true;
          }
        } catch (e) {
          debugPrint('Printing.directPrintPdf failed on ${targetPrinter.name}: $e');
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
        formattedDate = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
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
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFontBold,
        ),
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.only(right: 34, left: 16, top: 6, bottom: 6),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // 1. Logo (Enlarged & Centered)
                    if (logoImage != null)
                      pw.Center(
                        child: pw.Container(
                          height: 150,
                          margin: const pw.EdgeInsets.only(bottom: 10),
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),
                      ),

                    // 2. Store Header Info (Centered)
                    pw.Center(
                      child: pw.Text(
                        settings.storeName,
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    if (settings.storeAddress.isNotEmpty)
                      pw.Center(
                        child: pw.Text(
                          settings.storeAddress,
                          style: const pw.TextStyle(fontSize: 9.5),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    if (settings.storePhone.isNotEmpty)
                      pw.Center(
                        child: pw.Text(
                          settings.storePhone,
                          style: const pw.TextStyle(fontSize: 9.5),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    if (settings.receiptHeader.isNotEmpty)
                      pw.Center(
                        child: pw.Text(
                          settings.receiptHeader,
                          style: const pw.TextStyle(fontSize: 9.5),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),

                    pw.SizedBox(height: 4),
                    pw.Divider(thickness: 1),

                    // 3. Order Info & Separate Date / Time Lines (Centered)
                    if (cleanTable.isNotEmpty)
                      pw.Center(
                        child: pw.Text(
                          'طاولة: $cleanTable',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                          textAlign: pw.TextAlign.center,
                        ),
                      )
                    else
                      pw.Center(
                        child: pw.Text(
                          'نوع الطلب: $typeText',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),

                    pw.SizedBox(height: 4),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('التاريخ: $formattedDate', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                          pw.Text('الوقت: $formattedTime', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                        ],
                      ),
                    ),

                    // Delivery Customer Info Block
                    if (order.orderType == 'DELIVERY' ||
                        (order.customerPhone != null && order.customerPhone!.isNotEmpty) ||
                        (order.customerAddress != null && order.customerAddress!.isNotEmpty)) ...[
                      pw.SizedBox(height: 4),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(5),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.black, width: 0.8),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('--- بيانات التوصيل والزبون ---', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5), textAlign: pw.TextAlign.center),
                            if (order.customerName != null && order.customerName!.isNotEmpty)
                              pw.Text('اسم الزبون: ${order.customerName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                            if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                              pw.Text('هاتف الزبون: ${order.customerPhone}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5)),
                            if (order.customerAddress != null && order.customerAddress!.isNotEmpty)
                              pw.Text('عنوان التوصيل: ${order.customerAddress}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5)),
                          ],
                        ),
                      ),
                    ],

                    pw.Divider(thickness: 1),

                    // 4. Items Table Header
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            flex: 9,
                            child: pw.Text(
                              'الصنف / المادة',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(
                              'الكمية',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Expanded(
                            flex: 8,
                            child: pw.Text(
                              'المجموع',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                              textAlign: pw.TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Divider(thickness: 0.5),

                    // 5. Items Rows
                    ...items.map((item) {
                      final rawName = (item.productName != null && item.productName!.isNotEmpty)
                          ? item.productName!
                          : 'صنف #${item.productId}';
                      final pName = rawName.replaceAll(RegExp(r'\s+'), ' ').trim();
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              flex: 9,
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    pName,
                                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                                    textAlign: pw.TextAlign.right,
                                    softWrap: true,
                                  ),
                                  if (item.notes != null && item.notes!.isNotEmpty)
                                    pw.Text(
                                      'ملاحظة: ${item.notes}',
                                      style: const pw.TextStyle(fontSize: 8.5),
                                      textAlign: pw.TextAlign.right,
                                      softWrap: true,
                                    ),
                                ],
                              ),
                            ),
                            pw.Expanded(
                              flex: 3,
                              child: pw.Text(
                                item.formattedQuantity,
                                style: const pw.TextStyle(fontSize: 10),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Expanded(
                              flex: 8,
                              child: pw.Text(
                                '${item.subtotal.toStringAsFixed(0)} ${settings.currencySymbol}',
                                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                                textAlign: pw.TextAlign.left,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    pw.Divider(thickness: 1),

                    // 6. Summary
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('الإجمالي الكلي:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.Text('${order.total.toStringAsFixed(0)} ${settings.currencySymbol}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                    ),
                    if (cashPaid > 0) ...[
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('المدفوع:', style: const pw.TextStyle(fontSize: 9.5)),
                            pw.Text('${cashPaid.toStringAsFixed(0)} ${settings.currencySymbol}', style: const pw.TextStyle(fontSize: 9.5)),
                          ],
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('المتبقي:', style: const pw.TextStyle(fontSize: 9.5)),
                            pw.Text('${changeDue.toStringAsFixed(0)} ${settings.currencySymbol}', style: const pw.TextStyle(fontSize: 9.5)),
                          ],
                        ),
                      ),
                    ],
                    pw.Divider(thickness: 1),

                    // 7. Footer (Centered)
                    if (settings.receiptFooter.isNotEmpty) ...[
                      pw.Center(
                        child: pw.Text(
                          settings.receiptFooter,
                          style: const pw.TextStyle(fontSize: 9.5),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                    ],

                    // 8. Invoice ID at the very bottom (Small font, numbers only without #)
                    pw.Center(
                      child: pw.Text(
                        '${order.id ?? 1}',
                        style: const pw.TextStyle(fontSize: 8),
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
      // Trigger cash drawer kick signal before and after PDF print
      await openCashDrawer(settings);

      final printResult = await sendPdfToPrinter(
        pdfBytes: pdfBytes,
        printerNameConfig: settings.cashierPrinter,
        docName: 'Invoice_${order.id ?? 1}',
      );

      await openCashDrawer(settings);

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
        debugPrint('No items in this order have printToKitchen enabled. Skipping kitchen printing.');
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
        final targetPrinter = (item.kitchenPrinter != null && item.kitchenPrinter!.isNotEmpty)
            ? item.kitchenPrinter!
            : settings.kitchenPrinter;
        itemsByPrinter.putIfAbsent(targetPrinter, () => []).add(item);
      }

      bool allSuccess = true;

      for (var entry in itemsByPrinter.entries) {
        final printerName = entry.key;
        final printerGroupItems = entry.value;

        final pdf = pw.Document(
          theme: pw.ThemeData.withFont(
            base: arabicFont,
            bold: arabicFontBold,
          ),
        );

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.roll80,
            margin: const pw.EdgeInsets.only(right: 34, left: 16, top: 6, bottom: 6),
            build: (pw.Context context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Center(
                      child: pw.Text('*** أمر مطبخ (KOT) ***', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                    ),
                    pw.Center(
                      child: pw.Text('طلب #${order.id ?? 1} - ${order.orderType}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                    ),
                    if (tableName != null)
                      pw.Center(
                        child: pw.Text('طاولة: $tableName', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                      ),
                    pw.Divider(thickness: 1),

                    ...printerGroupItems.map((item) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('[ ${item.formattedQuantity} × ] ', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(item.productName ?? '', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                                  if (item.notes != null && item.notes!.isNotEmpty)
                                    pw.Text('ملاحظة: ${item.notes}', style: const pw.TextStyle(fontSize: 9)),
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
    required SettingsProvider settings,
  }) async {
    try {
      final arabicFont = await PdfGoogleFonts.cairoRegular();
      final arabicFontBold = await PdfGoogleFonts.cairoBold();

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFontBold,
        ),
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.only(right: 34, left: 16, top: 6, bottom: 6),
          build: (pw.Context context) {
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
                        style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Center(
                      child: pw.Text(
                        reportTitle,
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
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
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('إجمالي المبيعات:', style: const pw.TextStyle(fontSize: 8.5)),
                              pw.Text('${totalSales.toStringAsFixed(0)} ${settings.currencySymbol}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                          if (totalExpenses > 0) ...[
                            pw.SizedBox(height: 2),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('إجمالي المصروفات:', style: const pw.TextStyle(fontSize: 8.5)),
                                pw.Text('${totalExpenses.toStringAsFixed(0)} ${settings.currencySymbol}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              ],
                            ),
                          ],
                          pw.SizedBox(height: 2),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('عدد الفواتير:', style: const pw.TextStyle(fontSize: 8.5)),
                              pw.Text('$totalOrders فاتورة', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                          pw.Divider(thickness: 0.5),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('صافي الوارد / الربح:', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                              pw.Text('${netProfit.toStringAsFixed(0)} ${settings.currencySymbol}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
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
                        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.SizedBox(height: 4),

                    // 4. Product Breakdown Table (Balanced column widths to prevent overflow)
                    pw.TableHelper.fromTextArray(
                      headers: customHeaders ?? ['اسم الصنف / المنتج', 'الكمية', 'المجموع'],
                      data: customDataRows ?? productBreakdown.map((p) => [
                        p['name'].toString(),
                        '${p['qty']}',
                        '${(p['total'] as double).toStringAsFixed(0)} ${settings.currencySymbol}',
                      ]).toList(),
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                      cellStyle: const pw.TextStyle(fontSize: 8),
                      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(3.2),
                        1: const pw.FlexColumnWidth(1.2),
                        2: const pw.FlexColumnWidth(2.2),
                      },
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
    final ipRegex = RegExp(r'^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(?::(\d+))?$');
    final match = ipRegex.firstMatch(printerNameConfig.trim());
    if (match != null) {
      try {
        final host = match.group(1)!;
        final port = int.tryParse(match.group(2) ?? '9100') ?? 9100;
        final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 3));
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

        final psScript = '''
\$printerName = '$escapedPrinter'
\$filePath = '$escapedPath'
if ([string]::IsNullOrWhiteSpace(\$printerName)) {
  \$printerName = (Get-WmiObject -Class Win32_Printer | Where-Object {\$_ .Default -eq \$true}).Name
}
\$code = @"
using System;
using System.IO;
using System.Runtime.InteropServices;
public class WinRawPrinter {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
  public class DOCINFOA {
    [MarshalAs(UnmanagedType.LPStr)] public string pDocName;
    [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile;
    [MarshalAs(UnmanagedType.LPStr)] public string pDataType;
  }
  [DllImport("winspool.Drv", EntryPoint = "OpenPrinterA", SetLastError = true, CharSet = CharSet.Ansi, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool OpenPrinter([MarshalAs(UnmanagedType.LPStr)] string szPrinter, out IntPtr hPrinter, IntPtr pd);
  [DllImport("winspool.Drv", EntryPoint = "ClosePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool ClosePrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint = "StartDocPrinterA", SetLastError = true, CharSet = CharSet.Ansi, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool StartDocPrinter(IntPtr hPrinter, Int32 level, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOA di);
  [DllImport("winspool.Drv", EntryPoint = "EndDocPrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool EndDocPrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint = "StartPagePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool StartPagePrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint = "EndPagePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool EndPagePrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint = "WritePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, Int32 dwCount, out Int32 dwWritten);
  public static bool PrintRawBytes(string pName, string path) {
    byte[] bytes = File.ReadAllBytes(path);
    IntPtr hPrinter = new IntPtr(0);
    DOCINFOA di = new DOCINFOA { pDocName = "OpenCashDrawer", pDataType = "RAW" };
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
[WinRawPrinter]::PrintRawBytes(\$printerName, \$filePath)
''';

        final psFile = File('${tempDir.path}\\send_raw_drawer.ps1');
        await psFile.writeAsString(psScript);

        final result = await Process.run('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', psFile.path]);
        debugPrint('Windows PowerShell raw spool result: exit=${result.exitCode}, out=${result.stdout}');
        if (result.exitCode == 0 && result.stdout.toString().trim().toLowerCase() == 'true') {
          return true;
        }
      } catch (e) {
        debugPrint('Windows Win32 spool failed: $e');
      }

      // Windows secondary fallback: cmd copy /b
      try {
        final tempDir = await getTemporaryDirectory();
        if (pName.isNotEmpty) {
          final result = await Process.run('cmd', ['/c', 'copy', '/b', '${tempDir.path}\\drawer_kick.bin', '"$pName"']);
          if (result.exitCode == 0) return true;
        }
      } catch (_) {}
    }

    // 3. macOS & Linux CUPS Raw Spooling via lpr/lp
    if (Platform.isMacOS || Platform.isLinux) {
      try {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/drawer_kick.bin');
        await file.writeAsBytes(bytes);

        String queueName = pName;
        if (queueName.contains('الافتراضية') || queueName.contains('Default') || queueName.contains('طابعة')) {
          if (targetPrinter != null && !targetPrinter.name.contains('الافتراضية') && !targetPrinter.name.contains('طابعة')) {
            queueName = targetPrinter.name;
          } else {
            queueName = '';
          }
        }

        final queueNames = <String>{};
        if (queueName.isNotEmpty) queueNames.add(queueName);

        try {
          final systemPrinters = await Printing.listPrinters();
          for (var p in systemPrinters) {
            if (p.name.isNotEmpty && !p.name.contains('الافتراضية')) {
              queueNames.add(p.name);
            }
          }
        } catch (_) {}

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
            debugPrint('macOS/Linux print attempt ${cmd.join(" ")}: exit=${res.exitCode}');
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

  /// إرسال إشارة نبض كهربائي لفتح درج النقدية الإلكتروني (ESC/POS & TSPL Cash Drawer Kick)
  static Future<bool> openCashDrawer(SettingsProvider settings) async {
    try {
      final List<int> drawerBytes = [
        27, 64,                  // ESC @ (Reset/Initialize Printer)
        16, 20, 1, 0, 8,         // DLE DC4 1 0 8 (Real-time pulse Pin 2)
        16, 20, 1, 1, 8,         // DLE DC4 1 1 8 (Real-time pulse Pin 5)
        27, 112, 0, 60, 255,     // ESC p 0 (Pin 2, 120ms pulse)
        27, 112, 48, 60, 255,    // ESC p '0' (Pin 2 ASCII)
        27, 112, 1, 60, 255,     // ESC p 1 (Pin 5, 120ms pulse)
        27, 112, 49, 60, 255,    // ESC p '1' (Pin 5 ASCII)
        27, 112, 0, 25, 250,     // ESC p 0 (Pin 2, 50ms pulse)
        27, 112, 1, 25, 250,     // ESC p 1 (Pin 5, 50ms pulse)
        7,                       // BEL (Star Micronics)
        27, 7,                   // ESC BEL
        ...utf8.encode('DRAWER 0, 25, 250\r\n'),
        ...utf8.encode('DRAWER 1, 25, 250\r\n'),
        ...utf8.encode('CASHDRAWER 0, 25, 250\r\n'),
      ];

      final success = await sendRawBytesToPrinter(
        bytes: drawerBytes,
        settings: settings,
      );
      return success;
    } catch (e) {
      debugPrint('Error opening cash drawer: $e');
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

      final barcodeData = (product.barcode != null && product.barcode!.isNotEmpty)
          ? product.barcode!
          : product.id.toString().padLeft(6, '0');

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFontBold,
        ),
      );

      // Label Page Format: 50mm x 30mm standard label sticker
      const labelFormat = PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm);

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
                      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      product.name,
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
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
                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
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
}
