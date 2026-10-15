import 'package:flutter/material.dart';

/// Görselin sol-üst köşesine göre oransal (0..1) dikdörtgen.
///
/// Dokunma alanları ve canlı katmanlar ekran boyutuna göre DEĞİL, görselin
/// kendi boyutuna göre konumlandırılır. Bu sayede ekran oranı ne olursa olsun
/// (16:10 tablet, 20:9 telefon vb.) alanlar görseldeki yerinden kaymaz.
class StageRect {
  const StageRect(this.left, this.top, this.right, this.bottom);

  /// Referans uzayındaki piksel değerlerinden oransal alan üretir.
  /// [refWidth] ve [refHeight], koordinatların ölçüldüğü görsel boyutudur.
  factory StageRect.px(
    double x1,
    double y1,
    double x2,
    double y2, {
    required double refWidth,
    required double refHeight,
  }) {
    return StageRect(x1 / refWidth, y1 / refHeight, x2 / refWidth, y2 / refHeight);
  }

  final double left;
  final double top;
  final double right;
  final double bottom;
}

/// Görselin üzerine yerleşen tek bir katman (dokunma alanı veya canlı içerik).
class StageLayer {
  const StageLayer({required this.rect, required this.child});

  final StageRect rect;
  final Widget child;
}

/// Katmanlara görsel ölçeğini (görsel genişliği / referans genişlik) verir.
/// Yazı boyutlarını görselle birlikte büyütüp küçültmek için kullanılır.
class StageScope extends InheritedWidget {
  const StageScope({super.key, required this.scale, required super.child});

  final double scale;

  /// Tasarım pikseli cinsinden yazı boyutunu ekrana uyarlar (en az [min]).
  static double font(BuildContext context, double designPx, {double min = 9}) {
    final scope = context.dependOnInheritedWidgetOfExactType<StageScope>();
    final scale = scope?.scale ?? 1.0;
    final value = designPx * scale;
    return value < min ? min : value;
  }

  static double scaleOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StageScope>();
    return scope?.scale ?? 1.0;
  }

  @override
  bool updateShouldNotify(StageScope oldWidget) => oldWidget.scale != scale;
}

/// Hata ayıklama: --dart-define=ARES_DEBUG_HITBOX=true ile dokunma alanları görünür.
const bool aresDebugHitbox = bool.fromEnvironment('ARES_DEBUG_HITBOX');

/// Görünmez dokunma alanı katmanı oluşturur.
StageLayer stageHit({
  required StageRect rect,
  required VoidCallback onTap,
  String label = '',
}) {
  return StageLayer(
    rect: rect,
    child: Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: aresDebugHitbox
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x33FF0000),
                  border: Border.all(color: const Color(0xAAFF0000)),
                ),
              )
            : const SizedBox.expand(),
      ),
    ),
  );
}

/// Görseli oranını koruyarak mevcut alana sığdırır ve üzerine katmanları koyar.
///
/// BoxFit.contain mantığıyla çalışır: görsel kırpılmaz, gerekirse kenarlarda
/// [background] renginde boşluk kalır; katmanlar yine görsele göre hizalıdır.
class ImageStage extends StatelessWidget {
  const ImageStage({
    super.key,
    required this.asset,
    required this.imageSize,
    required this.layers,
    this.background = const Color(0xFF05080D),
    this.keyboardInset = 0,
    this.keyboardAnchor = 1.0,
  });

  /// Görselin asset yolu.
  final String asset;

  /// Görselin gerçek piksel boyutu (en-boy oranı için).
  final Size imageSize;

  /// Görselin üstündeki katmanlar (sondaki en üstte çizilir).
  final List<StageLayer> layers;

  /// Görselin dışında kalan alanın rengi.
  final Color background;

  /// Klavyenin kapladığı yükseklik. Sıfırdan büyükse sahne, [keyboardAnchor]
  /// ile belirtilen yatay çizgi klavyenin üstünde kalacak kadar yukarı kayar.
  final double keyboardInset;

  /// Görselin yüksekliğine oranla, klavye açılınca görünür kalması gereken çizgi (0..1).
  final double keyboardAnchor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableW = constraints.maxWidth;
        final availableH = constraints.maxHeight;
        final scaleW = availableW / imageSize.width;
        final scaleH = availableH / imageSize.height;
        final scale = scaleW < scaleH ? scaleW : scaleH;
        final stageW = imageSize.width * scale;
        final stageH = imageSize.height * scale;
        final offsetX = (availableW - stageW) / 2;
        var offsetY = (availableH - stageH) / 2;
        if (keyboardInset > 0) {
          final anchorY = offsetY + keyboardAnchor * stageH + 12;
          final keyboardTop = availableH - keyboardInset;
          if (anchorY > keyboardTop) offsetY -= anchorY - keyboardTop;
        }

        return ColoredBox(
          color: background,
          child: Stack(
            children: [
              Positioned(
                left: offsetX,
                top: offsetY,
                width: stageW,
                height: stageH,
                child: StageScope(
                  scale: scale,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          asset,
                          fit: BoxFit.fill,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              'Görsel yüklenemedi\n$asset',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ),
                      for (final layer in layers)
                        Positioned(
                          left: layer.rect.left * stageW,
                          top: layer.rect.top * stageH,
                          width: (layer.rect.right - layer.rect.left) * stageW,
                          height: (layer.rect.bottom - layer.rect.top) * stageH,
                          child: layer.child,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
