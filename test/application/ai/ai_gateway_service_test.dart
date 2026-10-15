import 'package:flutter_test/flutter_test.dart';
import '../../../lib/application/ai/ai_gateway_service.dart';
import '../../../lib/application/ai/ai_request_router.dart';
import '../../../lib/application/runtime/local_ai_runtime.dart';
import '../../../lib/domain/ai/ai_request.dart';
import '../../../lib/domain/runtime/runtime_result.dart';
import '../../../lib/core/security/cost_policy.dart';

class _LocalRuntime implements LocalAiRuntime {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<RuntimeResult> run(request) async => const RuntimeResult(
        status: RuntimeResultStatus.success,
        output: 'yerel cevap',
      );
}

void main() {
  test('local AI request is allowed', () async {
    final gateway = AiGatewayService(
      router: const PolicyFirstAiRequestRouter(),
      localRuntime: _LocalRuntime(),
    );
    final result = await gateway.execute(const AiRequest(
      instruction: 'Merhaba',
      costClass: AiCostClass.local,
    ));
    expect(result.status, RuntimeResultStatus.success);
  });
}
