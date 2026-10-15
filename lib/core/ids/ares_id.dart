import 'dart:math';

class AresId {
  const AresId(this.value);

  final String value;

  static AresId generate() {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return AresId('ares_$now$random');
  }

  /// Geriye donuk takma ad
  static AresId newId() => generate();

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) => other is AresId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
