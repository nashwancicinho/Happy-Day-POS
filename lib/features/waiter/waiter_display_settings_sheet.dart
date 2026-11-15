import 'package:flutter/material.dart';
import 'waiter_display_settings.dart';

class WaiterDisplaySettingsSheet extends StatefulWidget {
  final VoidCallback? onSettingsChanged;

  const WaiterDisplaySettingsSheet({
    super.key,
    this.onSettingsChanged,
  });

  static Future<void> show(BuildContext context, {VoidCallback? onSettingsChanged}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => WaiterDisplaySettingsSheet(onSettingsChanged: onSettingsChanged),
    );
  }

  @override
  State<WaiterDisplaySettingsSheet> createState() => _WaiterDisplaySettingsSheetState();
}

class _WaiterDisplaySettingsSheetState extends State<WaiterDisplaySettingsSheet> {
  int _columns = WaiterDisplaySettings.columns;
  double _scale = WaiterDisplaySettings.itemScale;
  double _ratio = WaiterDisplaySettings.cardRatio;
  double _tableSize = WaiterDisplaySettings.tableSize;

  void _applyChanges() {
    WaiterDisplaySettings.columns = _columns;
    WaiterDisplaySettings.itemScale = _scale;
    WaiterDisplaySettings.cardRatio = _ratio;
    WaiterDisplaySettings.tableSize = _tableSize;
    WaiterDisplaySettings.save();
    widget.onSettingsChanged?.call();
    setState(() {});
  }

  void _resetToDefault() {
    setState(() {
      _columns = 0;
      _scale = 1.0;
      _ratio = 0.98;
      _tableSize = 170.0;
    });
    _applyChanges();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1F2937),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tune_rounded, color: Color(0xFF10B981), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'إعدادات عرض المواد والشاشة',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _resetToDefault,
                    icon: const Icon(Icons.restart_alt, size: 16, color: Colors.amberAccent),
                    label: const Text(
                      'افتراضي',
                      style: TextStyle(color: Colors.amberAccent, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF374151), height: 16),

              // 1. Columns Count
              const Row(
                children: [
                  Icon(Icons.view_column_rounded, size: 18, color: Color(0xFF10B981)),
                  SizedBox(width: 6),
                  Text(
                    'عدد الأعمدة للمواد:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'اختر عدداً ثابتاً للأعمدة أو اجعله تلقائياً حسب حجم شاشة جهازك',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildColumnOption(0, 'تلقائي', Icons.auto_awesome),
                  const SizedBox(width: 6),
                  _buildColumnOption(2, '2 أعمدة', null),
                  const SizedBox(width: 6),
                  _buildColumnOption(3, '3 أعمدة', null),
                  const SizedBox(width: 6),
                  _buildColumnOption(4, '4 أعمدة', null),
                  const SizedBox(width: 6),
                  _buildColumnOption(5, '5 أعمدة', null),
                ],
              ),

              const SizedBox(height: 20),

              // 2. Item Size / Scale
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.photo_size_select_small_rounded, size: 18, color: Color(0xFF10B981)),
                      SizedBox(width: 6),
                      Text(
                        'حجم بطاقات المواد والخط:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981), width: 1),
                    ),
                    child: Text(
                      '${(_scale * 100).toInt()}%',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF10B981),
                  inactiveTrackColor: const Color(0xFF374151),
                  thumbColor: const Color(0xFF10B981),
                  overlayColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: _scale,
                  min: 0.80,
                  max: 1.40,
                  divisions: 12,
                  onChanged: (val) {
                    setState(() => _scale = val);
                    _applyChanges();
                  },
                ),
              ),

              // Scale Presets
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPresetButton('صغير (85%)', 0.85),
                  _buildPresetButton('عادي (100%)', 1.0),
                  _buildPresetButton('كبير (115%)', 1.15),
                  _buildPresetButton('ضخم (130%)', 1.30),
                ],
              ),

              const SizedBox(height: 20),

              // 3. Card Shape / Proportion
              const Row(
                children: [
                  Icon(Icons.aspect_ratio_rounded, size: 18, color: Color(0xFF10B981)),
                  SizedBox(width: 6),
                  Text(
                    'تناسب أبعاد البطاقة:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildRatioOption(0.92, 'مستطيل طولي'),
                  const SizedBox(width: 8),
                  _buildRatioOption(0.98, 'قياسي متوازن'),
                  const SizedBox(width: 8),
                  _buildRatioOption(1.10, 'مربع/عريض'),
                ],
              ),

              const SizedBox(height: 20),

              // 4. Tables Size (Optional helper for tables view)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.table_restaurant_rounded, size: 18, color: Colors.blueAccent),
                      SizedBox(width: 6),
                      Text(
                        'حجم بطاقات الطاولات:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_tableSize.toInt()} px',
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.blueAccent,
                  inactiveTrackColor: const Color(0xFF374151),
                  thumbColor: Colors.blueAccent,
                  overlayColor: Colors.blueAccent.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: _tableSize,
                  min: 130.0,
                  max: 230.0,
                  divisions: 10,
                  onChanged: (val) {
                    setState(() => _tableSize = val);
                    _applyChanges();
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Close / Done button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('حفظ وإغلاق ✓', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColumnOption(int count, String label, IconData? icon) {
    final isSelected = _columns == count;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() => _columns = count);
          _applyChanges();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFF374151),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey.shade300)
              else
                Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade300,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade300,
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetButton(String label, double val) {
    final isSelected = (_scale - val).abs() < 0.04;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() => _scale = val);
        _applyChanges();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFF374151),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF10B981) : Colors.grey.shade300,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRatioOption(double ratioVal, String label) {
    final isSelected = (_ratio - ratioVal).abs() < 0.04;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() => _ratio = ratioVal);
          _applyChanges();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFF374151),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade300,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
