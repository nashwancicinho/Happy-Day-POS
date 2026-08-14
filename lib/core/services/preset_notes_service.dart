import 'package:shared_preferences/shared_preferences.dart';

class PresetNotesService {
  static const String _key = 'preset_kitchen_notes';

  static const List<String> defaultNotes = [
    'بدون بصل',
    'بدون ثوم',
    'بدون خس',
    'زيادة ثوم',
    'زيادة صوص',
    'شطة حارة',
    'بدون ملح',
    'سفري',
    'بدون طماطم',
    'زيادة جبن',
  ];

  static Future<List<String>> getPresetNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? saved = prefs.getStringList(_key);
      if (saved != null && saved.isNotEmpty) {
        return saved;
      }
    } catch (_) {}
    return List<String>.from(defaultNotes);
  }

  static Future<List<String>> addPresetNote(String newNote) async {
    final clean = newNote.trim();
    final notes = await getPresetNotes();
    if (clean.isNotEmpty && !notes.contains(clean)) {
      notes.add(clean);
      await _saveNotes(notes);
    }
    return notes;
  }

  static Future<List<String>> deletePresetNote(String noteToDelete) async {
    final notes = await getPresetNotes();
    notes.removeWhere((item) => item.trim() == noteToDelete.trim());
    await _saveNotes(notes);
    return notes;
  }

  static Future<void> _saveNotes(List<String> notes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, notes);
    } catch (_) {}
  }
}
