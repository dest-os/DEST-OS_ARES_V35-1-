import '../../domain/tasks/task.dart';

abstract interface class TaskRepository {
  Future<void> save(AresTask task);
  Future<AresTask?> getById(String taskId);
  Future<List<AresTask>> getAll();
  Future<void> remove(String taskId);
}
