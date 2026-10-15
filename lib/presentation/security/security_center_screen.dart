import 'package:flutter/material.dart';
import 'security_screen_model.dart';

class SecurityCenterScreen extends StatelessWidget {
  const SecurityCenterScreen({super.key, required this.model});
  final SecurityScreenModel model;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(model.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(title: const Text('Aktif güvenlik kuralları'), trailing: Text('${model.activeRules}')),
          ListTile(title: const Text('Engellenen işlemler'), trailing: Text('${model.blockedActions}')),
          ListTile(title: const Text('Bekleyen onaylar'), trailing: Text('${model.pendingApprovals}')),
        ],
      ),
    );
  }
}
