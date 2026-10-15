import 'package:flutter/material.dart';

class AresAiCenterScreen extends StatelessWidget {
  const AresAiCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = <(String, String, String)>[
      ('YEREL AI', 'Cihaz uzerinde calisan modeller', 'LOCAL'),
      ('UCRETSIZ AI', 'Ucretsiz kullanim dogrulaması', 'FREE'),
      ('SINIRLI UCRETSIZ', 'Limitli ucretsiz saglayicilar', 'LIMITED FREE'),
      ('UCRETLI AI', 'Kullanim oncesi Ibrahim onayi zorunlu', 'PAID'),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF05080D),
      appBar: AppBar(
        title: const Text('AI Merkezi'),
        backgroundColor: const Color(0xFF08131D),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = cards[index];
          return Card(
            color: const Color(0xFF0A1520),
            child: ListTile(
              title: Text(item.$1, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
              subtitle: Text(item.$2, style: const TextStyle(color: Colors.white70)),
              trailing: Text(item.$3, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          );
        },
      ),
    );
  }
}
