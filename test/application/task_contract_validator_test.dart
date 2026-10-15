import 'package:flutter_test/flutter_test.dart';

import '../../lib/application/tasks/task_contract_validator.dart';
import '../../lib/domain/tasks/task_contract.dart';
import '../../lib/domain/tasks/task_contract_result.dart';
import '../../lib/domain/tasks/task_priority.dart';

void main() {
  test('tüm kabul kriterleri tamamlanınca görev kabul edilir', () {
    const contract = TaskContract(
      id: 'contract-1',
      title: 'Test',
      description: 'Test',
      priority: TaskPriority.normal,
      acceptanceCriteria: <String>['A', 'B'],
    );

    final result = TaskContractValidator().validate(
      contract: contract,
      completedCriteria: const <String>['A', 'B'],
    );

    expect(result.status, TaskContractResultStatus.accepted);
    expect(result.accepted, isTrue);
  });

  test('eksik kriter varsa revizyon gerekir', () {
    const contract = TaskContract(
      id: 'contract-2',
      title: 'Test',
      description: 'Test',
      priority: TaskPriority.normal,
      acceptanceCriteria: <String>['A', 'B'],
    );

    final result = TaskContractValidator().validate(
      contract: contract,
      completedCriteria: const <String>['A'],
    );

    expect(result.status, TaskContractResultStatus.needsRevision);
    expect(result.missingCriteria, contains('B'));
  });
}
