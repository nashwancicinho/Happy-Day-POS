import 'dart:convert';
import 'dart:io';

const String _secretSalt = 'HAPPY_DAY_POS_SALT_KEY_2026_ANNUAL_SUB';

String generateAnnualKeyForMachine(String targetMachineId) {
  final cleanMachineId = targetMachineId.trim().toUpperCase().replaceAll(' ', '');
  if (cleanMachineId.isEmpty) return '';

  final rawHash = base64UrlEncode(utf8.encode('$cleanMachineId-$_secretSalt')).replaceAll('=', '').toUpperCase();

  final p1 = rawHash.substring(0, 4).padRight(4, 'A');
  final p2 = rawHash.substring(4, 8).padRight(4, 'B');
  final checksum = _computeChecksumForMachine(cleanMachineId, 'HD-$p1-$p2');

  return 'HD-$p1-$p2-$checksum';
}

String _computeChecksumForMachine(String machineId, String data) {
  final combined = '$machineId-$data-$_secretSalt';
  int hash = 0;
  for (int i = 0; i < combined.length; i++) {
    hash = (hash * 31 + combined.codeUnitAt(i)) & 0xFFFFFFFF;
  }
  final hex = hash.toRadixString(16).toUpperCase().padLeft(8, '0');
  return hex.substring(0, 4);
}

void main(List<String> args) {
  print('====================================================');
  print('  Happy Day POS - External Key Generator Tool 🔑');
  print('====================================================');

  String machineId = '';
  if (args.isNotEmpty) {
    machineId = args[0];
  } else {
    stdout.write('أدخل رقم جهاز العميل (Machine ID): ');
    machineId = stdin.readLineSync() ?? '';
  }

  machineId = machineId.trim();
  if (machineId.isEmpty) {
    print('❌ خطأ: لم يتم إدخال رقم الجهاز!');
    exit(1);
  }

  final key = generateAnnualKeyForMachine(machineId);
  print('\n----------------------------------------------------');
  print('رقم الجهاز (Machine ID) : $machineId');
  print('كود التفعيل السنوي    : $key');
  print('----------------------------------------------------');
  print('✅ انسخ كود التفعيل أعلاه وأرسله للعميل.\n');
}
