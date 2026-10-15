import 'package:flutter_test/flutter_test.dart';

import '../../lib/domain/content/content_mode.dart';

void main() {
  test('content mode labels are stable', () {
    expect(ContentMode.mobileApp.label, 'Mobil Uygulama Üret');
    expect(ContentMode.video.label, 'Video İçerik Üret');
    expect(ContentMode.general.label, 'Genel İçerik Üret');
  });
}
