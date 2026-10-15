import 'package:flutter_test/flutter_test.dart';
import '../../../lib/application/voice/voice_command_guard.dart';
import '../../../lib/domain/voice/voice_command.dart';
import '../../../lib/domain/voice/voice_risk.dart';

void main() {
  test('yüksek riskli ses komutu onay bekler', () {
    final decision = VoiceCommandGuard().evaluate(
      const VoiceCommand(text: 'kritik işlem', requiresApproval: false),
      risk: VoiceRisk.high,
    );
    expect(decision.allowed, isTrue);
    expect(decision.requiresApproval, isTrue);
  });
}
