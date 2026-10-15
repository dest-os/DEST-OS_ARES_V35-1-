import 'code_artifact.dart';

/// Kod üretim işleminin değişmez sonucudur.
class GenerationResult {
  /// Creates an immutable generation result.
  GenerationResult({
    required this.success,
    required List<CodeArtifact> artifacts,
    required List<String> errors,
    required Map<String, Object?> metrics,
    List<String> suggestedActions = const <String>[],
  }) : artifacts = List.unmodifiable(artifacts),
       errors = List.unmodifiable(errors),
       metrics = Map.unmodifiable(metrics),
       suggestedActions = List.unmodifiable(suggestedActions);

  /// Whether the complete generation flow succeeded.
  final bool success;

  /// Artifacts produced before the result was returned.
  final List<CodeArtifact> artifacts;

  /// Errors encountered during generation.
  final List<String> errors;

  /// Suggested corrective actions associated with validation or runtime errors.
  final List<String> suggestedActions;

  /// Diagnostic metrics and execution logs.
  final Map<String, Object?> metrics;

  /// Returns a copy with the supplied fields replaced.
  GenerationResult copyWith({
    bool? success,
    List<CodeArtifact>? artifacts,
    List<String>? errors,
    List<String>? suggestedActions,
    Map<String, Object?>? metrics,
  }) {
    return GenerationResult(
      success: success ?? this.success,
      artifacts: artifacts ?? this.artifacts,
      errors: errors ?? this.errors,
      suggestedActions: suggestedActions ?? this.suggestedActions,
      metrics: metrics ?? this.metrics,
    );
  }
}
