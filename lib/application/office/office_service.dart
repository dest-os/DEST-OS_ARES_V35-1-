import '../../core/format/tr_date.dart';
import '../../core/ids/ares_id.dart';
import '../../core/result/ares_result.dart';
import '../../core/security/cost_policy.dart';
import '../../domain/ai/ai_request.dart';
import '../../domain/ai/ai_response.dart';
import '../../domain/archive/work_archive_entry.dart';
import '../../infrastructure/codegen/provider_router_gateway.dart';
import '../archive/archive_similarity.dart';
import '../archive/secret_scrubber.dart';
import '../archive/work_archive_repository.dart';
import '../codegen/ceo_review_service.dart';
import 'office_agents.dart';
import 'office_hub.dart';
import 'provider_store.dart';
import 'support_knowledge.dart';

/// CEO'nun isteği hangi konu olarak sınıflandırdığı.
enum OfficeIntent { chat, help, research, learn, security, code, video, content }

/// Sohbete eklenen dosya.
class OfficeAttachment {
  const OfficeAttachment({required this.name, required this.path, this.text = '', this.isImage = false});

  final String name;
  final String path;

  /// Okunabilen metin içeriği (görseller için boş).
  final String text;
  final bool isImage;
}

/// Dinleyici'nin kullanıcıya ilettiği sonuç.
class OfficeReply {
  const OfficeReply({
    required this.text,
    this.agent = 'Dinleyici',
    this.ok = true,
    this.fromArchive = false,
    this.report,
  });

  final String text;

  /// Cevabı hazırlayan ajan veya ekip.
  final String agent;
  final bool ok;

  /// Cevap Eğitim klasöründen geldi (yapay zekâ çağrısı yapılmadı).
  final bool fromArchive;

  /// Başarısız işlerde CEO'nun ayrıntılı raporu.
  final String? report;
}

/// Uzun işleri (uygulama/video/içerik üretimi) çalıştıran dış bağlantı.
typedef WorkRunner = Future<OfficeReply> Function(String request, void Function(String status) onStatus);

class _Step {
  const _Step(this.agentId, this.label, this.instruction);

  final String agentId;
  final String label;
  final String instruction;
}

/// Dinleyici → CEO → ekipler → CEO onayı → Dinleyici hattını yürütür.
class OfficeService {
  OfficeService({
    required this.router,
    required this.hub,
    required this.archive,
    required this.providers,
    this.codeRunner,
    this.videoRunner,
    this.contentRunner,
    this.support = const SupportKnowledge(),
    this.scrubber = const SecretScrubber(),
    this.similarity = const ArchiveSimilarity(),
  });

  /// CEO'nun işi ekibe geri gönderebileceği en fazla sayı.
  static const int maxReturns = 3;

  final ProviderRouterGateway router;
  final OfficeHub hub;
  final WorkArchiveRepository archive;
  final ProviderStore providers;
  final WorkRunner? codeRunner;
  final WorkRunner? videoRunner;
  final WorkRunner? contentRunner;
  final SupportKnowledge support;
  final SecretScrubber scrubber;
  final ArchiveSimilarity similarity;

  static const CeoReviewService _ceo = CeoReviewService();

  /// Sıradaki ilk yapay zekâ cihaz içi küçük model mi? Öyleyse istemler kısaltılır
  /// ve CEO incelemesi atlanır (küçük model hem yavaştır hem iyi bir hakem değildir).
  bool get _smallModel {
    final list = providers.callable;
    return list.isNotEmpty && list.first.id == ProviderRouterGateway.embeddedLocalProviderId;
  }

  static String _normalize(String text) => text.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

  static bool _hasAny(String text, List<String> keys) {
    for (final key in keys) {
      if (text.contains(key)) return true;
    }
    return false;
  }

  /// İsteği konuya göre sınıflandırır (kural tabanlı, token harcamaz).
  OfficeIntent classify(String request) {
    final t = _normalize(request);
    if (_hasAny(t, const ['uygulama yap', 'uygulama üret', 'uygulama geliştir', 'uygulama oluştur', 'apk', 'flutter', 'mobil uygulama', 'program yaz', 'kod yaz', 'kod üret'])) {
      return OfficeIntent.code;
    }
    if (_hasAny(t, const ['video', 'senaryo', 'altyazı', 'shorts', 'reels'])) return OfficeIntent.video;
    if (_hasAny(t, const ['güvenlik açı', 'zafiyet', 'güvenlik tara', 'güvenli mi', 'saldırı'])) return OfficeIntent.security;
    if (_hasAny(t, const ['öğret', 'öğren', 'ders ver', 'ders anlat', 'eğitim ver'])) return OfficeIntent.learn;
    if (_hasAny(t, const ['araştır', 'karşılaştır', 'incele', 'analiz et', 'rapor hazırla'])) return OfficeIntent.research;
    if (_hasAny(t, const ['makale', 'blog', 'içerik üret', 'doküman', 'metin yaz', 'sunum'])) return OfficeIntent.content;
    if (_hasAny(t, const ['nasıl yapabilirim', 'nasıl kullan', 'ne işe yarar', 'api anahtar', 'eğitim klasör', 'yardım', 'nasıl çalış', 'ayarlar'])) {
      return OfficeIntent.help;
    }
    return OfficeIntent.chat;
  }

  String _teamOf(OfficeIntent intent) {
    switch (intent) {
      case OfficeIntent.code:
        return 'development';
      case OfficeIntent.video:
      case OfficeIntent.content:
        return 'content';
      case OfficeIntent.research:
        return 'research';
      case OfficeIntent.security:
      case OfficeIntent.help:
      case OfficeIntent.chat:
      case OfficeIntent.learn:
        return 'support';
    }
  }

  List<_Step> _stepsFor(OfficeIntent intent) {
    switch (intent) {
      case OfficeIntent.research:
        return const <_Step>[
          _Step('researcher', 'Bilgi topluyor', 'Konuyla ilgili bildiklerini ve bilmediklerini ayır; kaynak veya rakam uydurma. Maddeler halinde bulguları yaz.'),
          _Step('analyst', 'Bulguları analiz ediyor', 'Önceki bulguları karşılaştır, net bir sonuç ve öneri çıkar. Emin olmadığın yerleri belirt.'),
        ];
      case OfficeIntent.security:
        return const <_Step>[
          _Step('security', 'Güvenlik inceliyor', 'Verilen bilgi veya koddaki olası güvenlik açıklarını bul, her biri için düzeltme öner. Emin olmadığını söyle.'),
        ];
      case OfficeIntent.learn:
        return const <_Step>[
          _Step('trainer', 'Ders hazırlıyor', 'Kullanıcının seviyesini bilmiyorsan önce 2-3 kısa soruyla sor, sonra seviyesine uygun, adım adım bir ders ver. Önceki derslerden devam et.'),
        ];
      case OfficeIntent.help:
        return const <_Step>[
          _Step('support', 'Yardım hazırlıyor', 'Kullanıcının sorusunu kısa ve uygulanabilir adımlarla yanıtla.'),
        ];
      case OfficeIntent.chat:
      case OfficeIntent.code:
      case OfficeIntent.video:
      case OfficeIntent.content:
        return const <_Step>[
          _Step('support', 'Cevap hazırlıyor', 'Kullanıcının isteğini doğrudan ve eksiksiz yanıtla.'),
        ];
    }
  }

  /// Kullanıcının isteğini işler ve sonucu Dinleyici adına döndürür.
  Future<OfficeReply> handle(
    String text, {
    List<OfficeAttachment> attachments = const <OfficeAttachment>[],
    String history = '',
    void Function(String status)? onStatus,
  }) async {
    final request = text.trim();
    final intent = classify(request);
    final team = _teamOf(intent);
    final opId = hub.startOp(title: clipText(request, 48), team: team, agent: 'listener', step: 'Komut alındı');

    void status(String message, {double? progress, String? agent}) {
      hub.updateOp(opId, progress: progress, step: message, agent: agent);
      onStatus?.call(message);
    }

    try {
      hub.setAgent('listener', '');
      status('Dinleyici komutu CEO\'ya iletti', progress: 0.05, agent: 'ceo');

      // 1) Eğitim klasörü her zaman ilk bakılacak yerdir.
      final entries = await _safeEntries();
      if (intent == OfficeIntent.chat || intent == OfficeIntent.help || intent == OfficeIntent.research) {
        final stored = _storedAnswer(request, entries);
        if (stored != null) {
          hub.finishOp(opId, ok: true, message: 'Eğitim klasöründen cevaplandı');
          hub.log('Eğitim klasöründen cevaplandı (yapay zekâ harcanmadı).', level: 'ok');
          return OfficeReply(text: stored, agent: 'Arşiv Uzmanı', fromArchive: true);
        }
      }

      // 2) Çevrimdışı teknik destek bilgisi.
      if (intent == OfficeIntent.help) {
        final answer = support.answer(request);
        if (answer != null) {
          hub.finishOp(opId, ok: true, message: 'Teknik Destek cevapladı');
          return OfficeReply(text: answer, agent: 'Teknik Destek');
        }
      }

      // 3) Uzun üretim işleri kendi hatlarına gider.
      final runner = intent == OfficeIntent.code
          ? codeRunner
          : intent == OfficeIntent.video
              ? videoRunner
              : intent == OfficeIntent.content
                  ? contentRunner
                  : null;
      if (runner != null) {
        status('CEO işi ${teamLabel(team)}\'ne verdi', progress: 0.15, agent: 'ceo');
        final reply = await runner(request, (message) => status(message));
        hub.finishOp(opId, ok: reply.ok, message: reply.ok ? 'Tamamlandı' : 'Tamamlanamadı');
        return reply;
      }

      // 4) Yapay zekâ gerektiren ekip çalışması.
      if (providers.callable.isEmpty) {
        final offline = support.answer(request);
        if (offline != null) {
          hub.finishOp(opId, ok: true, message: 'Teknik Destek cevapladı');
          return OfficeReply(text: offline, agent: 'Teknik Destek');
        }
        hub.finishOp(opId, ok: false, message: 'Yapay zekâ bağlı değil');
        return const OfficeReply(
          text: ProviderRouterGateway.noProviderMessage,
          agent: 'CIO',
          ok: false,
        );
      }
      final promptHistory = (_smallModel && history.length > 1200) ? history.substring(history.length - 1200) : history;
      return await _runTeam(
        opId: opId,
        request: request,
        intent: intent,
        attachments: attachments,
        history: promptHistory,
        entries: entries,
        status: status,
      );
    } catch (error) {
      hub.finishOp(opId, ok: false, message: 'Beklenmeyen hata');
      return OfficeReply(text: 'Beklenmeyen hata: $error', agent: 'CIO', ok: false);
    }
  }

  Future<List<WorkArchiveEntry>> _safeEntries() async {
    try {
      return await archive.search('');
    } catch (_) {
      return const <WorkArchiveEntry>[];
    }
  }

  static const String _answerMarker = '\nCevap: ';

  /// Aynı soru daha önce cevaplandıysa saklanan cevabı döndürür.
  String? _storedAnswer(String request, List<WorkArchiveEntry> entries) {
    final asked = ArchiveSimilarity.stems(request);
    if (asked.length < 2) return null;
    for (final entry in entries) {
      if (!entry.tags.contains('cevap')) continue;
      final cut = entry.summary.indexOf(_answerMarker);
      if (cut < 0) continue;
      final question = entry.summary.substring(0, cut);
      final stored = ArchiveSimilarity.stems(question);
      if (stored.isEmpty) continue;
      final shared = asked.where(stored.contains).length;
      final union = asked.length + stored.length - shared;
      if (shared >= 2 && shared / union >= 0.75) {
        final answer = entry.summary.substring(cut + _answerMarker.length).trim();
        if (answer.length > 20) {
          return '$answer\n\n— Eğitim klasöründen (${entry.title.split(' — ').first}); yapay zekâ harcanmadı. Yeniden üretmek için isteği biraz değiştirin.';
        }
      }
    }
    return null;
  }

  String _reference(String request, List<WorkArchiveEntry> entries, {String tag = ''}) {
    final pool = tag.isEmpty ? entries : entries.where((e) => e.tags.contains(tag)).toList();
    final ranked = similarity.rank(request, pool, limit: 1);
    if (ranked.isEmpty) return '';
    hub.log('Eğitim klasöründen referans kullanıldı: ${clipText(ranked.first.entry.title, 40)}', level: 'info');
    return clipText(ranked.first.entry.summary, 700);
  }

  String _attachmentText(List<OfficeAttachment> attachments) {
    if (attachments.isEmpty) return '';
    final b = StringBuffer('EKLİ DOSYALAR:\n');
    for (final a in attachments) {
      if (a.isImage) {
        b.writeln('--- ${a.name} --- (görsel eklendi; görsel çözümleme yapılamıyor)');
      } else if (a.text.isNotEmpty) {
        b.writeln('--- ${a.name} ---');
        b.writeln(a.text.length > 4000 ? a.text.substring(0, 4000) : a.text);
      } else {
        b.writeln('--- ${a.name} --- (içerik okunamadı)');
      }
    }
    return b.toString();
  }

  String _prompt({
    required OfficeAgent agent,
    required _Step step,
    required String request,
    required String attachments,
    required String reference,
    required String board,
    required String history,
    String feedback = '',
  }) {
    final b = StringBuffer()
      ..writeln(agent.persona)
      ..writeln(officeRules)
      ..writeln()
      ..writeln('GÖREVİN: ${step.instruction}');
    if (reference.isNotEmpty) {
      b
        ..writeln()
        ..writeln('EĞİTİM KLASÖRÜNDEN BENZER ÇALIŞMA (gerekirse referans al):')
        ..writeln(reference);
    }
    if (history.isNotEmpty) {
      b
        ..writeln()
        ..writeln('ÖNCEKİ KONUŞMA:')
        ..writeln(history);
    }
    if (attachments.isNotEmpty) {
      b
        ..writeln()
        ..writeln(attachments);
    }
    if (board.isNotEmpty) {
      b
        ..writeln()
        ..writeln('EKİP PANOSU (diğer ekip üyelerinin çıktısı):')
        ..writeln(board);
    }
    if (feedback.isNotEmpty) {
      b
        ..writeln()
        ..writeln('CEO GERİ BİLDİRİMİ (bunları düzelt):')
        ..writeln(feedback);
    }
    b
      ..writeln()
      ..writeln('KULLANICI İSTEĞİ:')
      ..write(request);
    return b.toString();
  }

  Future<AresResult<AiResponse>> _ask(String instruction, String agentId) {
    final agent = agentById(agentId);
    final preferred = agent == null ? null : providers.teamProvider[agent.team];
    return router.generateFor(AiRequest(instruction: instruction, costClass: AiCostClass.free), preferredId: preferred);
  }

  Future<OfficeReply> _runTeam({
    required String opId,
    required String request,
    required OfficeIntent intent,
    required List<OfficeAttachment> attachments,
    required String history,
    required List<WorkArchiveEntry> entries,
    required void Function(String message, {double? progress, String? agent}) status,
  }) async {
    final steps = _stepsFor(intent);
    final attachmentText = _attachmentText(attachments);
    final reference = _reference(request, entries, tag: intent == OfficeIntent.learn ? 'ders' : '');
    final logs = <String>[];
    final agentNames = <String>[];
    var board = '';
    var lastOutput = '';

    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      final agent = agentById(step.agentId);
      if (agent == null) continue;
      agentNames.add(agent.name);
      status('${agent.name}: ${step.label}', progress: 0.2 + 0.5 * (i / steps.length), agent: agent.id);
      final result = await _ask(
        _prompt(
          agent: agent,
          step: step,
          request: request,
          attachments: attachmentText,
          reference: reference,
          board: board,
          history: history,
        ),
        agent.id,
      );
      hub.setAgent(agent.id, '');
      if (result is AresFailure<AiResponse>) {
        logs.add('Hata: ${agent.name}: ${result.message}');
        return _fail(opId, request, <String>[result.message], logs, 0);
      }
      if (result is AresSuccess<AiResponse>) {
        lastOutput = result.value.text.trim();
        board = '$board\n[${agent.name}]\n${_clip(lastOutput, _smallModel ? 1200 : 2500)}\n';
      }
    }

    // CEO incelemesi yalnızca çok adımlı işlerde (araştırma, güvenlik) yapılır.
    final reviewed = (intent == OfficeIntent.research || intent == OfficeIntent.security) && !_smallModel;
    var returns = 0;
    var ceoApproved = false;
    if (reviewed) {
      final lastStep = steps.last;
      final lastAgent = agentById(lastStep.agentId);
      while (true) {
        status('CEO sonucu inceliyor', progress: 0.8, agent: 'ceo');
        final feedback = await _review(request, lastOutput);
        hub.setAgent('ceo', '');
        if (feedback == null) {
          ceoApproved = true;
          break;
        }
        if (returns >= maxReturns || lastAgent == null) {
          logs.add('CEO geri gönderme (self-healing) sınırına ulaşıldı: $returns/$maxReturns');
          return _fail(opId, request, <String>['CEO sonucu onaylamadı: ${_clip(feedback, 200)}'], logs, returns, partial: lastOutput);
        }
        returns += 1;
        logs.add('CEO geri gönderme (self-healing) $returns/$maxReturns: ${_clip(feedback, 120)}');
        status('CEO eksik buldu, ${lastAgent.name} düzeltiyor ($returns/$maxReturns)', progress: 0.8, agent: lastAgent.id);
        final retry = await _ask(
          _prompt(
            agent: lastAgent,
            step: lastStep,
            request: request,
            attachments: attachmentText,
            reference: reference,
            board: board,
            history: history,
            feedback: feedback,
          ),
          lastAgent.id,
        );
        hub.setAgent(lastAgent.id, '');
        if (retry is AresFailure<AiResponse>) {
          logs.add('Hata: ${lastAgent.name}: ${retry.message}');
          return _fail(opId, request, <String>[retry.message], logs, returns, partial: lastOutput);
        }
        if (retry is AresSuccess<AiResponse>) {
          lastOutput = retry.value.text.trim();
          board = '$board\n[${lastAgent.name} - düzeltme $returns]\n${_clip(lastOutput, 2500)}\n';
        }
      }
    }

    final footer = StringBuffer('\n\n— Ekip: ${agentNames.join(' → ')}');
    if (reviewed && ceoApproved) {
      footer.write(returns == 0 ? ' • CEO onayladı' : ' • CEO $returns düzeltmeden sonra onayladı');
    }
    if (router.lastProviderName.isNotEmpty) footer.write(' • AI: ${router.lastProviderName}');

    await _remember(request, lastOutput, intent);
    hub.finishOp(opId, ok: true, message: 'Tamamlandı');
    return OfficeReply(
      text: '$lastOutput${footer.toString()}',
      agent: reviewed ? 'CEO' : (agentNames.isEmpty ? 'Dinleyici' : agentNames.last),
    );
  }

  /// CEO incelemesi. Sonuç tamamsa null, değilse geri bildirim metni döner.
  Future<String?> _review(String request, String output) async {
    final prompt = StringBuffer()
      ..writeln('Sen CEO\'sun. $officeRules')
      ..writeln()
      ..writeln('KULLANICI İSTEĞİ:')
      ..writeln(_clip(request, 600))
      ..writeln()
      ..writeln('EKİBİN SONUCU:')
      ..writeln(_clip(output, 2500))
      ..writeln()
      ..writeln('Sonuç isteği tam karşılıyor mu? Eksik, hatalı veya uydurma görünen yer var mı? '
          'Sorun yoksa SADECE "TAMAM" yaz. Sorun varsa "EKSİK:" ile başlayıp en fazla 3 kısa madde yaz.');
    final result = await _ask(prompt.toString(), 'ceo');
    if (result is AresSuccess<AiResponse>) {
      final reply = result.value.text.trim();
      if (_normalize(reply).startsWith('tamam')) return null;
      return reply;
    }
    // İnceleme yapılamazsa işi bloklamayız.
    hub.log('CEO incelemesi yapılamadı; sonuç incelemesiz iletildi.', level: 'warn');
    return null;
  }

  OfficeReply _fail(String opId, String request, List<String> errors, List<String> logs, int returns, {String partial = ''}) {
    hub.finishOp(opId, ok: false, message: 'Tamamlanamadı');
    final report = _ceo.buildFailureReport(
      request: request,
      errors: errors,
      logs: logs,
      retryCount: 0,
      selfHealingCount: returns,
      maxSelfHealing: maxReturns,
    );
    final b = StringBuffer('İşi tamamlayamadım. Ayrıntılı rapor aşağıdadır.');
    if (partial.isNotEmpty) {
      b
        ..writeln()
        ..writeln()
        ..writeln('Ekibin son (onaylanmamış) çıktısı:')
        ..write(_clip(partial, 1500));
    }
    return OfficeReply(text: b.toString(), agent: 'CEO', ok: false, report: report);
  }

  Future<void> _remember(String request, String answer, OfficeIntent intent) async {
    try {
      if (answer.length < 40) return;
      final now = DateTime.now();
      final topic = clipText(scrubber.scrub(request), 40);
      final tags = intent == OfficeIntent.learn ? <String>['cevap', 'ders', 'eğitim'] : <String>['cevap', intent.name];
      await archive.save(
        WorkArchiveEntry(
          id: AresId('qa_${now.microsecondsSinceEpoch}'),
          title: '${formatTrDate(now)} — $topic',
          summary: scrubber.scrub('Soru: ${clipText(request, 240)}$_answerMarker${_clip(answer, 3000)}'),
          completedAt: now,
          tags: tags,
        ),
      );
      hub.log('Eğitim klasörüne kaydedildi: $topic', level: 'ok');
    } catch (_) {
      // Arşiv yazılamazsa cevap yine de kullanıcıya iletilir.
    }
  }

  String _clip(String value, int max) => value.length <= max ? value : value.substring(0, max);
}
