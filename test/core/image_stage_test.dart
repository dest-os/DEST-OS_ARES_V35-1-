import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/ui/image_stage.dart';

void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(2000, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<Rect> _hitRect(WidgetTester tester, Size screen) async {
  _bigScreen(tester);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: screen.width,
          height: screen.height,
          child: const ImageStage(
            asset: 'assets/images/yok.png',
            imageSize: Size(1536, 1024),
            layers: <StageLayer>[
              StageLayer(rect: StageRect(0.5, 0.5, 0.75, 1.0), child: SizedBox.expand(key: Key('hit'))),
            ],
          ),
        ),
      ),
    ),
  );
  return tester.getRect(find.byKey(const Key('hit')));
}

void main() {
  testWidgets('geniş ekranda alan görselin aynı yerinde kalır (yan boşluk)', (tester) async {
    // 800x400: görsel 600x400 olur, soldan 100 boşluk kalır.
    final rect = await _hitRect(tester, const Size(800, 400));
    expect(rect.left, closeTo(400, 0.6));
    expect(rect.top, closeTo(200, 0.6));
    expect(rect.width, closeTo(150, 0.6));
    expect(rect.height, closeTo(200, 0.6));
  });

  testWidgets('uzun ekranda alan görselin aynı yerinde kalır (üst-alt boşluk)', (tester) async {
    // 400x800: görsel 400x266.67 olur, üstten 266.67 boşluk kalır.
    final rect = await _hitRect(tester, const Size(400, 800));
    expect(rect.left, closeTo(200, 0.6));
    expect(rect.top, closeTo(400, 0.6));
    expect(rect.width, closeTo(100, 0.6));
    expect(rect.height, closeTo(133.3, 0.6));
  });

  testWidgets('klavye açılınca sahne çapa çizgisini görünür tutacak kadar yukarı kayar', (tester) async {
    _bigScreen(tester);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
          width: 1536,
          height: 1024,
          child: ImageStage(
            asset: 'assets/images/yok.png',
            imageSize: const Size(1536, 1024),
            keyboardInset: 400,
            keyboardAnchor: 0.9,
            layers: const <StageLayer>[
              StageLayer(rect: StageRect(0.0, 0.9, 1.0, 1.0), child: SizedBox.expand(key: Key('anchor'))),
            ],
          ),
          ),
        ),
      ),
    );
    final rect = tester.getRect(find.byKey(const Key('anchor')));
    // Çapa çizgisi (üst kenar) klavyenin üstünden yukarıda olmalı.
    expect(rect.top, lessThan(1024 - 400));
  });
}
