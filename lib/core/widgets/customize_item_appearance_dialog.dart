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
    {'name': 'افتراضي (تلقائي)', 'nameEn': 'Default (Auto)', 'hex': null},
    // Reds & Corals
    {'name': 'أحمر كلاسيكي 🟥', 'nameEn': 'Crimson Red', 'hex': '#DC2626'},
    {'name': 'أحمر عنابي 🍷', 'nameEn': 'Burgundy', 'hex': '#991B1B'},
    {'name': 'أحمر روبي 💎', 'nameEn': 'Ruby Red', 'hex': '#E11D48'},
    {'name': 'مرجاني مشرق 🪸', 'nameEn': 'Bright Coral', 'hex': '#F43F5E'},
    // Oranges & Ambers
    {'name': 'برتقالي ناري 🟧', 'nameEn': 'Fiery Orange', 'hex': '#EA580C'},
    {'name': 'برتقالي مشرق 🍊', 'nameEn': 'Bright Orange', 'hex': '#F97316'},
    {'name': 'عنبري دافئ 🟠', 'nameEn': 'Warm Amber', 'hex': '#F59E0B'},
    {'name': 'مشمشي ناعم 🍑', 'nameEn': 'Soft Peach', 'hex': '#FB923C'},
    // Yellows & Golds
    {'name': 'أصفر ذهبي 🟨', 'nameEn': 'Golden Yellow', 'hex': '#EAB308'},
    {'name': 'ذهبي خردلي 🍯', 'nameEn': 'Mustard Gold', 'hex': '#B45309'},
    {'name': 'كراميل عسلي 🍯', 'nameEn': 'Honey Caramel', 'hex': '#D97706'},
    // Greens & Limes
    {'name': 'ليموني منعش 🍋', 'nameEn': 'Lime Green', 'hex': '#84CC16'},
    {'name': 'تفاحي نضر 🍏', 'nameEn': 'Fresh Apple', 'hex': '#65A30D'},
    {'name': 'أخضر عشبي 🌿', 'nameEn': 'Grass Green', 'hex': '#16A34A'},
    {'name': 'أخضر زمردي 🟩', 'nameEn': 'Emerald Green', 'hex': '#10B981'},
    {'name': 'زمردي غامق 🌲', 'nameEn': 'Deep Emerald', 'hex': '#047857'},
    {'name': 'زيتي راقي 🫒', 'nameEn': 'Olive Green', 'hex': '#4D7C0F'},
    // Teals & Cyans
    {'name': 'تيل بحري 🌊', 'nameEn': 'Ocean Teal', 'hex': '#0F766E'},
    {'name': 'فيروزي غامق 🩵', 'nameEn': 'Deep Turquoise', 'hex': '#097A75'},
    {'name': 'نعناعي هادئ 🌱', 'nameEn': 'Fresh Mint', 'hex': '#14B8A6'},
    {'name': 'سماوي مشرق 💎', 'nameEn': 'Bright Cyan', 'hex': '#06B6D4'},
    // Blues
    {'name': 'أزرق سماء ☁️', 'nameEn': 'Sky Blue', 'hex': '#0EA5E9'},
    {'name': 'أزرق بحري 🌊', 'nameEn': 'Ocean Blue', 'hex': '#0284C7'},
    {'name': 'أزرق ملكي 🟦', 'nameEn': 'Royal Blue', 'hex': '#1D4ED8'},
    {'name': 'كحلي عميق 🌌', 'nameEn': 'Deep Navy', 'hex': '#1E3A8A'},
    {'name': 'نيلي داكن 🔷', 'nameEn': 'Deep Indigo', 'hex': '#3730A3'},
    // Purples & Violets
    {'name': 'بنفسجي ملكي 🟪', 'nameEn': 'Royal Purple', 'hex': '#7E22CE'},
    {'name': 'بنفسجي إمبراطوري 🔮', 'nameEn': 'Imperial Purple', 'hex': '#6B21A8'},
    {'name': 'لافندر فاقع 🪻', 'nameEn': 'Bright Lavender', 'hex': '#A855F7'},
    // Pinks & Roses
    {'name': 'وردي فوشيا 🌺', 'nameEn': 'Fuchsia Pink', 'hex': '#D946EF'},
    {'name': 'وردي داكن 🌸', 'nameEn': 'Deep Rose', 'hex': '#BE185D'},
    {'name': 'قرمزي بوردو 🍇', 'nameEn': 'Bordeaux', 'hex': '#881337'},
    // Browns & Earthy
    {'name': 'بني دافئ 🤎', 'nameEn': 'Warm Brown', 'hex': '#78350F'},
    {'name': 'كراميل خشبي 🪵', 'nameEn': 'Caramel Wood', 'hex': '#92400E'},
    {'name': 'قهوة موكا ☕', 'nameEn': 'Mocha Coffee', 'hex': '#451A03'},
    // Slates & Darks
    {'name': 'رمادي كحلي 🩶', 'nameEn': 'Navy Slate', 'hex': '#334155'},
    {'name': 'رمادي جرافيتي 🪨', 'nameEn': 'Graphite', 'hex': '#475569'},
    {'name': 'أسود فاحم 🖤', 'nameEn': 'Pitch Black', 'hex': '#18181B'},
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
        constraints: const BoxConstraints(maxWidth: 620),
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
                    final name = isEng ? (preset['nameEn'] ?? preset['name']!) : preset['name']!;
                    final isSelected = _selectedColor == hex;
                    final colorVal = _parseHexColor(hex);
                    final isDarkChip = hex != null && _isDarkColor(colorVal);

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
                            color: isSelected ? Colors.deepOrange : (isDarkChip ? Colors.white30 : Colors.grey.shade300),
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
                              Icon(Icons.check_circle, size: 14, color: isDarkChip ? Colors.amberAccent : Colors.deepOrange)
                            else
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorVal == Colors.white ? Colors.grey.shade300 : colorVal,
                                  border: Border.all(color: isDarkChip ? Colors.white54 : Colors.grey.shade400),
                                ),
                              ),
                            const SizedBox(width: 6),
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected
                                    ? (isDarkChip ? Colors.amberAccent : Colors.deepOrange.shade900)
                                    : (isDarkChip ? Colors.white : Colors.black87),
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
