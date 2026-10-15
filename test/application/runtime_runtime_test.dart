import 'package:flutter_test/flutter_test.dart';

import 'package:dest_os_ares/application/events/event_publisher.dart';
import 'package:dest_os_ares/application/events/in_memory_event_bus.dart';
import 'package:dest_os_ares/application/events/in_memory_event_store.dart';
import 'package:dest_os_ares/application/runtime/in_memory_agent_manager_runtime.dart';
import 'package:dest_os_ares/application/runtime/in_memory_checkpoint_repository.dart';
import 'package:dest_os_ares/application/runtime/in_memory_lease_repository.dart';
import 'package:dest_os_ares/application/runtime/paid_ai_runtime_gate.dart';
import 'package:dest_os_ares/application/runtime/resource_runtime.dart';
import 'package:dest_os_ares/application/runtime/result_pipeline.dart';
import 'package:dest_os_ares/application/runtime/runtime_kernel.dart';
import 'package:dest_os_ares/application/runtime/scheduler.dart';
import 'package:dest_os_ares/application/runtime/worker_runtime.dart';
import 'package:dest_os_ares/core/ids/ares_id.dart';
import 'package:dest_os_ares/core/security/cost_policy.dart';
import 'package:dest_os_ares/domain/agents/agent_profile.dart';
import 'package:dest_os_ares/domain/agents/agent_role.dart';
import 'package:dest_os_ares/domain/runtime/ai_runtime_request.dart';
import 'package:dest_os_ares/domain/runtime/runtime_state.dart';
import 'package:dest_os_ares/domain/runtime/runtime_task.dart';
import 'package:dest_os_ares/domain/tasks/task.dart';

void main() {
  test('Ucretli ve bilinmeyen AI otomatik calistirilmaz', () {
    const gate = PaidAiRuntimeGate();
    final paid = gate.evaluate(const AiRuntimeRequest(
      instruction: 'test',
      costClass: AiCostClass.paid,
    ));
    final unknown = gate.evaluate(const AiRuntimeRequest(
      instruction: 'test',
      costClass: AiCostClass.unknown,
    ));

    expect(paid.decision, AiRuntimeGateDecision.waitingApproval);
    expect(unknown.decision, AiRuntimeGateDecision.waitingApproval);
  });

  test('Runtime kernel gorevi calistirip checkpoint olusturur', () async {
    final bus = InMemoryEventBus();
    final publisher = EventPublisher(
      bus: bus,
      store: InMemoryEventStore(),
    );
    final checkpoints = InMemoryCheckpointRepository();

    final agent = AgentProfile(
      id: const AresId('agent-1'),
      name: 'Test Worker',
      role: AgentRole.developer,
    );

    final kernel = RuntimeKernel(
      scheduler: InMemoryRuntimeScheduler(),
      agentManager: InMemoryAgentManagerRuntime(workers: [agent]),
      worker: NoOpWorkerRuntime(),
      resources: DefaultResourceRuntime(),
      checkpoints: checkpoints,
      leases: InMemoryLeaseRepository(),
      resultPipeline: DefaultRuntimeResultPipeline(),
      eventPublisher: publisher,
    );

    final task = RuntimeTask(
      task: AresTask(
        id: const AresId('task-1'),
        title: 'Test',
        description: 'Runtime testi',
      ),
    );

    await kernel.submit(task);
    final result = await kernel.runNext();

    expect(result, isNotNull);
    expect(await checkpoints.latestForTask('task-1'), isNotNull);
  });
}
