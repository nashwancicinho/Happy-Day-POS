import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Test Amiri Regular & Bold asset font loading and PDF generation', () async {
    final regularData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
    expect(regularData.lengthInBytes, greaterThan(0));
    expect(boldData.lengthInBytes, greaterThan(0));

    final fontRegular = pw.Font.ttf(regularData);
    final fontBold = pw.Font.ttf(boldData);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Text('فاتورة كاشير - مطعم هابي داي', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text('المادة: بيتزا لحم 10,000 د.ع', style: const pw.TextStyle(fontSize: 10)),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    expect(bytes.lengthInBytes, greaterThan(0));
    print('Amiri Regular & Bold PDF generated successfully! Bytes length: ${bytes.length}');
  });
}
