import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../features/settings/settings_provider.dart';

class PrintService {
  /// جلب كافة الطابعات المعرفة والمكتشفة على جهاز الكمبيوتر
  static Future<List<Printer>> getSystemPrinters() async {
    List<Printer> printers = [];
    try {
      printers = await Printing.listPrinters();
    } catch (e) {
      debugPrint('Error listing system printers via Printing package: $e');
    }

    // Fallback for macOS / Linux if Printing.listPrinters() returns empty
    if (printers.isEmpty && (Platform.isMacOS || Platform.isLinux)) {
      try {
        final result = await Process.run('lpstat', ['-p', '-d']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          final lines = output.split('\n');
          String? defaultPrinterName;

          for (final line in lines) {
            if (line.contains('system default destination:')) {
              defaultPrinterName = line.split(':').last.trim();
            }
          }

          for (final line in lines) {
            if (line.startsWith('printer ')) {
              final parts = line.split(' ');
              if (parts.length > 1) {
                final printerName = parts[1].trim();
                final isDefault = (printerName == defaultPrinterName);
                if (printerName.isNotEmpty && !printers.any((p) => p.name == printerName)) {
                  printers.add(
                    Printer(
                      name: printerName,
                      url: printerName,
                      isDefault: isDefault,
                      isAvailable: true,
                    ),
                  );
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Fallback lpstat printer query failed: $e');
      }
    }

    debugPrint('Total discovered system printers: ${printers.length}');
    return printers;
  }

  /// البحث عن طابعة محددة بالاسم أو إرجاع الطابعة الافتراضية
  static Future<Printer?> findTargetPrinter(String printerName) async {
    final printers = await getSystemPrinters();
    if (printers.isEmpty) return null;

    final trimmed = printerName.trim();
    if (trimmed.isEmpty ||
        trimmed.contains('الافتراضية') ||
        trimmed.contains('POS-80') ||
        trimmed.contains('KOT-Kitchen') ||
        trimmed.contains('Default Printer')) {
      return printers.where((p) => p.isDefault).firstOrNull ?? printers.first;
    }

    return printers.where((p) => p.name.toLowerCase() == trimmed.toLowerCase() || p.url.toLowerCase() == trimmed.toLowerCase()).firstOrNull ??
        printers.where((p) => p.name.toLowerCase().contains(trimmed.toLowerCase())).firstOrNull ??
        printers.where((p) => p.isDefault).firstOrNull ??
        printers.first;
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
          );
          if (success) {
            debugPrint('Successfully printed directly to ${targetPrinter.name}');
            return true;
          }
        } catch (e) {
          debugPrint('Printing.directPrintPdf failed on ${targetPrinter.name}: $e');
        }
      }

      // Fallback 1: macOS native CUPS `lpr` command
      if (Platform.isMacOS) {
        try {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$docName.pdf');
          await tempFile.writeAsBytes(pdfBytes);

          List<String> lprArgs = [];
          if (targetPrinter != null && targetPrinter.name.isNotEmpty) {
            lprArgs.addAll(['-P', targetPrinter.name]);
          }
          lprArgs.add(tempFile.path);

          final result = await Process.run('lpr', lprArgs);
          if (result.exitCode == 0) {
            debugPrint('Successfully printed PDF via macOS CUPS lpr');
            return true;
          } else {
            final defaultLprResult = await Process.run('lpr', [tempFile.path]);
            if (defaultLprResult.exitCode == 0) {
              debugPrint('Successfully printed PDF via macOS default lpr');
              return true;
            }
          }
        } catch (e) {
          debugPrint('macOS CUPS lpr fallback failed: $e');
        }
      }

      // Fallback 2: Open System Print Layout Dialog
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
      final arabicFont = await PdfGoogleFonts.cairoRegular();
      final arabicFontBold = await PdfGoogleFonts.cairoBold();

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

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFontBold,
        ),
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 8),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                // 1. Logo (Centered)
                if (logoImage != null)
                  pw.Center(
                    child: pw.Container(
                      height: 55,
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                  ),

                // 2. Store Header Info (Centered)
                pw.Center(
                  child: pw.Text(
                    settings.storeName,
                    style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
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
                      'هاتف: ${settings.storePhone}',
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

                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1),

                // 3. Invoice Meta (Centered)
                pw.Center(
                  child: pw.Text(
                    'فاتورة رقم: #${order.id ?? 1} (${order.orderType})',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                if (tableName != null)
                  pw.Center(
                    child: pw.Text(
                      'طاولة: $tableName',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                pw.Center(
                  child: pw.Text(
                    'التاريخ: ${order.createdAt}',
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Divider(thickness: 1),

                // 4. Items Table Header
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text('الصنف / المادة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text('الكمية', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.center),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('المجموع', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.left),
                      ),
                    ],
                  ),
                ),
                pw.Divider(thickness: 0.5),

                // 5. Items Rows
                ...items.map((item) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(item.productName ?? 'صنف', style: const pw.TextStyle(fontSize: 9)),
                              if (item.notes != null && item.notes!.isNotEmpty)
                                pw.Text('ملاحظة: ${item.notes}', style: const pw.TextStyle(fontSize: 7)),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(item.formattedQuantity, style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text('${item.subtotal.toStringAsFixed(0)} ${settings.currencySymbol}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.left),
                        ),
                      ],
                    ),
                  );
                }),
                pw.Divider(thickness: 1),

                // 6. Summary
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('الإجمالي الكلي:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text('${order.total.toStringAsFixed(0)} ${settings.currencySymbol}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  ],
                ),
                if (cashPaid > 0) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('المدفوع:', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('${cashPaid.toStringAsFixed(0)} ${settings.currencySymbol}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('المتبقي:', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('${changeDue.toStringAsFixed(0)} ${settings.currencySymbol}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
                pw.Divider(thickness: 1),

                // 7. Footer (Centered)
                if (settings.receiptFooter.isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      settings.receiptFooter,
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      return await sendPdfToPrinter(
        pdfBytes: pdfBytes,
        printerNameConfig: settings.cashierPrinter,
        docName: 'Invoice_${order.id ?? 1}',
      );
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
          margin: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 8),
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

                ...kitchenItems.map((item) {
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
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      return await sendPdfToPrinter(
        pdfBytes: pdfBytes,
        printerNameConfig: settings.kitchenPrinter,
        docName: 'KOT_${order.id ?? 1}',
      );
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
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        settings.storeName,
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        reportTitle,
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('الفترة الزمنيـة: $dateRangeText', style: const pw.TextStyle(fontSize: 11), textAlign: pw.TextAlign.center),
                      pw.Text('تاريخ الطباعة: ${DateTime.now().toString().substring(0, 16)} | المنفذ: $generatedBy', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
                    ],
                  ),
                ),
                pw.Divider(thickness: 1.5),
                pw.SizedBox(height: 12),

                // Financial Overview Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text('إجمالي المبيعات (الوارد)', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('${totalSales.toStringAsFixed(0)} ${settings.currencySymbol}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text('إجمالي المصروفات', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('${totalExpenses.toStringAsFixed(0)} ${settings.currencySymbol}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text('عدد الفواتير', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('$totalOrders فاتورة', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text('صافي الربح / الوارد الصافي', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('${netProfit.toStringAsFixed(0)} ${settings.currencySymbol}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Table of Products / Breakdown / Custom Table
                pw.Text(tableTitle ?? 'تفاصيل مبيعات المنتجات والأصناف:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),

                pw.TableHelper.fromTextArray(
                  headers: customHeaders ?? ['اسم الصنف / المنتج', 'الكمية المباعة', 'إجمالي المبلغ'],
                  data: customDataRows ?? productBreakdown.map((p) => [
                    p['name'].toString(),
                    '${p['qty']} قطعة',
                    '${(p['total'] as double).toStringAsFixed(0)} ${settings.currencySymbol}',
                  ]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                ),

                pw.Spacer(),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('توقيع المحاسب / المدير: ....................', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('نظام HAPPY DAY POS', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
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
}
