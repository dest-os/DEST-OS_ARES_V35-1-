import 'package:flutter_test/flutter_test.dart';

import '../../../lib/infrastructure/ai/local_prompt_builder.dart';

void main() {
  const builder = LocalPromptBuilder();
  const cleaner = LocalOutputCleaner();

  test('komut ChatML biçimindedir ve düşünme modu kapalıdır', () {
    final prompt = builder.build('Merhaba', contextTokens: 2048, maxTokens: 320);
    expect(prompt.startsWith('<|im_start|>system\n'), isTrue);
    expect(prompt.contains('<|im_start|>user\nMerhaba<|im_end|>'), isTrue);
    expect(prompt.endsWith('<|im_start|>assistant\n<think>\n\n</think>\n\n'), isTrue);
  });

  test('uzun istek bağlama sığacak şekilde kısaltılır ve başı ile sonu korunur', () {
    final long = 'BAŞ${'x' * 20000}SON';
    final prompt = builder.build(long, contextTokens: 2048, maxTokens: 320);
    expect(prompt.length, lessThan(6000));
    expect(prompt.contains('BAŞ'), isTrue);
    expect(prompt.contains('SON'), isTrue);
    expect(prompt.contains('[...kısaltıldı...]'), isTrue);
  });

  test('küçük bağlamda da en az bir bütçe kalır', () {
    final prompt = builder.build('a' * 5000, contextTokens: 512, maxTokens: 128);
    expect(prompt.length, lessThan(2500));
  });

  test('çıktı temizleyici düşünme bloklarını ve etiketleri siler', () {
    expect(cleaner.clean('<think>iç ses</think>Merhaba!<|im_end|>'), 'Merhaba!');
    expect(cleaner.clean('Cevap<|im_end|>\n'), 'Cevap');
    expect(cleaner.clean('<think>bitmemiş düşünce'), '');
    expect(cleaner.clean('  Selam  '), 'Selam');
  });
}
