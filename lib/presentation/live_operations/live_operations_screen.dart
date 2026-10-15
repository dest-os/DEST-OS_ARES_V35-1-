import 'package:flutter/material.dart';

import '../../application/live_operations/in_memory_live_operations_repository.dart';
import '../../application/live_operations/live_operations_service.dart';
import '../../domain/live_operations/live_operation.dart';
import '../../domain/live_operations/live_operation_status.dart';

class LiveOperationsScreen extends StatefulWidget {
  const LiveOperationsScreen({super.key});

  @override
  State<LiveOperationsScreen> createState() => _LiveOperationsScreenState();
}

class _LiveOperationsScreenState extends State<LiveOperationsScreen> {
  final LiveOperationsService _service = LiveOperationsService(
    InMemoryLiveOperationsRepository(),
  );

  List<LiveOperation> _operations = <LiveOperation>[];

  @override
  void initState() {
    super.initState();
    _seedPreview();
  }

  Future<void> _seedPreview() async {
    await _service.publish(
      LiveOperation(
        id: 'live-demo-1',
        title: 'ARES canlı operasyon altyapısı',
        status: LiveOperationStatus.running,
        progress: 0.42,
        updatedAt: DateTime.now().toUtc(),
        currentStep: 'Operasyon durumu izleniyor',
        message: 'Canlı izleme katmanı hazır.',
        priority: 10,
      ),
    );
    await _service.publish(
      LiveOperation(
        id: 'live-demo-2',
        title: 'Onay bekleyen işlem',
        status: LiveOperationStatus.waitingApproval,
        progress: 0.70,
        updatedAt: DateTime.now().toUtc(),
        currentStep: 'İbrahim onayı bekleniyor',
        priority: 9,
      ),
    );
    await _refresh();
  }

  Future<void> _refresh() async {
    final snapshot = await _service.snapshot();
    if (!mounted) return;
    setState(() {
      _operations = snapshot.operations;
    });
  }

  Color _statusColor(LiveOperationStatus status, BuildContext context) {
    switch (status) {
      case LiveOperationStatus.running:
        return Colors.cyanAccent;
      case LiveOperationStatus.waitingApproval:
        return Colors.amberAccent;
      case LiveOperationStatus.failed:
      case LiveOperationStatus.blocked:
        return Colors.redAccent;
      case LiveOperationStatus.completed:
        return Colors.greenAccent;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ARES • Canlı Operasyon'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Canlı çalışma görünümü',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Bu ekran görevleri yönetmez; çalışan operasyonların anlık durumunu gösterir.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ..._operations.map(
              (operation) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              operation.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            operation.status.value,
                            style: TextStyle(
                              color: _statusColor(operation.status, context),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: operation.progress),
                      const SizedBox(height: 10),
                      Text(
                        '${(operation.progress * 100).round()}%',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (operation.currentStep != null) ...[
                        const SizedBox(height: 8),
                        Text('Adım: ${operation.currentStep}'),
                      ],
                      if (operation.message != null) ...[
                        const SizedBox(height: 4),
                        Text('Durum: ${operation.message}'),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
