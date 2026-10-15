import 'package:flutter/material.dart';

class ProductionReleaseScreen extends StatelessWidget {
  const ProductionReleaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <String>[
      'Release manifest ve bütünlük',
      'Production imzası',
      'V30 entegrasyon kontrolleri',
      'Güvenlik ve gizlilik',
      'Backup / Restore',
      'Update / Migration',
      'Ücretli AI son onay kapısı',
      'Local AI model ve lisans doğrulaması',
      '2400×1600 tablet smoke testi',
      'Production izleme ve audit',
      'Rollback / recovery hazırlığı',
      'Release artifact manifest',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF050A10),
      appBar: AppBar(
        title: const Text('ARES V31 • Production Release'),
        backgroundColor: const Color(0xFF07131E),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) => Card(
          color: const Color(0xFF0B1823),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.cyan.withValues(alpha: .12),
              child: Text('${index + 1}'),
            ),
            title: Text(items[index], style: const TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.verified_outlined, color: Colors.cyanAccent),
          ),
        ),
      ),
    );
  }
}
