import 'package:flutter/material.dart';
class ProductionRecoveryScreen extends StatelessWidget {
  const ProductionRecoveryScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF050A10),
    appBar: AppBar(title: const Text('ARES Üretim Kurtarma'), backgroundColor: const Color(0xFF071522)),
    body: const Padding(padding: EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('YEDEKLEME / GERİ YÜKLEME / GÜNCELLEME', style: TextStyle(color: Colors.cyan, fontSize: 18)),
      SizedBox(height: 18),
      Text('• Yedek bütünlüğü doğrulanır.', style: TextStyle(color: Colors.white70)),
      Text('• Geri yükleme öncesi önizleme yapılır.', style: TextStyle(color: Colors.white70)),
      Text('• Yıkıcı işlemler onay olmadan uygulanmaz.', style: TextStyle(color: Colors.white70)),
      Text('• Güncelleme imza ve bütünlük kontrolünden geçer.', style: TextStyle(color: Colors.white70)),
      Text('• Başarısız güncellemede geri dönüş korunur.', style: TextStyle(color: Colors.white70)),
    ])),
  );
}
