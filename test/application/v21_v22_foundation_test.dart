import 'package:flutter_test/flutter_test.dart';
import '../../lib/application/ai_center/ai_center_service.dart';
import '../../lib/application/automation/automation_guard.dart';
import '../../lib/core/security/cost_policy.dart';
import '../../lib/domain/ai_center/ai_center_category.dart';
import '../../lib/domain/ai_center/ai_provider_profile.dart';
import '../../lib/domain/automation/automation_rule.dart';
import '../../lib/domain/automation/automation_trigger.dart';

void main() {
  test('ücretli ve bilinmeyen AI onay gerektirir', () {
    const service = AiCenterService();
    const paid = AiProviderProfile(provider: 'X', model: 'Y', address: 'https://example.invalid', category: AiCenterCategory.paid, capabilities: [], verified: true);
    const unknown = AiProviderProfile(provider: 'X', model: 'Y', address: '', category: AiCenterCategory.unknown, capabilities: [], verified: false);
    expect(service.requiresApproval(paid), isTrue);
    expect(service.requiresApproval(unknown), isTrue);
    expect(service.toCostClass(paid), AiCostClass.paid);
  });

  test('onay gerektiren otomasyon onaysız çalışmaz', () {
    const guard = AutomationGuard();
    const rule = AutomationRule(id: 'a1', name: 'test', trigger: AutomationTrigger.event, enabled: true, requiresApproval: true);
    expect(guard.mayRun(rule, approvalGranted: false), isFalse);
    expect(guard.mayRun(rule, approvalGranted: true), isTrue);
  });
}
