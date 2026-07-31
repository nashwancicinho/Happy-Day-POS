import 'dart:io';
import 'package:flutter/foundation.dart';
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
    if (printerName.isEmpty || printerName.contains('الافتراضية')) {
      final printers = await getSystemPrinters();
      return printers.where((p) => p.isDefault).firstOrNull ?? printers.firstOrNull;
    }
    
    final printers = await getSystemPrinters();
    return printers.where((p) => p.name == printerName || p.url == printerName).firstOrNull ??
        printers.where((p) => p.isDefault).firstOrNull ??
        printers.firstOrNull;
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

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFontBold,
        ),
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.all(10),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  settings.storeName,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                if (settings.storeAddress.isNotEmpty)
                  pw.Text(settings.storeAddress, style: const pw.TextStyle(fontSize: 9)),
                if (settings.storePhone.isNotEmpty)
                  pw.Text('Tel: ${settings.storePhone}', style: const pw.TextStyle(fontSize: 9)),
                if (settings.receiptHeader.isNotEmpty)
                  pw.Text(settings.receiptHeader, style: const pw.TextStyle(fontSize: 8)),
                pw.Divider(),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Invoice #${order.id ?? 1}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text(order.orderType, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ],
                ),
                if (tableName != null)
                  pw.Text('Table: $tableName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text('Date: ${order.createdAt}', style: const pw.TextStyle(fontSize: 8)),
                pw.Divider(),

                // Items Table
                ...items.map((item) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text('${item.productName} x${item.formattedQuantity}', style: const pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Text('${item.subtotal.toStringAsFixed(0)} ${settings.currencySymbol}', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  );
                }),
                pw.Divider(),

                // Summary
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    pw.Text('${order.total.toStringAsFixed(0)} ${settings.currencySymbol}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  ],
                ),
                if (cashPaid > 0) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Paid:', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('${cashPaid.toStringAsFixed(0)} ${settings.currencySymbol}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Change:', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('${changeDue.toStringAsFixed(0)} ${settings.currencySymbol}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
                pw.Divider(),

                if (settings.receiptFooter.isNotEmpty)
                  pw.Text(settings.receiptFooter, style: const pw.TextStyle(fontSize: 9)),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final targetPrinter = await findTargetPrinter(settings.cashierPrinter);

      if (targetPrinter != null) {
        return await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (format) async => pdfBytes,
        );
      } else {
        return await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'Invoice_${order.id ?? 1}',
        );
      }
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
          margin: const pw.EdgeInsets.all(10),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('*** KOT KITCHEN ***', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('Order #${order.id ?? 1} - ${order.orderType}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                if (tableName != null)
                  pw.Text('Table: $tableName', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),

                ...items.map((item) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('[ ${item.formattedQuantity} x ] ', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(item.productName ?? '', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                              if (item.notes != null && item.notes!.isNotEmpty)
                                pw.Text('Note: ${item.notes}', style: const pw.TextStyle(fontSize: 9)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                pw.Divider(),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final targetPrinter = await findTargetPrinter(settings.kitchenPrinter);

      if (targetPrinter != null) {
        return await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (format) async => pdfBytes,
        );
      } else {
        return await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'KOT_${order.id ?? 1}',
        );
      }
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
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        settings.storeName,
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        reportTitle,
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('الفترة الزمنيـة: $dateRangeText', style: const pw.TextStyle(fontSize: 11)),
                      pw.Text('تاريخ الطباعة: ${DateTime.now().toString().substring(0, 16)} | المنفذ: $generatedBy', style: const pw.TextStyle(fontSize: 10)),
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
      final targetPrinter = await findTargetPrinter(settings.reportsPrinter);

      if (targetPrinter != null) {
        return await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (format) async => pdfBytes,
        );
      } else {
        return await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'Report_${DateTime.now().millisecondsSinceEpoch}',
        );
      }
    } catch (e) {
      debugPrint('Error printing report: $e');
      return false;
    }
  }
}
