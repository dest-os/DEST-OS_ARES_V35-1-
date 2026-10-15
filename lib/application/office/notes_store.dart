import 'package:flutter/foundation.dart';

import '../../infrastructure/storage/json_file_store.dart';

/// Kullanıcının sohbetteki "Notlar" bölümüne yazdığı not.
class NoteData {
  const NoteData({required this.id, required this.text, required this.createdAt});

  final String id;
  final String text;
  final DateTime createdAt;
}

/// Notları diskte saklar.
class NotesStore extends ChangeNotifier {
  NotesStore({required JsonFileStore store}) : _store = store;

  static const String _fileName = 'notes';

  final JsonFileStore _store;
  final List<NoteData> _items = <NoteData>[];

  List<NoteData> get items => List<NoteData>.unmodifiable(_items);

  Future<void> load() async {
    final raw = await _store.read(_fileName);
    _items.clear();
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final id = item['id'];
        final text = item['text'];
        final at = item['createdAt'] is String ? DateTime.tryParse(item['createdAt'] as String) : null;
        if (id is String && text is String && at != null) {
          _items.add(NoteData(id: id, text: text, createdAt: at));
        }
      }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    await _store.write(
      _fileName,
      _items
          .map((n) => <String, Object?>{'id': n.id, 'text': n.text, 'createdAt': n.createdAt.toIso8601String()})
          .toList(),
    );
  }

  Future<void> add(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    final now = DateTime.now();
    _items.insert(0, NoteData(id: 'note_${now.microsecondsSinceEpoch}', text: clean, createdAt: now));
    await _save();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _items.removeWhere((n) => n.id == id);
    await _save();
    notifyListeners();
  }
}
