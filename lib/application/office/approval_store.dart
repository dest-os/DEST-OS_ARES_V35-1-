import 'package:flutter/foundation.dart';

import '../../infrastructure/storage/json_file_store.dart';

/// Kullanıcı onayı bekleyen veya sonuçlanmış bir istek.
class ApprovalRequest {
  ApprovalRequest({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    required this.refId,
    required this.createdAt,
    this.status = 'pending',
  });

  /// paid_ai: ücretli AI kullanımı, new_ai: yeni AI önerisi, new_model: yeni model.
  final String id;
  final String kind;
  final String title;
  final String detail;
  final String refId;
  final String createdAt;
  final String status;

  bool get isPending => status == 'pending';

  ApprovalRequest withStatus(String value) => ApprovalRequest(
        id: id,
        kind: kind,
        title: title,
        detail: detail,
        refId: refId,
        createdAt: createdAt,
        status: value,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'kind': kind,
        'title': title,
        'detail': detail,
        'refId': refId,
        'createdAt': createdAt,
        'status': status,
      };

  static ApprovalRequest fromJson(Map<String, dynamic> json) {
    String text(String key) {
      final value = json[key];
      return value is String ? value : '';
    }

    return ApprovalRequest(
      id: text('id'),
      kind: text('kind'),
      title: text('title'),
      detail: text('detail'),
      refId: text('refId'),
      createdAt: text('createdAt'),
      status: text('status').isEmpty ? 'pending' : text('status'),
    );
  }
}

/// Onay isteklerini saklar. Ücretli AI ve yeni AI ekleme gibi işler burada bekler.
class ApprovalStore extends ChangeNotifier {
  ApprovalStore({required JsonFileStore store}) : _store = store;

  static const String _fileName = 'approvals';
  static const int _maxItems = 100;

  final JsonFileStore _store;
  final List<ApprovalRequest> _items = <ApprovalRequest>[];

  List<ApprovalRequest> get all => List<ApprovalRequest>.unmodifiable(_items);
  List<ApprovalRequest> get pending => _items.where((r) => r.isPending).toList();
  int get pendingCount => pending.length;

  Future<void> load() async {
    final raw = await _store.read(_fileName);
    _items.clear();
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          try {
            final r = ApprovalRequest.fromJson(Map<String, dynamic>.from(item));
            if (r.id.isNotEmpty) _items.add(r);
          } catch (_) {
            // Bozuk kayıt atlanır.
          }
        }
      }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    await _store.write(_fileName, _items.map((r) => r.toJson()).toList());
  }

  /// Aynı türde ve aynı hedef için bekleyen istek yoksa yenisini ekler.
  /// Yeni istek eklendiyse true döner.
  Future<bool> request({
    required String kind,
    required String title,
    required String detail,
    required String refId,
  }) async {
    final exists = _items.any((r) => r.isPending && r.kind == kind && r.refId == refId);
    if (exists) return false;
    final now = DateTime.now();
    _items.insert(
      0,
      ApprovalRequest(
        id: '${kind}_${now.microsecondsSinceEpoch}',
        kind: kind,
        title: title,
        detail: detail,
        refId: refId,
        createdAt: now.toIso8601String(),
      ),
    );
    if (_items.length > _maxItems) _items.removeRange(_maxItems, _items.length);
    await _save();
    notifyListeners();
    return true;
  }

  /// İsteği onaylar veya reddeder. Bulunan isteği döndürür.
  Future<ApprovalRequest?> resolve(String id, {required bool approved}) async {
    final index = _items.indexWhere((r) => r.id == id);
    if (index < 0) return null;
    final updated = _items[index].withStatus(approved ? 'approved' : 'rejected');
    _items[index] = updated;
    await _save();
    notifyListeners();
    return updated;
  }

  /// Bu sağlayıcı için kullanıcı daha önce reddetti mi.
  bool wasRejected(String kind, String refId) {
    return _items.any((r) => r.kind == kind && r.refId == refId && r.status == 'rejected');
  }
}
