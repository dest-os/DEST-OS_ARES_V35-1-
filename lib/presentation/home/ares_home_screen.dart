import 'package:flutter/material.dart';

import '../../application/environment/environment_health_service.dart';
import '../../application/office/approval_store.dart';
import '../../application/office/office_hub.dart';
import '../../core/ui/image_stage.dart';
import '../../domain/codegen/generation_result.dart';
import '../../domain/content/content_generation_result.dart';
import '../../domain/content/content_mode.dart';
import '../../infrastructure/video/ffmpeg_command_runner.dart';
import 'live_panels.dart';

/// Sohbet ekranını açar. [draft]: yazı kutusuna önceden konacak metin,
/// [section]: history, tasks, files, vision, notes, archive.
typedef ChatRouteBuilder = Widget Function(BuildContext context, {String? draft, String? section});

/// Ayarlar ekranını açar. [section]: catalog, keys, order, usage, approvals, general, security, backup, info.
typedef SettingsRouteBuilder = Widget Function(BuildContext context, {String? section});

/// ARES tablet ana ekranı.
///
/// Tasarım PNG'si olduğu gibi kalır. Üstüne (1) görsele göre hizalı görünmez
/// dokunma alanları ve (2) CIO'nun beslediği canlı paneller konur.
class AresHomeScreen extends StatelessWidget {
  const AresHomeScreen({
    super.key,
    this.onCodeGenerate,
    this.onContentGenerate,
    this.environmentHealthService,
    this.onVideoRender,
    this.chatBuilder,
    this.settingsBuilder,
    this.learningBuilder,
    this.healthServiceFactory,
    this.hub,
    this.approvals,
    this.cioReportBuilder,
    this.productionBuilder,
  });

  final ChatRouteBuilder? chatBuilder;
  final SettingsRouteBuilder? settingsBuilder;
  final WidgetBuilder? learningBuilder;
  final EnvironmentHealthService Function()? healthServiceFactory;

  /// Canlı durumun kaynağı (CIO ve CEO buraya yazar).
  final OfficeHub? hub;
  final ApprovalStore? approvals;
  final WidgetBuilder? cioReportBuilder;
  final WidgetBuilder? productionBuilder;

  final Future<GenerationResult> Function(
    String request, {
    void Function(String status)? onProgress,
  })? onCodeGenerate;

  final Future<ContentGenerationResult> Function({
    required ContentMode mode,
    required String request,
    String duration,
    String style,
    String platform,
    String contentType,
    void Function(String status)? onProgress,
  })? onContentGenerate;

  final EnvironmentHealthService? environmentHealthService;

  final Future<VideoRenderResult> Function({
    required List<String> arguments,
    required String relativeOutputRoot,
  })? onVideoRender;

  static const String _asset = 'assets/images/ares_ana_ekran.png';
  static const Size _imageSize = Size(1536, 1024);

  // Koordinatlar 1344x896 referans uzayında ölçüldü (görselin ölçekli görünümü).
  static StageRect _r(double x1, double y1, double x2, double y2) {
    return StageRect.px(x1, y1, x2, y2, refWidth: 1344, refHeight: 896);
  }

  void _push(BuildContext context, WidgetBuilder builder) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  void _openChat(BuildContext context, {String? draft, String? section}) {
    final builder = chatBuilder;
    if (builder == null) {
      _toast(context, 'Dinleyici (sohbet) henüz bağlı değil.');
      return;
    }
    _push(context, (ctx) => builder(ctx, draft: draft, section: section));
  }

  void _openSettings(BuildContext context, {String? section}) {
    final builder = settingsBuilder;
    if (builder == null) {
      _toast(context, 'Ayarlar henüz bağlı değil.');
      return;
    }
    _push(context, (ctx) => builder(ctx, section: section));
  }

  void _openLearning(BuildContext context) {
    final builder = learningBuilder;
    if (builder == null) {
      _toast(context, 'Eğitim klasörü henüz bağlı değil.');
      return;
    }
    _push(context, builder);
  }

  void _openCio(BuildContext context) {
    final builder = cioReportBuilder;
    if (builder == null) {
      _toast(context, 'CIO raporu henüz bağlı değil.');
      return;
    }
    _push(context, builder);
  }

  void _openProduction(BuildContext context) {
    final builder = productionBuilder;
    if (builder == null) {
      _openChat(context, draft: 'Mobil uygulama yap: ');
      return;
    }
    _push(context, builder);
  }

  void _showCeoInfo(BuildContext context) {
    final working = hub?.activeOps.length ?? 0;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CEO'),
        content: Text(
          'Planlama, ekip kurma, iş dağıtımı, takip ve kontrol.\n\n'
          'Komut Dinleyici\'den CEO\'ya gelir; CEO konuya göre ekipleri seçer, işi parçalara böler ve sonucu kontrol eder. '
          'Eksik bulursa işi ekibe en fazla 3 kez geri gönderir; düzelmezse ayrıntılı rapor ve tavsiyeyle size iletir.\n\n'
          'Şu an çalışan iş: $working',
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Kapat'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveHub = hub;
    final liveApprovals = approvals;
    final layers = <StageLayer>[];

    // —— Canlı katmanlar (CIO ve CEO tarafından beslenir) ——
    if (liveHub != null && liveApprovals != null) {
      layers
        ..add(StageLayer(rect: _r(1084, 52, 1304, 76), child: LiveSubtitle(hub: liveHub)))
        ..add(StageLayer(
          rect: _r(1052, 88, 1328, 326),
          child: LiveOpsColumn(hub: liveHub, approvals: liveApprovals, onOpenApprovals: () => _openSettings(context, section: 'approvals')),
        ))
        ..add(StageLayer(rect: _r(1262, 344, 1328, 361), child: AgentCounter(hub: liveHub)))
        ..add(StageLayer(rect: _r(1054, 370, 1326, 522), child: AgentsList(hub: liveHub)))
        ..add(StageLayer(rect: _r(1054, 571, 1326, 698), child: NoteList(hub: liveHub, notifications: false)))
        ..add(StageLayer(rect: _r(1054, 749, 1326, 872), child: NoteList(hub: liveHub, notifications: true)))
        ..add(StageLayer(
          rect: _r(798, 778, 986, 854),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openCio(context),
            child: SystemStatusRows(hub: liveHub),
          ),
        ));
    }

    // —— Dokunma alanları (görsele göre hizalı) ——
    layers
      ..add(stageHit(rect: _r(15, 60, 305, 215), label: 'Dinleyici', onTap: () => _openChat(context)))
      ..add(stageHit(rect: _r(318, 100, 545, 232), label: 'CEO', onTap: () => _showCeoInfo(context)))
      ..add(stageHit(rect: _r(575, 100, 720, 230), label: 'Ayarlar', onTap: () => _openSettings(context)))
      ..add(stageHit(rect: _r(760, 60, 1015, 215), label: 'CIO', onTap: () => _openCio(context)))
      ..add(stageHit(rect: _r(65, 270, 217, 345), label: 'Araştırma Ekibi', onTap: () => _openChat(context, draft: 'Şunu araştır: ')))
      ..add(stageHit(rect: _r(268, 305, 447, 372), label: 'Geliştirme Ekibi', onTap: () => _openProduction(context)))
      ..add(stageHit(rect: _r(625, 305, 775, 362), label: 'İçerik Ekibi', onTap: () => _openProduction(context)))
      ..add(stageHit(rect: _r(820, 275, 982, 350), label: 'Destek Ekibi', onTap: () => _openCio(context)))
      ..add(stageHit(rect: _r(95, 415, 327, 705), label: 'Dinleyici masası', onTap: () => _openChat(context)))
      ..add(stageHit(rect: _r(440, 550, 600, 648), label: 'CEO masası: Ayarlar', onTap: () => _openSettings(context)))
      ..add(stageHit(rect: _r(710, 420, 905, 712), label: 'CIO masası', onTap: () => _openCio(context)))
      ..add(stageHit(rect: _r(95, 780, 225, 800), label: 'Yazılı komut', onTap: () => _openChat(context)))
      ..add(stageHit(rect: _r(95, 798, 225, 817), label: 'Sesli komut', onTap: () => _openChat(context)))
      ..add(stageHit(rect: _r(95, 816, 225, 835), label: 'Dosya yükleme', onTap: () => _openChat(context, section: 'files')))
      ..add(stageHit(rect: _r(95, 834, 225, 853), label: 'Sürekli dinleme', onTap: () => _openChat(context)))
      ..add(stageHit(rect: _r(366, 780, 428, 850), label: 'Planlar', onTap: () => _openChat(context, draft: 'Bir görev planla: ')))
      ..add(stageHit(rect: _r(430, 780, 488, 850), label: 'Veriler', onTap: () => _openLearning(context)))
      ..add(stageHit(rect: _r(490, 780, 548, 850), label: 'Görevler', onTap: () => _openChat(context, section: 'tasks')))
      ..add(stageHit(rect: _r(552, 780, 612, 850), label: 'Raporlar', onTap: () => _openCio(context)))
      ..add(stageHit(rect: _r(614, 780, 672, 850), label: 'Sonuçlar', onTap: () => _openLearning(context)));

    // Onay bekleyen sayısı rozeti (CEO gözünün köşesinde).
    if (liveApprovals != null) {
      layers.add(StageLayer(
        rect: _r(688, 102, 718, 132),
        child: ApprovalBadge(approvals: liveApprovals, onTap: () => _openSettings(context, section: 'approvals')),
      ));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF05080D),
      body: ImageStage(asset: _asset, imageSize: _imageSize, layers: layers),
    );
  }
}
