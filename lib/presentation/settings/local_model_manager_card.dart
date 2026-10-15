
import 'package:flutter/material.dart';

import '../../infrastructure/ai/local_model_config.dart';
import '../../infrastructure/ai/local_model_downloader.dart';
import '../../infrastructure/ai/local_model_service.dart';
import '../../infrastructure/ai/local_model_storage.dart';

/// ARES gömülü yerel modelinin indirme, yükleme ve hızlı test kontrolleri.
class LocalModelManagerCard extends StatefulWidget {
  const LocalModelManagerCard({
    super.key,
    required this.service,
    required this.downloader,
  });

  final LocalModelService service;
  final LocalModelDownloader downloader;

  @override
  State<LocalModelManagerCard> createState() => _LocalModelManagerCardState();
}

class _LocalModelManagerCardState extends State<LocalModelManagerCard> {
  final LocalModelStorage _storage = LocalModelStorage();

  bool _busy = false;
  bool _modelAvailable = false;
  bool _modelLoaded = false;
  double? _progress;
  String _bytesText = '';
  String _fileSizeText = '';
  String _status = 'Model durumu kontrol ediliyor…';
  String _testOutput = '';

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  Future<void> _refreshStatus() async {
    try {
      final file = await _storage.getModelFile();
      final available = file != null;
      final size = file == null ? 0 : await file.length();
      final loaded = await widget.service.isModelLoaded;
      if (!mounted) return;
      setState(() {
        _modelAvailable = available;
        _modelLoaded = loaded;
        _fileSizeText = available ? '${_mb(size)} MB' : '';
        _status = loaded
            ? 'Hazır: model belleğe yüklü (bağlam ${widget.service.activeContext} token).'
            : available
                ? 'Model cihazda var; belleğe yüklenmemiş.'
                : 'Model henüz indirilmedi.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Model durumu alınamadı: $error');
    }
  }

  Future<void> _loadWithFeedback() async {
    setState(() {
      _progress = null;
      _bytesText = '';
      _status = 'Model belleğe yükleniyor… (birkaç saniye sürebilir)';
    });
    final ok = await widget.service.ensureLoaded();
    if (ok) {
      await _storage.deleteLegacyModel();
    }
    await _refreshStatus();
    if (!mounted) return;
    if (!ok) {
      final reason = widget.service.lastError;
      setState(() => _status = 'Model yüklenemedi: ${reason.isEmpty ? 'bilinmeyen hata' : reason}');
    }
  }

  Future<void> _downloadAndLoad() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _bytesText = '';
      _status = 'Model indiriliyor (≈ ${_mb(LocalModelConfig.approxSizeBytes)} MB). Wi-Fi önerilir; bu ekranı açık tutun.';
    });
    try {
      await widget.downloader.downloadModel(
        onProgress: (value) {
          if (!mounted) return;
          setState(() => _progress = value);
        },
        onBytes: (received, total) {
          if (!mounted) return;
          setState(() => _bytesText = '${_mb(received)} / ${_mb(total)} MB');
        },
      );
      if (!mounted) return;
      await _loadWithFeedback();
    } catch (error) {
      if (!mounted) return;
      await _refreshStatus();
      if (!mounted) return;
      setState(() {
        _progress = null;
        _status = 'İndirme başarısız: $error';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadExistingModel() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _loadWithFeedback();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _quickTest() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _testOutput = '';
      _status = 'Test çalışıyor…';
    });
    final watch = Stopwatch()..start();
    try {
      final loaded = await widget.service.ensureLoaded();
      if (!loaded) {
        throw StateError('Model yüklü değil: ${widget.service.lastError}');
      }
      final text = await widget.service.generateText(
        'Merhaba! Kendini tek cümleyle tanıt.',
        maxTokens: 80,
      );
      watch.stop();
      final seconds = watch.elapsedMilliseconds / 1000;
      final approxTokens = (text.length / 3).round();
      if (!mounted) return;
      setState(() {
        _testOutput = text.isEmpty ? '(boş cevap)' : text;
        _status = text.isEmpty
            ? 'Test: model cevap üretmedi.'
            : 'Test tamam: ${seconds.toStringAsFixed(1)} sn, yaklaşık ${(approxTokens / (seconds <= 0 ? 1 : seconds)).toStringAsFixed(1)} token/sn.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _testOutput = '';
        _status = 'Test başarısız: $error';
      });
    } finally {
      await _refreshStatusKeepingMessage();
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Durum satırını ezmeden yalnızca düğme durumlarını tazeler.
  Future<void> _refreshStatusKeepingMessage() async {
    try {
      final available = await _storage.isModelAvailable();
      final loaded = await widget.service.isModelLoaded;
      if (!mounted) return;
      setState(() {
        _modelAvailable = available;
        _modelLoaded = loaded;
      });
    } catch (_) {
      // Düğme durumu tazelenemezse mevcut değerler korunur.
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _modelLoaded
        ? Colors.greenAccent
        : _modelAvailable
            ? Colors.orangeAccent
            : Colors.white70;

    return Card(
      color: const Color(0xFF0A1722),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF123A57)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.memory, color: Colors.cyanAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ARES Gömülü Yerel AI',
                    style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(LocalModelConfig.fileName, style: const TextStyle(color: Colors.white)),
            if (_fileSizeText.isNotEmpty)
              Text('Cihazdaki dosya: $_fileSizeText', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            const Text(
              'İlk indirme için internet ve yaklaşık 430 MB boş alan gerekir. İndirildikten sonra model '
              'internetsiz, cihaz üzerinde çalışır. Küçük bir modeldir: kısa ve basit işlerde iyidir, '
              'uzun ve karmaşık işlerde hata yapabilir.',
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(_status, style: TextStyle(color: statusColor, height: 1.3)),
            if (_busy && _progress != null) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: _progress, color: Colors.cyanAccent, backgroundColor: Colors.white12),
              const SizedBox(height: 4),
              Text(
                '${((_progress ?? 0) * 100).toStringAsFixed(1)}%  ${_bytesText}',
                style: const TextStyle(color: Colors.white70),
              ),
            ] else if (_busy) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(color: Colors.cyanAccent),
            ],
            if (_testOutput.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF05111B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF123A57)),
                ),
                child: SelectableText(_testOutput, style: const TextStyle(color: Colors.white, height: 1.35)),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy || _modelLoaded
                      ? null
                      : _modelAvailable
                          ? _loadExistingModel
                          : _downloadAndLoad,
                  icon: Icon(_modelAvailable ? Icons.play_arrow : Icons.download),
                  label: Text(_modelAvailable ? 'Modeli yükle' : 'İndir ve yükle'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy || !_modelAvailable ? null : _quickTest,
                  icon: const Icon(Icons.bolt),
                  label: const Text('Hızlı test'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _refreshStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Durumu yenile'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
