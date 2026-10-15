import 'package:flutter/material.dart';

import '../../application/ai/ai_gateway.dart';
import '../../application/settings/ares_settings.dart';
import '../../core/result/ares_result.dart';
import '../../core/security/cost_policy.dart';
import '../../domain/ai/ai_request.dart';
import '../../domain/ai/ai_response.dart';

/// CEO masasındaki göz: Sistem & API Ayarları / AI Merkezi.
/// Görsel referans: ares_sistem_api_ayarlari_referans.png
/// Senaryo: Ücretsiz (yeşil), Sınırlı ücretsiz (sarı), Ücretli (kırmızı),
/// Yerel, Araç, Diğer kategoriler. Kullanımda olanlar yeşil, kota dolunca mavi, kalkmış kırmızı+sil.
class AresSettingsScreen extends StatefulWidget {
  const AresSettingsScreen({super.key, required this.store, required this.gateway});

  final AresSettingsStore store;
  final AresAiGateway gateway;

  @override
  State<AresSettingsScreen> createState() => _AresSettingsScreenState();
}

class _AresSettingsScreenState extends State<AresSettingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late final TextEditingController _freeUrl;
  late final TextEditingController _freeModel;
  late final TextEditingController _freeKey;
  late final TextEditingController _localUrl;
  late final TextEditingController _localModel;
  late bool _localEnabled;
  bool _hideKey = true;
  bool _busy = false;
  String? _status;
  bool _statusOk = false;

  // Örnek katalog (senaryo: gerçek veriler sonradan girilecek; başlangıç için yerel açık kaynak)
  static const List<_AiCard> _catalog = [
    // Ücretsiz
    _AiCard(name: 'Llama 3.2', provider: 'Meta', tags: 'Metin, Görsel, Kod', tier: _Tier.free, status: _Status.active, local: true),
    _AiCard(name: 'Mistral 7B', provider: 'Mistral AI', tags: 'Metin, Kod', tier: _Tier.free, status: _Status.active, local: true),
    _AiCard(name: 'Phi 3', provider: 'Microsoft', tags: 'Metin, Kod', tier: _Tier.free, status: _Status.active, local: true),
    // Sınırlı ücretsiz
    _AiCard(name: 'Gemini 1.5 Flash', provider: 'Google', tags: 'Metin, Görsel, Kod', tier: _Tier.limited, status: _Status.active),
    _AiCard(name: 'Claude 3.5 Haiku', provider: 'Anthropic', tags: 'Metin, Görsel, Kod', tier: _Tier.limited, status: _Status.active),
    _AiCard(name: 'GPT-4o Mini', provider: 'OpenAI', tags: 'Metin, Görsel, Kod', tier: _Tier.limited, status: _Status.active),
    // Ücretli
    _AiCard(name: 'GPT-4o', provider: 'OpenAI', tags: 'Metin, Görsel, Kod', tier: _Tier.paid, status: _Status.active),
    _AiCard(name: 'Claude 3.5 Sonnet', provider: 'Anthropic', tags: 'Metin, Görsel, Kod', tier: _Tier.paid, status: _Status.active),
    _AiCard(name: 'Gemini 1.5 Pro', provider: 'Google', tags: 'Metin, Görsel, Kod', tier: _Tier.paid, status: _Status.active),
    // Yerel
    _AiCard(name: 'Ollama (Llama, Mistral)', provider: 'Yerel', tags: 'Metin, Kod', tier: _Tier.local, status: _Status.active, local: true),
    _AiCard(name: 'Stable Diffusion', provider: 'Yerel', tags: 'Görsel Üretim', tier: _Tier.local, status: _Status.active, local: true),
    _AiCard(name: 'Whisper', provider: 'Yerel', tags: 'Ses Tanıma', tier: _Tier.local, status: _Status.active, local: true),
    // Araçlar
    _AiCard(name: 'DALL-E 3', provider: 'OpenAI', tags: 'Görsel Üretim', tier: _Tier.tool, status: _Status.active),
    _AiCard(name: 'ElevenLabs', provider: 'ElevenLabs', tags: 'Ses Üretim', tier: _Tier.tool, status: _Status.active),
    _AiCard(name: 'Tavily', provider: 'Tavily', tags: 'Web Arama', tier: _Tier.tool, status: _Status.active),
    // Diğer
    _AiCard(name: 'Perplexity', provider: 'Perplexity', tags: 'Web Araştırma', tier: _Tier.other, status: _Status.active),
    _AiCard(name: 'HuggingFace', provider: 'HF', tags: 'Çeşitli Modeller', tier: _Tier.other, status: _Status.active),
    _AiCard(name: 'Groq', provider: 'Groq', tags: 'Hızlı Çıkarım', tier: _Tier.other, status: _Status.active),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
    final s = widget.store.current;
    _freeUrl = TextEditingController(text: s.freeBaseUrl);
    _freeModel = TextEditingController(text: s.freeModel);
    _freeKey = TextEditingController(text: s.freeApiKey);
    _localUrl = TextEditingController(text: s.localBaseUrl);
    _localModel = TextEditingController(text: s.localModel);
    _localEnabled = s.localEnabled;
  }

  @override
  void dispose() {
    _tab.dispose();
    _freeUrl.dispose();
    _freeModel.dispose();
    _freeKey.dispose();
    _localUrl.dispose();
    _localModel.dispose();
    super.dispose();
  }

  AresSettings _collect() => AresSettings(
        localEnabled: _localEnabled,
        localBaseUrl: _localUrl.text.trim(),
        localModel: _localModel.text.trim(),
        freeBaseUrl: _freeUrl.text.trim(),
        freeModel: _freeModel.text.trim(),
        freeApiKey: _freeKey.text.trim(),
      );

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.store.save(_collect());
      if (!mounted) return;
      setState(() {
        _status = 'Ayarlar kaydedildi. Yerel / ücretsiz yapılandırma aktif.';
        _statusOk = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = 'Ayarlar kaydedilemedi: $error';
        _statusOk = false;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _status = 'Bağlantı deneniyor…';
      _statusOk = false;
    });
    try {
      await widget.store.save(_collect());
      final result = await widget.gateway.generate(
        const AiRequest(instruction: 'Sadece "tamam" yaz.', costClass: AiCostClass.free),
      );
      if (!mounted) return;
      setState(() {
        if (result is AresSuccess<AiResponse>) {
          _status = 'Bağlantı çalışıyor. Model: ${result.value.modelName}';
          _statusOk = true;
        } else if (result is AresFailure<AiResponse>) {
          _status = result.message;
          _statusOk = false;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = 'Test başarısız: $error';
        _statusOk = false;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05080D),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.settings, color: Colors.cyanAccent, size: 22),
            SizedBox(width: 8),
            Text('SİSTEM & API AYARLARI', style: TextStyle(fontSize: 18)),
          ],
        ),
        backgroundColor: const Color(0xFF08131D),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            onPressed: _busy ? null : _test,
            tooltip: 'Kaydet ve test et',
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Genel Ayarlar'),
            Tab(text: 'AI Kataloğu'),
            Tab(text: 'API Anahtarları'),
            Tab(text: 'Model Sıralaması'),
            Tab(text: 'Kullanım & Limitler'),
            Tab(text: 'Onaylar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildGeneralTab(),
          _buildCatalogTab(),
          _buildApiKeysTab(),
          _buildPlaceholder('Model Sıralaması', 'Aktif modeller öncelik sırasına göre listelenir. Yerel → Ücretsiz → Sınırlı → Ücretli (onaylı).'),
          _buildPlaceholder('Kullanım & Limitler', 'Günlük / aylık kota, token kullanımı ve uyarı eşikleri burada yönetilir.'),
          _buildPlaceholder('Onaylar', 'Ücretli AI kullanımı için kullanıcı onayı zorunludur. Onay verilmeden ücretli model çağrılmaz.'),
        ],
      ),
    );
  }

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Yerel AI (Başlangıç — açık kaynak)'),
        SwitchListTile(
          title: const Text('Yerel AI etkin', style: TextStyle(color: Colors.white)),
          subtitle: const Text('Ollama / LM Studio / yerel endpoint', style: TextStyle(color: Colors.white54)),
          value: _localEnabled,
          activeColor: Colors.greenAccent,
          onChanged: (v) => setState(() => _localEnabled = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _localUrl,
          style: const TextStyle(color: Colors.white),
          decoration: _dec('Yerel Base URL', 'http://localhost:11434'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _localModel,
          style: const TextStyle(color: Colors.white),
          decoration: _dec('Yerel Model', 'qwen3:4b / llama3.2 / mistral'),
        ),
        const SizedBox(height: 24),
        _sectionTitle('Ücretsiz / Sınırlı Ücretsiz Endpoint'),
        TextField(
          controller: _freeUrl,
          style: const TextStyle(color: Colors.white),
          decoration: _dec('Base URL', 'https://api.groq.com/openai/v1'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _freeModel,
          style: const TextStyle(color: Colors.white),
          decoration: _dec('Model adı', 'llama-3.1-8b-instant'),
        ),
        const SizedBox(height: 20),
        if (_status != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _statusOk ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _statusOk ? Colors.greenAccent : Colors.redAccent),
            ),
            child: Text(_status!, style: TextStyle(color: _statusOk ? Colors.greenAccent : Colors.redAccent)),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.save),
                label: const Text('Kaydet'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _test,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow),
                label: const Text('Kaydet ve Test Et'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Senaryo notu: Program açıldığında boş kabuk olmaz. Yerel açık kaynak AI ile başlangıç çalışmaları yönetilir. '
          'Ücretli AI kullanıcı onayı olmadan kullanılmaz.',
          style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildCatalogTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _tierHeader('Ücretsiz AI\'lar', Colors.greenAccent, 'Ücretsiz'),
        _cardGrid(_catalog.where((c) => c.tier == _Tier.free)),
        const SizedBox(height: 16),
        _tierHeader('Sınırlı Ücretsiz', Colors.amberAccent, 'Sınırlı Ücretsiz'),
        _cardGrid(_catalog.where((c) => c.tier == _Tier.limited)),
        const SizedBox(height: 16),
        _tierHeader('Ücretli AI\'lar', Colors.redAccent, 'Ücretli'),
        _cardGrid(_catalog.where((c) => c.tier == _Tier.paid)),
        const SizedBox(height: 16),
        _tierHeader('Yerel AI\'lar', Colors.lightBlueAccent, 'Yerel'),
        _cardGrid(_catalog.where((c) => c.tier == _Tier.local)),
        const SizedBox(height: 16),
        _tierHeader('Araç AI\'ları', Colors.purpleAccent, 'Araç / Uzmanlık'),
        _cardGrid(_catalog.where((c) => c.tier == _Tier.tool)),
        const SizedBox(height: 16),
        _tierHeader('Diğer AI\'lar', Colors.blueGrey, 'Diğer'),
        _cardGrid(_catalog.where((c) => c.tier == _Tier.other)),
        const SizedBox(height: 20),
        const Text(
          'Renkler: Yeşil = kullanımda · Sarı = sınırlı/kota · Mavi = sınıra ulaşıldı · Kırmızı = kullanım dışı / silinebilir',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildApiKeysTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('API Anahtarı (ücretsiz / sınırlı endpoint)'),
        TextField(
          controller: _freeKey,
          obscureText: _hideKey,
          style: const TextStyle(color: Colors.white),
          decoration: _dec(
            'API Anahtarı',
            'Boş bırakılabilir (yerel kullanılıyorsa)',
            suffix: IconButton(
              icon: Icon(_hideKey ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
              onPressed: () => setState(() => _hideKey = !_hideKey),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'API anahtarı cihazda saklanır (allowBackup=false). Bulut yedeğine karışmaz. '
          'Ücretli modeller için anahtar kullanıcı tarafından girilir ve onay kapısından geçer.',
          style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _busy ? null : _save,
          icon: const Icon(Icons.save),
          label: const Text('Anahtarı Kaydet'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade800),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(String title, String body) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, color: Colors.cyanAccent, size: 48),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(color: Colors.cyanAccent, fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _tierHeader(String title, Color color, String badge) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
              child: Text(badge, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _cardGrid(Iterable<_AiCard> cards) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cards.map((c) => _AiCatalogCard(card: c)).toList(),
    );
  }

  InputDecoration _dec(String label, String hint, {Widget? suffix}) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white24),
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyan.withOpacity(0.3))),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
        border: const OutlineInputBorder(),
      );
}

enum _Tier { free, limited, paid, local, tool, other }
enum _Status { active, limitedQuota, exhausted, retired }

class _AiCard {
  const _AiCard({
    required this.name,
    required this.provider,
    required this.tags,
    required this.tier,
    required this.status,
    this.local = false,
  });
  final String name;
  final String provider;
  final String tags;
  final _Tier tier;
  final _Status status;
  final bool local;
}

class _AiCatalogCard extends StatelessWidget {
  const _AiCatalogCard({required this.card});
  final _AiCard card;

  Color get _border {
    switch (card.status) {
      case _Status.active:
        return card.tier == _Tier.paid ? Colors.redAccent : Colors.greenAccent;
      case _Status.limitedQuota:
        return Colors.amberAccent;
      case _Status.exhausted:
        return Colors.blueAccent;
      case _Status.retired:
        return Colors.red.shade900;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1520),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: _border, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              if (card.status == _Status.retired)
                const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
            ],
          ),
          const SizedBox(height: 4),
          Text(card.provider, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 6),
          Text(card.tags, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          if (card.local) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
              child: const Text('Yerel / Ücretsiz', style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
            ),
          ],
        ],
      ),
    );
  }
}
