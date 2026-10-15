import 'package:flutter/material.dart';

import '../../application/office/cio_finding.dart';
import '../../application/office/cio_service.dart';
import '../../application/office/office_hub.dart';
import '../../core/format/tr_date.dart';

/// CIO raporu: sistem durumu, rutin kontrol bulguları ve çözüm önerileri.
class CioReportScreen extends StatefulWidget {
  const CioReportScreen({super.key, required this.cio, required this.hub});

  final CioService cio;
  final OfficeHub hub;

  @override
  State<CioReportScreen> createState() => _CioReportScreenState();
}

class _CioReportScreenState extends State<CioReportScreen> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    await widget.cio.runRoutineCheck();
    if (mounted) setState(() => _busy = false);
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'error':
        return const Color(0xFFFF5A5A);
      case 'warn':
        return const Color(0xFFF1C40F);
      case 'ok':
        return const Color(0xFF3DDC84);
      default:
        return const Color(0xFF68DEFC);
    }
  }

  Widget _statusRow(String title, bool? ok) {
    final color = ok == null ? const Color(0xFF6B7A88) : (ok ? const Color(0xFF3DDC84) : const Color(0xFFFF9F43));
    final text = ok == null ? 'Kontrol edilmedi' : (ok ? 'Aktif' : 'Sorun var');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 8),
          Text('$title: $text', style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _finding(CioFinding f) {
    final color = _levelColor(f.level);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1722),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${f.area} • ${f.text}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          if (f.fix.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Çözüm: ${f.fix}', style: const TextStyle(color: Colors.white70, height: 1.4)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05080D),
      appBar: AppBar(title: const Text('CIO RAPORU'), backgroundColor: const Color(0xFF08131D)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: AnimatedBuilder(
            animation: widget.hub,
            builder: (context, _) {
              final status = widget.hub.systemStatus;
              final report = widget.cio.lastReport;
              final last = widget.cio.lastRunAt;
              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const Text('Sistem durumu', style: TextStyle(color: Color(0xFF68DEFC), fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  _statusRow('Yapay zekâ altyapısı', status['ai']),
                  _statusRow('İnternet bağlantısı', status['internet']),
                  _statusRow('Veri / depolama', status['sync']),
                  _statusRow('Güvenlik', status['security']),
                  const SizedBox(height: 8),
                  Text(
                    last == null
                        ? 'Rutin kontrol henüz çalışmadı.'
                        : 'Son kontrol: ${formatTrDate(last)} ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _run,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Şimdi kontrol et'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Bulgular ve çözüm önerileri', style: TextStyle(color: Color(0xFF68DEFC), fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (report.isEmpty) const Text('Bulgu yok.', style: TextStyle(color: Colors.white54)),
                  for (final f in report) _finding(f),
                  const SizedBox(height: 8),
                  const Text(
                    'CIO rutin kontrolü uygulama açıkken yaklaşık 3 dakikada bir çalışır. Uygulama kapalıyken arka planda çalışmaz.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
