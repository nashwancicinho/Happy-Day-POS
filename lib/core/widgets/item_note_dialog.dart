import 'package:flutter/material.dart';
import '../services/preset_notes_service.dart';

class ItemNoteDialog extends StatefulWidget {
  final String productName;
  final String initialNote;

  const ItemNoteDialog({
    super.key,
    required this.productName,
    required this.initialNote,
  });

  static Future<String?> show(BuildContext context, {required String productName, required String initialNote}) {
    return showDialog<String>(
      context: context,
      builder: (context) => ItemNoteDialog(
        productName: productName,
        initialNote: initialNote,
      ),
    );
  }

  @override
  State<ItemNoteDialog> createState() => _ItemNoteDialogState();
}

class _ItemNoteDialogState extends State<ItemNoteDialog> {
  late TextEditingController _noteController;
  final TextEditingController _newPresetController = TextEditingController();
  List<String> _presetNotes = [];
  bool _isLoadingPresets = true;
  bool _isAddingPreset = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNote);
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final notes = await PresetNotesService.getPresetNotes();
    if (mounted) {
      setState(() {
        _presetNotes = notes;
        _isLoadingPresets = false;
      });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _newPresetController.dispose();
    super.dispose();
  }

  void _togglePresetNote(String preset) {
    String currentText = _noteController.text.trim();
    List<String> currentParts = currentText
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (currentParts.contains(preset)) {
      currentParts.remove(preset);
    } else {
      currentParts.add(preset);
    }

    setState(() {
      _noteController.text = currentParts.join('، ');
    });
  }

  Future<void> _addNewPreset() async {
    final newText = _newPresetController.text.trim();
    if (newText.isEmpty) return;

    setState(() => _isAddingPreset = true);
    final updated = await PresetNotesService.addPresetNote(newText);
    if (mounted) {
      setState(() {
        _presetNotes = updated;
        _newPresetController.clear();
        _isAddingPreset = false;
      });
      _togglePresetNote(newText);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت إضافة "$newText" للملاحظات المحفوظة 💾'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deletePreset(String noteToDelete) async {
    final updated = await PresetNotesService.deletePresetNote(noteToDelete);
    if (mounted) {
      setState(() {
        _presetNotes = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إزالة "$noteToDelete" من المحفوظات 🗑️'),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentText = _noteController.text.trim();
    final List<String> selectedParts = currentText
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return AlertDialog(
      backgroundColor: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit_note_rounded, color: Color(0xFF10B981), size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ملاحظة المطبخ والمكونات',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.productName,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Text Field for Current Note
              const Text(
                'الملاحظة الحالية للصنف:',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'اكتب الملاحظة أو اختر من المكونات الجاهزة في الأسفل...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF111827),
                  suffixIcon: _noteController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                          tooltip: 'مسح نص الملاحظة',
                          onPressed: () {
                            setState(() {
                              _noteController.clear();
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                maxLines: 2,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // 2. Preset Stored Notes Chips Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bookmarks_rounded, color: Color(0xFF10B981), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'ملاحظات ومكونات مخزونة:',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(
                    'انقر للاختيار / اضغط ✖ للحذف',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 3. Stored Notes Chips Wrap
              if (_isLoadingPresets)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2),
                  ),
                )
              else if (_presetNotes.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'لا توجد ملاحظات مخزونة حالياً. يمكنك إضافة مكونات جديدة بالأسفل.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presetNotes.map((preset) {
                    final isSelected = selectedParts.contains(preset);
                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF10B981) : const Color(0xFF374151),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF059669) : Colors.white24,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _togglePresetNote(preset),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                preset,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _deletePreset(preset),
                                borderRadius: BorderRadius.circular(12),
                                child: const Padding(
                                  padding: EdgeInsets.all(2.0),
                                  child: Icon(Icons.close, color: Colors.white70, size: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 18),
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),

              // 4. Add New Custom Component/Note Section
              const Text(
                'إضافة مكون/ملاحظة جديدة وحفظها بالبرنامج:',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newPresetController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'مثال: بدون طماطم، زيادة صوص حار...',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF111827),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isAddingPreset ? null : _addNewPreset,
                    icon: _isAddingPreset
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add, color: Colors.white, size: 18),
                    label: const Text('إضافة وحفظ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actions: [
        if (currentText.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context, '');
            },
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 18),
            label: const Text('مسح الملاحظة', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () {
            Navigator.pop(context, _noteController.text.trim());
          },
          icon: const Icon(Icons.check, color: Colors.white, size: 18),
          label: const Text('حفظ للصنف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
