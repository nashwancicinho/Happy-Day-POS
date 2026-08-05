import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../features/settings/settings_provider.dart';
import '../theme/app_colors.dart';


class CustomizeItemAppearanceDialog extends StatefulWidget {
  final String itemName;
  final String? initialImage;
  final String? initialColor;

  const CustomizeItemAppearanceDialog({
    super.key,
    required this.itemName,
    this.initialImage,
    this.initialColor,
  });

  static Future<Map<String, String?>?> show(
    BuildContext context, {
    required String itemName,
    String? initialImage,
    String? initialColor,
  }) {
    return showDialog<Map<String, String?>?>(
      context: context,
      builder: (ctx) => CustomizeItemAppearanceDialog(
        itemName: itemName,
        initialImage: initialImage,
        initialColor: initialColor,
      ),
    );
  }

  @override
  State<CustomizeItemAppearanceDialog> createState() => _CustomizeItemAppearanceDialogState();
}

class _CustomizeItemAppearanceDialogState extends State<CustomizeItemAppearanceDialog> {
  late String? _selectedImage;
  late String? _selectedColor;

  // Preset Colors Palette (Hex String -> Label) - Deeper & Richer Colors
  final List<Map<String, String?>> _colorPresets = [
    {'name': 'افتراضي', 'hex': null},
    {'name': 'برتقالي ناري 🟧', 'hex': '#EA580C'},
    {'name': 'أحمر عنابي 🟥', 'hex': '#B91C1C'},
    {'name': 'أزرق ملكي 🟦', 'hex': '#1D4ED8'},
    {'name': 'بنفسجي ملكي 🟪', 'hex': '#7E22CE'},
    {'name': 'زمردي غامق 🟩', 'hex': '#047857'},
    {'name': 'فيروزي غامق 🩵', 'hex': '#097A75'},
    {'name': 'ذهبي خردلي 🟨', 'hex': '#B45309'},
    {'name': 'وردي داكن 🌸', 'hex': '#BE185D'},
    {'name': 'بني دافئ 🤎', 'hex': '#78350F'},
    {'name': 'رمادي كحلي 🩶', 'hex': '#334155'},
    {'name': 'أسود فاحم 🖤', 'hex': '#18181B'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedImage = widget.initialImage;
    _selectedColor = widget.initialColor;
  }

  Future<void> _pickImage() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'images',
      extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file != null) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final assetsDir = Directory(path.join(appDir.path, 'happy_day_pos_assets'));
        if (!assetsDir.existsSync()) {
          await assetsDir.create(recursive: true);
        }
        final ext = path.extension(file.path);
        final newFileName = 'custom_img_${DateTime.now().millisecondsSinceEpoch}$ext';
        final targetPath = path.join(assetsDir.path, newFileName);
        final savedFile = await File(file.path).copy(targetPath);
        setState(() {
          _selectedImage = savedFile.path;
        });
      } catch (e) {
        debugPrint('Error copying image file: $e');
        setState(() {
          _selectedImage = file.path;
        });
      }
    }
  }

  Color _parseHexColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.white;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.white;
    }
  }

  bool _isDarkColor(Color color) {
    return color.computeLuminance() < 0.5;
  }

  @override
  Widget build(BuildContext context) {
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final cardBgColor = _parseHexColor(_selectedColor);
    final hasImage = _selectedImage != null && _selectedImage!.isNotEmpty && File(_selectedImage!).existsSync();
    final isDarkBg = hasImage || (_selectedColor != null && _isDarkColor(cardBgColor));
    final textColor = isDarkBg ? Colors.white : Colors.black87;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.palette_outlined, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEng ? 'Customize Appearance 🎨' : 'تخصيص مظهر المادة / التصنيف 🎨',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            widget.itemName,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 28),

                // Live Preview Card Section
                Text(
                  isEng ? 'Live Card Preview:' : 'معاينة المظهر الحية:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 140,
                    height: 120,
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade300, width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Stack(
                        children: [
                          Positioned.fill(child: Container(color: cardBgColor)),
                          if (hasImage)
                            Positioned.fill(
                              child: Image.file(
                                File(_selectedImage!),
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Container(color: cardBgColor),
                              ),
                            ),
                          if (hasImage)
                            Positioned.fill(
                              child: Container(color: Colors.black.withValues(alpha: 0.55)),
                            ),
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Center(
                                child: Text(
                                  widget.itemName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),


                const SizedBox(height: 20),

                // Section 1: Background Image
                Text(
                  isEng ? '1. Background Image 🖼️:' : '1. صورة خلفية الصنف / التصنيف 🖼️:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: Text(isEng ? 'Choose Image File' : 'اختيار صورة من الجهاز 🖼️'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    if (_selectedImage != null && _selectedImage!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _selectedImage = null),
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        label: Text(isEng ? 'Remove' : 'حذف الصورة'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // Section 2: Color Palette
                Text(
                  isEng ? '2. Card Background Color 🎨:' : '2. لون خلفية كارت الصنف 🎨:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _colorPresets.map((preset) {
                    final hex = preset['hex'];
                    final name = preset['name']!;
                    final isSelected = _selectedColor == hex;
                    final colorVal = _parseHexColor(hex);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = hex;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorVal,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.deepOrange : Colors.grey.shade300,
                            width: isSelected ? 2.5 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 6, spreadRadius: 1)]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected)
                              const Icon(Icons.check_circle, size: 14, color: Colors.deepOrange)
                            else
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorVal == Colors.white ? Colors.grey.shade300 : colorVal,
                                  border: Border.all(color: Colors.grey.shade400),
                                ),
                              ),
                            const SizedBox(width: 6),
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.deepOrange.shade900 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Save / Cancel Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(isEng ? 'Cancel' : 'إلغاء'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context, {
                          'image': _selectedImage,
                          'color': _selectedColor,
                        });
                      },
                      icon: const Icon(Icons.save, size: 18),
                      label: Text(isEng ? 'Save Appearance' : 'حفظ المظهر 💾'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
