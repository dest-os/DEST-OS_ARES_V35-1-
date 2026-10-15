import '../../domain/tasks/task.dart';
import 'task_repository.dart';

class InMemoryTaskRepository implements TaskRepository {
  final Map<String, AresTask> _items = <String, AresTask>{};

  @override
  Future<List<AresTask>> getAll() async {
    return List<AresTask>.unmodifiable(_items.values);
  }

  @override
  Future<AresTask?> getById(String taskId) async => _items[taskId];

  @override
  Future<void> remove(String taskId) async {
    _items.remove(taskId);
  }

  @override
  Future<void> save(AresTask task) async {
    _items[task.id.value] = task;
  }
}
