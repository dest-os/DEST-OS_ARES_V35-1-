import 'package:flutter/material.dart';

class ConnectorCenterScreen extends StatelessWidget {
  const ConnectorCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ARES Tool & Connector Merkezi')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bağlantılar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('Araçlar ve dış bağlantılar güvenlik katmanından geçirilir.'),
            SizedBox(height: 24),
            Card(child: ListTile(title: Text('Tool Registry'), subtitle: Text('Kayıtlı araçların yönetimi'))),
            Card(child: ListTile(title: Text('Connector Registry'), subtitle: Text('API ve servis bağlantıları'))),
            Card(child: ListTile(title: Text('Credential Vault'), subtitle: Text('Gizli bilgiler yalnızca referansla kullanılır'))),
            Card(child: ListTile(title: Text('Quota & Health'), subtitle: Text('Limit, maliyet ve bağlantı durumu'))),
          ],
        ),
      ),
    );
  }
}
