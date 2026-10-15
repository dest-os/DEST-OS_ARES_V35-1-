import 'package:flutter_test/flutter_test.dart';

import '../../../lib/application/codegen/prompt_builder_service.dart';
import '../../../lib/domain/codegen/project_spec.dart';

void main() {
  test('ajan promptu önceki ajanların dosya içeriğini taşır', () {
    final prompt = const PromptBuilderService().build(
      role: CodegenAgentRole.flutterDeveloper,
      projectSpec: const ProjectSpec(
        projectName: 'Test',
        description: 'Test uygulaması üret',
        packageName: 'test_app',
        features: <String>['Test'],
        architecture: ArchitectureType.clean,
        requiredPackages: <String>[],
        screens: <String>['Ana'],
        acceptanceCriteria: <String>['main.dart oluşturulmalı'],
        includeTests: true,
        includeReadme: true,
      ),
      relevantFiles: const <String>[],
      fileExcerpts: const <String, String>{'docs/product.md': 'KABUL KRITERI: gorev eklenebilir'},
    );
    expect(prompt.userPrompt, contains('docs/product.md'));
    expect(prompt.userPrompt, contains('KABUL KRITERI'));
  });
}
