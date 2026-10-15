import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/office/approval_actions.dart';
import '../../application/office/approval_store.dart';
import '../../application/office/cio_service.dart';
import '../../application/office/office_agents.dart';
import '../../application/office/provider_store.dart';
import '../../application/radar/model_radar_service.dart';
import '../../core/format/tr_date.dart';
import '../../core/result/ares_result.dart';
import '../../domain/ai/ai_response.dart';
import '../../domain/office/ai_provider.dart';
import '../../infrastructure/codegen/provider_router_gateway.dart';
import '../../infrastructure/ai/local_model_downloader.dart';
import '../../infrastructure/ai/local_model_service.dart';
import '../../infrastructure/codegen/openai_compatible_transport.dart';
import 'local_model_manager_card.dart';

const Color _bg = Color(0xFF05080D);
const Color _panel = Color(0xFF0A1722);
const Color _line = Color(0xFF123A57);
const Color _cyan = Color(0xFF68DEFC);

Color statusColor(ProviderStatus status) {
  switch (status) {
    case ProviderStatus.active:
      return const Color(0xFF2ECC71);
    case ProviderStatus.limited:
      return const Color(0xFFF1C40F);
    case ProviderStatus.limitReached:
      return const Color(0xFF3498DB);
    case ProviderStatus.deprecated:
      return const Color(0xFFE74C3C);
    case ProviderStatus.inactive:
      return const Color(0xFF6B7A88);
  }
}

String statusLabel(ProviderStatus status) {
  switch (status) {
    case ProviderStatus.active:
      return 'Kullanımda';
    case ProviderStatus.limited:
      return 'Sınırlı kullanım / günlük kota';
    case ProviderStatus.limitReached:
      return 'Kota doldu';
    case ProviderStatus.deprecated:
      return 'Kullanımdan kalktı';
    case ProviderStatus.inactive:
      return 'Etkin değil';
  }
}

Color _categoryColor(ProviderCategory category) {
  switch (category) {
    case ProviderCategory.free:
      return const Color(0xFF2ECC71);
    case ProviderCategory.limitedFree:
      return const Color(0xFFF1C40F);
    case ProviderCategory.paid:
      return const Color(0xFFE74C3C);
    case ProviderCategory.local:
      return const Color(0xFF3498DB);
    case ProviderCategory.tool:
      return const Color(0xFF9B59B6);
    case ProviderCategory.other:
      return const Color(0xFF95A5A6);
  }
}

String _categoryTag(ProviderCategory category) {
  switch (category) {
    case ProviderCategory.free:
      return 'Ücretsiz';
    case ProviderCategory.limitedFree:
      return 'Sınırlı Ücretsiz';
    case ProviderCategory.paid:
      return 'Ücretli';
    case ProviderCategory.local:
      return 'Yerel';
    case ProviderCategory.tool:
      return 'Araç / Uzman';
    case ProviderCategory.other:
      return 'Diğer';
  }
}

class _SectionDef {
  const _SectionDef(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

/// Sistem & API Ayarları (CEO masasındaki göz).
class AresSettingsCenter extends StatefulWidget {
  const AresSettingsCenter({
    super.key,
    required this.providers,
    required this.approvals,
    required this.actions,
    required this.router,
    required this.radar,
    required this.cio,
    required this.localModelService,
    required this.localModelDownloader,
    this.initialSection,
  });

  final ProviderStore providers;
  final ApprovalStore approvals;
  final ApprovalActions actions;
  final ProviderRouterGateway router;
  final ModelRadarService radar;
  final CioService cio;
  final LocalModelService localModelService;
  final LocalModelDownloader localModelDownloader;
  final String? initialSection;

  @override
  State<AresSettingsCenter> createState() => _AresSettingsCenterState();
}

class _AresSettingsCenterState extends State<AresSettingsCenter> {
  static const List<_SectionDef> _tabs = <_SectionDef>[
    _SectionDef('general', 'Genel Ayarlar', Icons.tune),
    _SectionDef('catalog', 'AI Kataloğu', Icons.apps),
    _SectionDef('keys', 'API Anahtarları', Icons.vpn_key_outlined),
    _SectionDef('order', 'Model Sıralaması', Icons.format_list_numbered),
    _SectionDef('usage', 'Kullanım & Limitler', Icons.speed),
    _SectionDef('approvals', 'Onaylar', Icons.verified_user_outlined),
  ];

  static const List<_SectionDef> _rail = <_SectionDef>[
    _SectionDef('catalog', 'AI & API Merkezi', Icons.hub_outlined),
    _SectionDef('general', 'Genel AI Ayarları', Icons.tune),
    _SectionDef('order', 'Model Sıralaması', Icons.format_list_numbered),
    _SectionDef('usage', 'Kullanım & Limitler', Icons.speed),
    _SectionDef('approvals', 'Onaylar', Icons.verified_user_outlined),
    _SectionDef('security', 'Güvenlik', Icons.shield_outlined),
    _SectionDef('backup', 'Yedekle / Geri Yükle', Icons.backup_outlined),
    _SectionDef('info', 'Sistem Bilgileri', Icons.info_outline),
  ];

  late String _section;
  bool _includeKeys = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection ?? 'catalog';
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 5)));
  }

  // —— Ortak parçalar ——

  Widget _card({required Widget child, Color border = _line}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
      child: child,
    );
  }

  Widget _heading(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: const TextStyle(color: _cyan, fontSize: 20, fontWeight: FontWeight.bold)),
    );
  }

  Widget _muted(String text) {
    return Text(text, style: const TextStyle(color: Colors.white60, height: 1.4));
  }

  Widget _dot(Color color) {
    return Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }

  // —— Katalog ——

  Widget _legend() {
    Widget item(Color color, String text) {
      return Padding(
        padding: const EdgeInsets.only(right: 16, bottom: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [_dot(color), const SizedBox(width: 6), Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13))]),
      );
    }

    return Wrap(
      children: [
        item(statusColor(ProviderStatus.active), 'Kullanımda'),
        item(statusColor(ProviderStatus.limited), 'Sınırlı / günlük kota'),
        item(statusColor(ProviderStatus.limitReached), 'Kota doldu'),
        item(statusColor(ProviderStatus.deprecated), 'Kullanımdan kalktı'),
        item(statusColor(ProviderStatus.inactive), 'Etkin değil'),
      ],
    );
  }

  Widget _providerRow(AiProviderConfig p) {
    final status = p.statusAt(widget.providers.today);
    final color = statusColor(status);
    return InkWell(
      onTap: () => _editProvider(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _dot(color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  Text(
                    '${p.vendor} • ${p.capabilities.isEmpty ? 'Bilgi yok' : p.capabilities}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    '${statusLabel(status)}${p.autoFilled && !p.hasKey && p.needsKey ? ' • API anahtarınızı girin' : ''}',
                    style: TextStyle(color: color, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (status == ProviderStatus.deprecated)
              IconButton(
                tooltip: 'Katalogdan sil',
                icon: const Icon(Icons.delete_outline, color: Color(0xFFE74C3C)),
                onPressed: () => _confirmRemove(p),
              ),
          ],
        ),
      ),
    );
  }

  Widget _categoryCard(ProviderCategory category, double width) {
    final items = widget.providers.inCategory(category);
    final color = _categoryColor(category);
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.6))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(providerCategoryLabel(category), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.25), borderRadius: BorderRadius.circular(12)),
                child: Text(_categoryTag(category), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(color: _line),
          if (items.isEmpty) const Text('Bu kategoride sağlayıcı yok.', style: TextStyle(color: Colors.white38)),
          for (final p in items) _providerRow(p),
        ],
      ),
    );
  }

  Widget _catalog() {
    return AnimatedBuilder(
      animation: widget.providers,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 3 : (constraints.maxWidth >= 600 ? 2 : 1);
            final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
            return ListView(
              children: [
                _legend(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(onPressed: _busy ? null : _scanRadar, icon: const Icon(Icons.radar), label: const Text('AI Radar: şimdi tara')),
                    OutlinedButton.icon(onPressed: _addCustom, icon: const Icon(Icons.add), label: const Text('Özel sağlayıcı ekle')),
                  ],
                ),
                const SizedBox(height: 4),
                _muted('Kategoriler ve adresler bilinen genel bilgilere göredir, uygulama içinden doğrulanmaz. Ücret ve kota bilgisini sağlayıcının sitesinden kontrol edin.'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [for (final c in ProviderCategory.values) _categoryCard(c, width)],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _scanRadar() async {
    setState(() => _busy = true);
    try {
      final result = await widget.radar.scan(force: true);
      if (!mounted) return;
      final errors = result.errors.isEmpty ? '' : '\nUyarılar: ${result.errors.take(2).join(' | ')}';
      _notice('Radar bitti: ${result.newModels} yeni model, ${result.newSuggestions} yeni öneri. Onaylar bölümüne bakın.$errors');
    } catch (error) {
      if (mounted) _notice('Radar çalışamadı: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRemove(AiProviderConfig p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Katalogdan silinsin mi?'),
        content: Text('${p.name} silinecek. Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok == true) await widget.providers.remove(p.id);
  }

  Future<void> _editProvider(AiProviderConfig p) async {
    final baseUrl = TextEditingController(text: p.baseUrl);
    final model = TextEditingController(text: p.model);
    final key = TextEditingController(text: p.apiKey);
    final limit = TextEditingController(text: p.dailyLimit > 0 ? '${p.dailyLimit}' : '');
    var enabled = p.enabled;
    var deprecated = p.deprecated;
    var models = <String>[];
    var modelsBusy = false;
    var modelsError = '';
    String? selectedModel = p.model.isEmpty ? null : p.model;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> fetchModels() async {
            final url = baseUrl.text.trim();
            if (url.isEmpty) {
              setLocal(() {
                modelsError = 'Önce Base URL girin.';
                models = <String>[];
              });
              return;
            }
            setLocal(() {
              modelsBusy = true;
              modelsError = '';
            });
            try {
              final list = await RemoteModelCatalog().listModels(
                baseUrl: url,
                apiKey: key.text,
              );
              if (!ctx.mounted) return;
              setLocal(() {
                models = list;
                modelsBusy = false;
                if (list.isEmpty) {
                  modelsError = 'Sağlayıcı model listesi döndürmedi. Model adını elle yazabilirsiniz.';
                } else if (selectedModel != null && !list.contains(selectedModel)) {
                  // Keep current model text even if not in list
                }
              });
            } catch (e) {
              if (!ctx.mounted) return;
              setLocal(() {
                modelsBusy = false;
                modelsError = 'Liste alınamadı: $e';
                models = <String>[];
              });
            }
          }

          return AlertDialog(
            title: Text(p.name),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${providerCategoryLabel(p.category)} · ${p.vendor}', style: const TextStyle(color: Colors.white70)),
                    if (p.siteUrl.isNotEmpty)
                      SelectableText('Anahtar/Site: ${p.siteUrl}', style: const TextStyle(color: _cyan)),
                    if (!p.chat)
                      const Text('Araç AI: sohbet için çağrılmaz, yalnızca katalogda tutulur.', style: TextStyle(color: Colors.white54)),
                    if (p.category == ProviderCategory.paid)
                      const Text('Ücretli: kullanım için Onaylar bölümünde onayınız gerekir.', style: TextStyle(color: Color(0xFFFFB27A))),
                    const SizedBox(height: 8),
                    TextField(controller: baseUrl, decoration: const InputDecoration(labelText: 'Adres (Base URL)')),
                    const SizedBox(height: 8),
                    // API anahtarı — model listesi bunun hemen altında / model seçimi üstte
                    if (p.needsKey || p.category != ProviderCategory.local)
                      TextField(
                        controller: key,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(labelText: 'API anahtarı'),
                      ),
                    const SizedBox(height: 10),
                    // Model keşfi satırı
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            models.isEmpty
                                ? 'Bu API anahtarıyla açılan modeller'
                                : 'Modeller (${models.length}) — CEO / kullanıcı seçebilir',
                            style: const TextStyle(color: _cyan, fontWeight: FontWeight.w600),
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: modelsBusy ? null : fetchModels,
                          child: modelsBusy
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Modelleri getir'),
                        ),
                      ],
                    ),
                    if (modelsError.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(modelsError, style: const TextStyle(color: Color(0xFFFFB27A), fontSize: 12)),
                    ],
                    if (models.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: _panel,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _line),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: models.length,
                          itemBuilder: (_, i) {
                            final id = models[i];
                            final selected = (selectedModel ?? model.text.trim()) == id;
                            return ListTile(
                              dense: true,
                              selected: selected,
                              title: Text(id, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              trailing: selected ? const Icon(Icons.check, color: _cyan, size: 18) : null,
                              onTap: () {
                                setLocal(() {
                                  selectedModel = id;
                                  model.text = id;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: model,
                      decoration: const InputDecoration(
                        labelText: 'Seçili model adı',
                        helperText: 'Listeden seçin veya elle yazın',
                      ),
                    ),
                    TextField(
                      controller: limit,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Günlük istek sınırı (0 = sınırsız)'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Etkin (ekip bunu kullanabilir)'),
                      value: enabled,
                      onChanged: (v) => setLocal(() => enabled = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Kullanımdan kalktı olarak işaretle'),
                      value: deprecated,
                      onChanged: (v) => setLocal(() => deprecated = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Vazgeç')),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Kaydet')),
            ],
          );
        },
      ),
    );

    final updated = p.copyWith(
      baseUrl: baseUrl.text.trim(),
      model: model.text.trim(),
      apiKey: key.text.trim(),
      dailyLimit: int.tryParse(limit.text.trim()) ?? 0,
      enabled: enabled,
      deprecated: deprecated,
    );
    baseUrl.dispose();
    model.dispose();
    key.dispose();
    limit.dispose();
    if (saved != true) return;
    await widget.providers.upsert(updated);
    if (updated.category == ProviderCategory.paid && updated.enabled && !updated.paidApproved) {
      await widget.approvals.request(
        kind: 'paid_ai',
        title: 'Ücretli AI kullanım onayı: ${updated.name}',
        detail: '${updated.name} ücretlidir. Onaylarsanız istekler bu servise gönderilir ve hesabınızdan ücret kesilebilir.',
        refId: updated.id,
      );
      if (mounted) _notice('${updated.name} ücretli: Onaylar bölümünde onay verene kadar kullanılmaz.');
    } else if (mounted) {
      _notice('${updated.name} kaydedildi. Model: ${updated.model.isEmpty ? "(yok)" : updated.model}');
    }
  }


  Future<void> _addCustom() async {
    final name = TextEditingController();
    final baseUrl = TextEditingController();
    final model = TextEditingController();
    final key = TextEditingController();
    var category = ProviderCategory.limitedFree;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Özel sağlayıcı ekle (OpenAI uyumlu)'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Ad')),
                  TextField(controller: baseUrl, decoration: const InputDecoration(labelText: 'Adres (https://…/v1)')),
                  TextField(controller: model, decoration: const InputDecoration(labelText: 'Model adı')),
                  TextField(controller: key, obscureText: true, decoration: const InputDecoration(labelText: 'API anahtarı (gerekmiyorsa boş)')),
                  const SizedBox(height: 8),
                  DropdownButton<ProviderCategory>(
                    value: category,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: ProviderCategory.free, child: Text('Ücretsiz')),
                      DropdownMenuItem(value: ProviderCategory.limitedFree, child: Text('Sınırlı ücretsiz')),
                      DropdownMenuItem(value: ProviderCategory.paid, child: Text('Ücretli')),
                      DropdownMenuItem(value: ProviderCategory.local, child: Text('Yerel')),
                      DropdownMenuItem(value: ProviderCategory.other, child: Text('Diğer')),
                    ],
                    onChanged: (v) => setLocal(() => category = v ?? category),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Ekle')),
          ],
        ),
      ),
    );
    final title = name.text.trim();
    final url = baseUrl.text.trim();
    final modelName = model.text.trim();
    final apiKey = key.text.trim();
    name.dispose();
    baseUrl.dispose();
    model.dispose();
    key.dispose();
    if (saved != true || title.isEmpty || url.isEmpty) return;
    await widget.providers.upsert(
      AiProviderConfig(
        id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
        name: title,
        vendor: 'Özel',
        category: category,
        baseUrl: url,
        model: modelName,
        apiKey: apiKey,
        needsKey: category != ProviderCategory.local,
      ),
    );
    if (mounted) _notice('$title eklendi. Etkinleştirmek için kartına dokunun.');
  }

  // —— API anahtarları ——

  Widget _keys() {
    return AnimatedBuilder(
      animation: widget.providers,
      builder: (context, _) {
        final list = widget.providers.ordered.where((p) => p.needsKey).toList();
        return ListView(
          children: [
            _heading('API Anahtarları'),
            _muted('Anahtarı yalnızca siz girersiniz. Radar bir servisi eklediğinde bilgileri doldurur, anahtarı sizden ister. Anahtarlar bu cihazda uygulamanın özel alanında düz dosya olarak saklanır.'),
            const SizedBox(height: 12),
            for (final p in list) _KeyRow(key: ValueKey('key_${p.id}'), provider: p, store: widget.providers, router: widget.router),
          ],
        );
      },
    );
  }

  // —— Model sıralaması ——

  Widget _order() {
    return AnimatedBuilder(
      animation: widget.providers,
      builder: (context, _) {
        final chat = widget.providers.chatProviders;
        final callable = widget.providers.callable;
        final callableIds = callable.map((p) => p.id).toList();
        return ListView(
          children: [
            _heading('Model Sıralaması'),
            _muted('İşler yukarıdan aşağıya bu sırayla denenir. Bir sağlayıcının kotası dolarsa iş sıradakine devredilir ve kaldığı yerden devam eder. Sürükleyerek sıralayın.'),
            const SizedBox(height: 10),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) => widget.providers.reorderChat(oldIndex, newIndex),
              children: [
                for (var i = 0; i < chat.length; i++)
                  Container(
                    key: ValueKey('order_${chat[i].id}'),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(10), border: Border.all(color: _line)),
                    child: ListTile(
                      leading: CircleAvatar(radius: 14, backgroundColor: _line, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 13))),
                      title: Text(chat[i].name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(statusLabel(chat[i].statusAt(widget.providers.today)), style: TextStyle(color: statusColor(chat[i].statusAt(widget.providers.today)), fontSize: 12)),
                      trailing: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle, color: Colors.white54)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _heading('Ekiplere özel yapay zekâ'),
            _muted('İsterseniz bir ekibin işini belirli bir yapay zekâya verin. "Otomatik" seçilirse sıralama kullanılır.'),
            const SizedBox(height: 8),
            for (final team in const ['research', 'development', 'content', 'support'])
              _card(
                child: Row(
                  children: [
                    Expanded(child: Text(teamLabel(team), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                    DropdownButton<String>(
                      value: callableIds.contains(widget.providers.teamProvider[team]) ? widget.providers.teamProvider[team] : '',
                      items: [
                        const DropdownMenuItem<String>(value: '', child: Text('Otomatik (sıraya göre)')),
                        for (final p in callable) DropdownMenuItem<String>(value: p.id, child: Text(p.name)),
                      ],
                      onChanged: (v) => widget.providers.setTeamProvider(team, v),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // —— Kullanım & limitler ——

  Widget _usage() {
    return AnimatedBuilder(
      animation: widget.providers,
      builder: (context, _) {
        final today = widget.providers.today;
        return ListView(
          children: [
            _heading('Kullanım & Limitler'),
            _muted('Sayaçlar yalnızca bu uygulamanın gönderdiği istekleri sayar. Kota dolduğunda sağlayıcı bugün için "mavi" olur ve yarın otomatik açılır.'),
            const SizedBox(height: 10),
            for (final p in widget.providers.chatProviders)
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _dot(statusColor(p.statusAt(today))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                        Text(statusLabel(p.statusAt(today)), style: TextStyle(color: statusColor(p.statusAt(today)), fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bugün: ${p.usageDay == today ? p.usedToday : 0} istek • Günlük sınır: ${p.dailyLimit > 0 ? p.dailyLimit : 'yok'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(onPressed: () => widget.providers.clearLimit(p.id), child: const Text('Kotayı sıfırla')),
                        OutlinedButton(onPressed: () => _editProvider(p), child: const Text('Sınırı değiştir')),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // —— Onaylar ——

  String _kindLabel(String kind) {
    switch (kind) {
      case 'paid_ai':
        return 'Ücretli AI';
      case 'new_ai':
        return 'Yeni AI önerisi';
      case 'new_model':
        return 'Yeni model';
      default:
        return 'Onay';
    }
  }

  Widget _approvals() {
    return AnimatedBuilder(
      animation: widget.approvals,
      builder: (context, _) {
        final pending = widget.approvals.pending;
        final done = widget.approvals.all.where((r) => !r.isPending).take(10).toList();
        return ListView(
          children: [
            _heading('Onaylar'),
            _muted('Ücretli AI kullanımı ve radarın yeni AI önerileri sizin onayınız olmadan uygulanmaz.'),
            const SizedBox(height: 10),
            if (pending.isEmpty) _card(child: const Text('Bekleyen onay yok.', style: TextStyle(color: Colors.white54))),
            for (final r in pending)
              _card(
                border: const Color(0xFF8A6D1B),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_kindLabel(r.kind)} • ${r.title}', style: const TextStyle(color: Color(0xFFFFE08A), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(r.detail, style: const TextStyle(color: Colors.white70, height: 1.4)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () async {
                            final message = await widget.actions.decide(r, approved: true);
                            if (mounted) _notice(message);
                          },
                          child: const Text('Onayla'),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            final message = await widget.actions.decide(r, approved: false);
                            if (mounted) _notice(message);
                          },
                          child: const Text('Reddet'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (done.isNotEmpty) ...[
              const SizedBox(height: 8),
              _heading('Geçmiş kararlar'),
              for (final r in done)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('${r.status == 'approved' ? '✓ Onaylandı' : '✗ Reddedildi'} — ${r.title}', style: const TextStyle(color: Colors.white54)),
                ),
            ],
          ],
        );
      },
    );
  }

  // —— Genel ——

  Widget _general() {
    return ListView(
      children: [
        _heading('Genel AI Ayarları'),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Çalışma kuralları', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _muted('• CEO, hatalı veya eksik sonucu ekibe en fazla ${3} kez geri gönderir; düzelmezse ayrıntılı rapor ve tavsiyeyle size iletir.\n'
                  '• Ücretli yapay zekâ onayınız olmadan kullanılmaz.\n'
                  '• Kotası dolan yapay zekânın işi sıradakine devredilir.\n'
                  '• Başarılı işler Eğitim klasörüne tarih ve konu başlığıyla kaydedilir; silme kararı sizindir.\n'
                  '• Ekip, bilmediği konuda uydurma yapmamak üzere yönlendirilir; yine de sonuçları kontrol edin.'),
            ],
          ),
        ),
        LocalModelManagerCard(
          service: widget.localModelService,
          downloader: widget.localModelDownloader,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          children: [
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final findings = await widget.cio.runRoutineCheck();
                      if (!mounted) return;
                      setState(() => _busy = false);
                      _notice('CIO kontrolü bitti: ${findings.length} bulgu. Ayrıntı için Güvenlik veya ana ekrandaki CIO raporuna bakın.');
                    },
              icon: const Icon(Icons.health_and_safety_outlined),
              label: const Text('CIO kontrolünü şimdi çalıştır'),
            ),
            OutlinedButton.icon(onPressed: _busy ? null : _scanRadar, icon: const Icon(Icons.radar), label: const Text('AI Radar: şimdi tara')),
          ],
        ),
      ],
    );
  }

  // —— Güvenlik ——

  Widget _security() {
    final findings = widget.cio.lastReport.where((f) => f.area == 'Güvenlik').toList();
    return ListView(
      children: [
        _heading('Güvenlik'),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mevcut korumalar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _muted('• Ücretli yapay zekâ onaysız çağrılmaz.\n'
                  '• Eğitim klasörüne yazılan metinlerdeki anahtar/parola benzeri değerler gizlenir.\n'
                  '• Yedeğe API anahtarları varsayılan olarak eklenmez.\n'
                  '• Uygulama verileri bulut yedeğine dahil edilmez.\n'
                  '• Üretilen koda Güvenlik ajanı kural tabanlı tarama yapar.'),
            ],
          ),
        ),
        _card(
          border: const Color(0xFF8A6D1B),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bilinen sınırlar', style: TextStyle(color: Color(0xFFFFE08A), fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _muted('• API anahtarları cihazda düz dosyada saklanır; şifreli depolama henüz yok.\n'
                  '• Kural tabanlı tarama her açığı bulamaz; bulunmaması güvenli olduğu anlamına gelmez.'),
            ],
          ),
        ),
        _heading('Son kontrol bulguları'),
        if (findings.isEmpty) _muted('Güvenlik ile ilgili bulgu yok (veya kontrol henüz çalışmadı).'),
        for (final f in findings)
          _card(child: Text('${f.text}\n${f.fix}', style: const TextStyle(color: Colors.white70, height: 1.4))),
      ],
    );
  }

  // —— Yedek ——

  Widget _backup() {
    return ListView(
      children: [
        _heading('Yedekle / Geri Yükle'),
        _muted('Yedek, AI kataloğunu ve sıralamayı JSON olarak panoya kopyalar. Bir not uygulamasına yapıştırıp saklayabilirsiniz. Eğitim klasörü ve sohbetler bu yedeğe dahil değildir.'),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('API anahtarlarını da yedeğe ekle'),
          subtitle: const Text('Önerilmez: pano başka uygulamalarca okunabilir.', style: TextStyle(color: Color(0xFFFFB27A))),
          value: _includeKeys,
          onChanged: (v) => setState(() => _includeKeys = v),
        ),
        Wrap(
          spacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () async {
                final text = const JsonEncoder.withIndent('  ').convert(widget.providers.exportJson(includeKeys: _includeKeys));
                await Clipboard.setData(ClipboardData(text: text));
                if (mounted) _notice('Yedek panoya kopyalandı (${text.length} karakter).');
              },
              icon: const Icon(Icons.copy),
              label: const Text('Yedeği panoya kopyala'),
            ),
            OutlinedButton.icon(onPressed: _restore, icon: const Icon(Icons.paste), label: const Text('Yedekten geri yükle')),
          ],
        ),
      ],
    );
  }

  Future<void> _restore() async {
    final controller = TextEditingController();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text != null) controller.text = clip!.text!;
    if (!mounted) {
      controller.dispose();
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yedekten geri yükle'),
        content: SizedBox(
          width: 560,
          child: TextField(controller: controller, minLines: 6, maxLines: 12, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Yedek JSON metnini yapıştırın')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Geri yükle')),
        ],
      ),
    );
    final text = controller.text;
    controller.dispose();
    if (go != true) return;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) throw const FormatException('Yedek bir JSON nesnesi olmalı.');
      await widget.providers.importJson(Map<String, dynamic>.from(decoded));
      if (mounted) _notice('Yedek geri yüklendi.');
    } on FormatException catch (error) {
      if (mounted) _notice('Yedek okunamadı: ${error.message}');
    } catch (error) {
      if (mounted) _notice('Yedek geri yüklenemedi: $error');
    }
  }

  // —— Sistem bilgileri ——

  Widget _info() {
    final last = widget.cio.lastRunAt;
    return ListView(
      children: [
        _heading('Sistem Bilgileri'),
        _card(
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[widget.providers, widget.approvals]),
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _muted('Sürüm: 0.1.0 (DEST-OS ARES)'),
                  _muted('Katalogdaki sağlayıcı: ${widget.providers.ordered.length}'),
                  _muted('Çalışabilir sağlayıcı: ${widget.providers.callable.length}'),
                  _muted('Bekleyen onay: ${widget.approvals.pendingCount}'),
                  _muted('Son CIO kontrolü: ${last == null ? 'henüz yapılmadı' : '${formatTrDate(last)} ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}'}'),
                ],
              );
            },
          ),
        ),
        FutureBuilder<DateTime?>(
          future: widget.radar.lastScanAt(),
          builder: (context, snapshot) {
            final at = snapshot.data;
            return _muted('Son AI Radar taraması: ${at == null ? 'henüz yapılmadı' : '${formatTrDate(at)} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'}');
          },
        ),
      ],
    );
  }

  Widget _content() {
    switch (_section) {
      case 'keys':
        return _keys();
      case 'order':
        return _order();
      case 'usage':
        return _usage();
      case 'approvals':
        return _approvals();
      case 'general':
        return _general();
      case 'security':
        return _security();
      case 'backup':
        return _backup();
      case 'info':
        return _info();
      default:
        return _catalog();
    }
  }

  Widget _tabButton(_SectionDef def) {
    final selected = _section == def.key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(def.label),
        selected: selected,
        onSelected: (_) => setState(() => _section = def.key),
        selectedColor: const Color(0xFF00448A),
        backgroundColor: const Color(0xFF0A1722),
        labelStyle: TextStyle(color: selected ? _cyan : Colors.white70, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _railItem(_SectionDef def, {required bool wide}) {
    final selected = _section == def.key;
    final badge = def.key == 'approvals' ? widget.approvals.pendingCount : 0;
    return InkWell(
      onTap: () => setState(() => _section = def.key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0B3A63) : const Color(0xFF0A1722),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? const Color(0xFF3BA7FF) : _line),
        ),
        child: Row(
          children: [
            Icon(def.icon, size: 20, color: selected ? _cyan : Colors.white70),
            if (wide) ...[
              const SizedBox(width: 10),
              Expanded(child: Text(def.label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.w600))),
            ],
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(10)),
                child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF08131D),
        title: const Text('SİSTEM & API AYARLARI'),
        actions: [IconButton(tooltip: 'Kapat', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).maybePop())],
      ),
      body: AnimatedBuilder(
        animation: widget.approvals,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: wide ? 230 : 64,
                      child: ListView(children: [for (final def in _rail) _railItem(def, wide: wide)]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (final def in _tabs) _tabButton(def)])),
                          const SizedBox(height: 10),
                          Expanded(child: _content()),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// API Anahtarları sekmesindeki tek satır: anahtar kutusu, kaydet ve test.
class _KeyRow extends StatefulWidget {
  const _KeyRow({super.key, required this.provider, required this.store, required this.router});

  final AiProviderConfig provider;
  final ProviderStore store;
  final ProviderRouterGateway router;

  @override
  State<_KeyRow> createState() => _KeyRowState();
}

class _KeyRowState extends State<_KeyRow> {
  late final TextEditingController _key;
  bool _busy = false;
  String _result = '';
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    _key = TextEditingController(text: widget.provider.apiKey);
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  AiProviderConfig _current() {
    return (widget.store.byId(widget.provider.id) ?? widget.provider).copyWith(apiKey: _key.text.trim());
  }

  Future<void> _save() async {
    await widget.store.upsert(_current());
    if (!mounted) return;
    setState(() {
      _result = 'Kaydedildi.';
      _ok = true;
    });
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _result = 'Deneniyor…';
      _ok = false;
    });
    final p = _current();
    await widget.store.upsert(p);
    final result = await widget.router.testProvider(p);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result is AresSuccess<AiResponse>) {
        _ok = true;
        _result = 'Çalışıyor. Model: ${result.value.modelName}';
      } else if (result is AresFailure<AiResponse>) {
        _ok = false;
        _result = result.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${p.name}  •  ${_categoryTag(p.category)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          if (p.siteUrl.isNotEmpty) SelectableText('Anahtar alınacak site: ${p.siteUrl}', style: const TextStyle(color: _cyan, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _key,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'API anahtarı', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(onPressed: _busy ? null : _save, child: const Text('Kaydet')),
              if (p.chat) OutlinedButton(onPressed: _busy ? null : _test, child: const Text('Kaydet ve test et')),
            ],
          ),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_result, style: TextStyle(color: _ok ? const Color(0xFF3DDC84) : const Color(0xFFFFB27A), height: 1.3)),
            ),
        ],
      ),
    );
  }
}
