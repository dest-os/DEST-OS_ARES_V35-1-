import '../../core/ids/ares_id.dart';
import 'task_status.dart';

/// Ana görev modeli (runtime ve CEO katmanı bunu kullanır).
class AresTask {
  AresTask({
    required this.id,
    required this.title,
    required this.description,
    this.status = TaskStatus.received,
    this.priority = 'normal',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  final AresId id;
  final String title;
  final String description;
  TaskStatus status;
  final String priority;
  final DateTime createdAt;

  void changeStatus(TaskStatus newStatus) {
    status = newStatus;
  }

  AresTask copyWith({
    AresId? id,
    String? title,
    String? description,
    TaskStatus? status,
    String? priority,
    DateTime? createdAt,
  }) {
    return AresTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Geriye dönük uyumluluk için takma ad.
typedef Task = AresTask;
