import 'package:flutter/foundation.dart';

import 'office_agents.dart';

enum OpState { queued, running, awaitingApproval, done, failed }

/// Canlı Operasyon panosundaki tek bir iş.
class OfficeOp {
  OfficeOp({
    required this.id,
    required this.title,
    required this.team,
    required this.agent,
    required this.startedAt,
    this.progress = 0,
    this.step = '',
    this.state = OpState.running,
  });

  final String id;
  final String title;
  final String team;
  final String agent;
  final DateTime startedAt;
  double progress;
  String step;
  OpState state;
  DateTime? finishedAt;

  bool get active => state == OpState.running || state == OpState.queued || state == OpState.awaitingApproval;
}

/// Son işlemler ve sistem bildirimleri için tek satırlık kayıt.
class OfficeNote {
  OfficeNote({required this.time, required this.text, required this.level});

  final DateTime time;
  final String text;

  /// info, ok, warn, error
  final String level;
}

/// Ofisin canlı durumu: işler, ajan durumları, son işlemler ve bildirimler.
/// Ana ekrandaki sağ sütun ve sohbetteki "Çalışan Görevler" paneli bunu dinler.
class OfficeHub extends ChangeNotifier {
  static const int _maxOps = 30;
  static const int _maxNotes = 40;

  final List<OfficeOp> _ops = <OfficeOp>[];
  final List<OfficeNote> _activity = <OfficeNote>[];
  final List<OfficeNote> _notifications = <OfficeNote>[];
  final Map<String, String> _agentStatus = <String, String>{};
  final Map<String, bool> _systemStatus = <String, bool>{};
  int _counter = 0;

  List<OfficeOp> get ops => List<OfficeOp>.unmodifiable(_ops);
  List<OfficeOp> get activeOps => _ops.where((o) => o.state == OpState.running).toList();
  List<OfficeOp> get queuedOps => _ops.where((o) => o.state == OpState.queued).toList();
  List<OfficeOp> get approvalOps => _ops.where((o) => o.state == OpState.awaitingApproval).toList();
  List<OfficeNote> get activity => List<OfficeNote>.unmodifiable(_activity);
  List<OfficeNote> get notifications => List<OfficeNote>.unmodifiable(_notifications);
  Map<String, bool> get systemStatus => Map<String, bool>.unmodifiable(_systemStatus);

  /// Ajanın şu anki durumu; boşsa "Beklemede".
  String statusOf(String agentId) => _agentStatus[agentId] ?? '';

  int get workingAgentCount => _agentStatus.values.where((s) => s.isNotEmpty).length;
  int get totalAgentCount => officeAgents.length;

  /// Yeni iş başlatır ve id'sini döndürür.
  String startOp({required String title, required String team, required String agent, String step = ''}) {
    _counter += 1;
    final id = 'op_${DateTime.now().microsecondsSinceEpoch}_$_counter';
    _ops.insert(0, OfficeOp(id: id, title: title, team: team, agent: agent, startedAt: DateTime.now(), step: step));
    if (_ops.length > _maxOps) _ops.removeRange(_maxOps, _ops.length);
    if (step.isNotEmpty) _agentStatus[agent] = step;
    notifyListeners();
    return id;
  }

  OfficeOp? _find(String id) {
    for (final op in _ops) {
      if (op.id == id) return op;
    }
    return null;
  }

  /// İşin ilerlemesini, adımını veya durumunu günceller.
  void updateOp(String id, {double? progress, String? step, OpState? state, String? agent}) {
    final op = _find(id);
    if (op == null) return;
    if (progress != null) op.progress = progress.clamp(0.0, 1.0).toDouble();
    if (step != null) op.step = step;
    if (state != null) op.state = state;
    final who = agent ?? op.agent;
    if (step != null && step.isNotEmpty) _agentStatus[who] = step;
    notifyListeners();
  }

  /// İşi bitirir; ilgili ajanların durumunu boşaltır.
  void finishOp(String id, {required bool ok, String message = ''}) {
    final op = _find(id);
    if (op == null) return;
    op.state = ok ? OpState.done : OpState.failed;
    op.finishedAt = DateTime.now();
    if (ok) op.progress = 1;
    if (message.isNotEmpty) op.step = message;
    _agentStatus.remove(op.agent);
    log('${op.title}: ${ok ? 'tamamlandı' : 'tamamlanamadı'}', level: ok ? 'ok' : 'error');
    notifyListeners();
  }

  void setAgent(String agentId, String status) {
    if (status.isEmpty) {
      _agentStatus.remove(agentId);
    } else {
      _agentStatus[agentId] = status;
    }
    notifyListeners();
  }

  void clearAgents() {
    _agentStatus.clear();
    notifyListeners();
  }

  void removeOp(String id) {
    _ops.removeWhere((o) => o.id == id);
    notifyListeners();
  }

  void log(String text, {String level = 'info'}) {
    _activity.insert(0, OfficeNote(time: DateTime.now(), text: text, level: level));
    if (_activity.length > _maxNotes) _activity.removeRange(_maxNotes, _activity.length);
    notifyListeners();
  }

  /// Aynı metinli son bildirimi tekrarlamaz.
  void notify(String text, {String level = 'info'}) {
    if (_notifications.isNotEmpty && _notifications.first.text == text) return;
    _notifications.insert(0, OfficeNote(time: DateTime.now(), text: text, level: level));
    if (_notifications.length > _maxNotes) _notifications.removeRange(_maxNotes, _notifications.length);
    notifyListeners();
  }

  void setSystemStatus(Map<String, bool> status) {
    _systemStatus
      ..clear()
      ..addAll(status);
    notifyListeners();
  }
}
