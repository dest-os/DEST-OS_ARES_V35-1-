import 'package:flutter_test/flutter_test.dart';

import '../../lib/application/ceo/ceo_brain_service.dart';
import '../../lib/domain/ceo/ceo_intent.dart';

void main() {
  test('CEO isteği görev oluşturma niyeti olarak anlar', () {
    final service = CeoBrainService();

    final intent = service.understand('acil bir görev oluştur');

    expect(intent.type, CeoIntentType.createTask);
    expect(intent.priority, 'critical');
  });

  test('CEO planı kritik görev için onay gerektirebilir', () {
    final service = CeoBrainService();

    final intent = service.understand('kritik bir görev oluştur');
    final plan = service.plan(
      intent: intent,
      planId: 'plan-1',
      taskId: 'task-1',
    );

    expect(plan.requiresApproval, isTrue);
    expect(plan.taskIds, contains('task-1'));
  });
}
