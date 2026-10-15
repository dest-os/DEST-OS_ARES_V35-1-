import 'package:flutter/material.dart';

import '../../application/runtime/production/production_composition_root.dart';
import '../../domain/runtime/runtime_snapshot.dart';

class ProductionRuntimeScreen extends StatefulWidget {
  const ProductionRuntimeScreen({super.key});

  @override
  State<ProductionRuntimeScreen> createState() => _ProductionRuntimeScreenState();
}

class _ProductionRuntimeScreenState extends State<ProductionRuntimeScreen> {
  final _root = ProductionCompositionRoot();
  RuntimeSnapshot? _snapshot;

  Future<void> _start() async {
    final runtime = _root.build();
    await runtime.start();
    if (!mounted) return;
    setState(() => _snapshot = runtime.snapshot());
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(title: const Text('ARES Üretim Çalışma Sistemi')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Durum: ${snapshot?.status.name ?? 'stopped'}'),
            Text('Mod: ${snapshot?.mode.name ?? 'online'}'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _start, child: const Text('Çalışma Sistemini Başlat')),
          ],
        ),
      ),
    );
  }
}
