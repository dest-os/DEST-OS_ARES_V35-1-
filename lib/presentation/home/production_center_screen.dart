import 'package:flutter/material.dart';

/// Üretim Merkezi: Geliştirme / İçerik ekibinin uzun üretim işleri.
class ProductionCenterScreen extends StatelessWidget {
  const ProductionCenterScreen({
    super.key,
    required this.onOpenMobile,
    required this.onOpenVideo,
    required this.onOpenContent,
  });

  final VoidCallback onOpenMobile;
  final VoidCallback onOpenVideo;
  final VoidCallback onOpenContent;

  Widget _card(IconData icon, String title, String text, VoidCallback onTap) {
    return Card(
      color: const Color(0xFF0A1722),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, color: Colors.cyanAccent, size: 36),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(text, style: const TextStyle(color: Colors.white60)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05080D),
      appBar: AppBar(title: const Text('ÜRETİM MERKEZİ'), backgroundColor: const Color(0xFF08131D)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Sohbette "görev takip uygulaması yap" gibi bir istek yazarsanız CEO bu işi otomatik olarak Geliştirme Ekibi\'ne verir. '
                'Ayrıntılı ayarlarla çalışmak için aşağıdaki ekranları da açabilirsiniz.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 16),
              _card(Icons.phone_android, 'Mobil Uygulama Üret', 'Geliştirme Ekibi: her özellik ayrı dosya olarak üretilir.', onOpenMobile),
              _card(Icons.movie_creation_outlined, 'Video İçerik Üret', 'İçerik Ekibi: senaryo, altyazı, sahne planı.', onOpenVideo),
              _card(Icons.description_outlined, 'Genel İçerik Üret', 'İçerik Ekibi: doküman, makale, sunum metni.', onOpenContent),
            ],
          ),
        ),
      ),
    );
  }
}
