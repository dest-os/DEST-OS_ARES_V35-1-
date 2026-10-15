import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/ares_app.dart';
import 'application/archive/archive_recorder.dart';
import 'application/codegen/code_generation_orchestrator.dart';
import 'application/codegen/code_generation_request_service.dart';
import 'application/codegen/code_validator_service.dart';
import 'application/codegen/code_writer_service.dart';
import 'application/codegen/project_scaffold_service.dart';
import 'application/codegen/prompt_builder_service.dart';
import 'application/content/content_generation_orchestrator.dart';
import 'application/content/content_request_service.dart';
import 'application/office/approval_actions.dart';
import 'application/office/approval_store.dart';
import 'application/office/chat_history_store.dart';
import 'application/office/cio_service.dart';
import 'application/office/notes_store.dart';
import 'application/office/office_hub.dart';
import 'application/office/office_service.dart';
import 'application/office/provider_store.dart';
import 'application/office/security_audit_service.dart';
import 'application/radar/model_radar_service.dart';
import 'application/runtime/production/production_composition_root.dart';
import 'core/security/cost_policy.dart';
import 'domain/content/content_mode.dart';
import 'infrastructure/ai/local_model_service.dart';
import 'infrastructure/ai/local_model_config.dart';
import 'infrastructure/ai/local_model_downloader.dart';
import 'infrastructure/ai/local_model_storage.dart';
import 'infrastructure/archive/file_work_archive_repository.dart';
import 'infrastructure/codegen/file_system_writer.dart';
import 'infrastructure/codegen/llm_code_generator.dart';
import 'infrastructure/codegen/provider_router_gateway.dart';
import 'infrastructure/radar/dartio_model_list_fetcher.dart';
import 'infrastructure/storage/json_file_store.dart';
import 'presentation/chat/chat_screen.dart';
import 'presentation/cio/cio_report_screen.dart';
import 'presentation/codegen/code_generation_screen.dart';
import 'presentation/content/content_generation_screen.dart';
import 'presentation/home/production_center_screen.dart';
import 'presentation/learning/learning_screen.dart';
import 'presentation/settings/ares_settings_center.dart';

/// Uygulamaya geri dönülünce tam ekran modunu yeniden uygular.
class _ImmersiveKeeper with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
      );
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  WidgetsBinding.instance.addObserver(_ImmersiveKeeper());

  await SystemChrome.setPreferredOrientations(
    const <DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
  );

  final jsonStore = JsonFileStore();
  final hub = OfficeHub();
  final providers = ProviderStore(store: jsonStore);
  final approvals = ApprovalStore(store: jsonStore);
  final history = ChatHistoryStore(store: jsonStore);
  final notes = NotesStore(store: jsonStore);

  await providers.load();
  await approvals.load();
  await history.load();
  await notes.load();

  // Gömülü yerel AI servisleri aynı örnekler üzerinden paylaşılır.
  final localModelService = LocalModelService();
  final localModelDownloader = LocalModelDownloader();

  final router = ProviderRouterGateway(
    providers: providers,
    approvals: approvals,
    hub: hub,
    localModelService: localModelService,
  );

  final archive = FileWorkArchiveRepository(jsonStore);
  final recorder = ArchiveRecorder(archive);
  const security = SecurityAuditService();

  final codeOrchestrator = CodeGenerationOrchestrator(
    scaffoldService: const ProjectScaffoldService(),
    promptBuilder: const PromptBuilderService(),
    llmCodeGenerator: ApiLlmCodeGenerator(gateway: router),
    codeWriter: CodeWriterService(
      writer: FileSystemWriter(),
    ),
    validator: const CodeValidatorService(),
    aiCostClass: AiCostClass.local,
  );

  final contentOrchestrator = ContentGenerationOrchestrator(
    gateway: router,
    writer: CodeWriterService(
      writer: FileSystemWriter(),
    ),
    costClass: AiCostClass.local,
  );

  final compositionRoot = ProductionCompositionRoot(
    codeGenerationOrchestrator: codeOrchestrator,
    contentGenerationOrchestrator: contentOrchestrator,
  );

  final CodeGenerationRequestService codeService =
      compositionRoot.buildCodeGenerationRequestService();

  final ContentRequestService contentService =
      compositionRoot.buildContentRequestService();

  Future<OfficeReply> codeRunner(
    String request,
    void Function(String status) onStatus,
  ) async {
    final result = await codeService.generate(
      request,
      onProgress: onStatus,
    );

    await recorder.recordCodeGeneration(
      request: request,
      result: result,
    );

    if (!result.success) {
      final report = result.metrics['ceoReport'];

      return OfficeReply(
        text: 'Mobil uygulama üretimi tamamlanamadı.',
        agent: 'CEO',
        ok: false,
        report: report is String ? report : null,
      );
    }

    onStatus('Güvenlik ajanı kodu tarıyor');
    hub.setAgent('security', 'Üretilen kodu tarıyor');

    final findings = security.scanArtifacts(result.artifacts);

    hub.setAgent('security', '');

    if (findings.any(
      (f) => f.level == 'error' || f.level == 'warn',
    )) {
      hub.notify(
        'Üretilen kodda ${findings.length} güvenlik bulgusu var.',
        level: 'warn',
      );
    }

    final paths = result.artifacts
        .map((a) => a.relativePath)
        .take(12)
        .join('\n- ');

    return OfficeReply(
      text: 'Mobil uygulama iskeleti üretildi: '
          '${result.artifacts.length} dosya (her özellik ayrı dosya).\n'
          '- $paths\n\n${security.summarize(findings)}',
      agent: 'Geliştirme Ekibi',
    );
  }

  Future<OfficeReply> contentRunner(
    ContentMode mode,
    String request,
    void Function(String status) onStatus,
    String platform,
    String contentType,
  ) async {
    final result = await contentService.generate(
      mode: mode,
      request: request,
      duration: '60 saniye',
      style: 'modern, temiz ve ARES uyumlu',
      platform: platform,
      contentType: contentType,
      onProgress: onStatus,
    );

    await recorder.recordContent(
      modeLabel: mode.label,
      request: request,
      success: result.success,
      artifactCount: result.artifacts.length,
      errors: result.errors,
    );

    if (!result.success) {
      return OfficeReply(
        text: 'İçerik üretimi tamamlanamadı:\n'
            '- ${result.errors.take(3).join('\n- ')}',
        agent: 'CEO',
        ok: false,
      );
    }

    final paths = result.artifacts
        .map((a) => a.relativePath)
        .take(12)
        .join('\n- ');

    return OfficeReply(
      text: 'İçerik üretildi: '
          '${result.artifacts.length} dosya.\n- $paths',
      agent: 'İçerik Ekibi',
    );
  }

  final office = OfficeService(
    router: router,
    hub: hub,
    archive: archive,
    providers: providers,
    codeRunner: codeRunner,
    videoRunner: (request, onStatus) => contentRunner(
      ContentMode.video,
      request,
      onStatus,
      'YouTube Shorts',
      'video',
    ),
    contentRunner: (request, onStatus) => contentRunner(
      ContentMode.general,
      request,
      onStatus,
      'genel',
      'doküman',
    ),
  );

  final radar = ModelRadarService(
    store: jsonStore,
    providers: providers,
    approvals: approvals,
    fetcher: const DartIoModelListFetcher(),
    hub: hub,
  );

  final cio = CioService(
    hub: hub,
    providers: providers,
    approvals: approvals,
    archive: archive,
    store: jsonStore,
  );

  final actions = ApprovalActions(
    approvals: approvals,
    providers: providers,
    hub: hub,
  );

  void open(BuildContext context, WidgetBuilder builder) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: builder),
    );
  }

  Widget mobileScreen() => CodeGenerationScreen(
        onGenerate: (request, {onProgress}) async {
          final result = await codeService.generate(
            request,
            onProgress: onProgress,
          );

          await recorder.recordCodeGeneration(
            request: request,
            result: result,
          );

          return result;
        },
      );

  Widget videoScreen() => ContentGenerationScreen(
        mode: ContentMode.video,
        onGenerate: ({
          required mode,
          required request,
          duration = '60 saniye',
          style = 'modern',
          platform = 'YouTube Shorts',
          contentType = 'video',
          onProgress,
        }) async {
          return contentService.generate(
            mode: mode,
            request: request,
            duration: duration,
            style: style,
            platform: platform,
            contentType: contentType,
            onProgress: onProgress,
          );
        },
      );

  Widget contentScreen() => ContentGenerationScreen(
        mode: ContentMode.general,
        onGenerate: ({
          required mode,
          required request,
          duration = '60 saniye',
          style = 'modern',
          platform = 'genel',
          contentType = 'doküman',
          onProgress,
        }) async {
          return contentService.generate(
            mode: mode,
            request: request,
            duration: duration,
            style: style,
            platform: platform,
            contentType: contentType,
            onProgress: onProgress,
          );
        },
      );

  Widget settingsRoute(
    BuildContext context, {
    String? section,
  }) =>
      AresSettingsCenter(
        providers: providers,
        approvals: approvals,
        actions: actions,
        router: router,
        radar: radar,
        cio: cio,
        localModelService: localModelService,
        localModelDownloader: localModelDownloader,
        initialSection: section,
      );

  Widget learningRoute(BuildContext context) =>
      LearningScreen(archive: archive);

  Widget chatRoute(
    BuildContext context, {
    String? draft,
    String? section,
  }) =>
      AresChatScreen(
        office: office,
        hub: hub,
        history: history,
        notes: notes,
        initialDraft: draft,
        initialSection: section,
        onOpenSettings: () => open(
          context,
          (_) => settingsRoute(context),
        ),
        onOpenArchive: () => open(context, learningRoute),
        onOpenMobile: () => open(context, (_) => mobileScreen()),
        onOpenVideo: () => open(context, (_) => videoScreen()),
        onOpenContent: () => open(context, (_) => contentScreen()),
      );

  runApp(
    AresApp(
      hub: hub,
      approvals: approvals,
      chatBuilder: chatRoute,
      settingsBuilder: settingsRoute,
      learningBuilder: learningRoute,
      cioReportBuilder: (context) => CioReportScreen(
        cio: cio,
        hub: hub,
      ),
      productionBuilder: (context) => ProductionCenterScreen(
        onOpenMobile: () => open(context, (_) => mobileScreen()),
        onOpenVideo: () => open(context, (_) => videoScreen()),
        onOpenContent: () => open(context, (_) => contentScreen()),
      ),
    ),
  );

  cio.start();

  // Yerel yapay zekâ: model cihazdaysa açılışta arka planda belleğe yüklenir.
  Future<void>(() async {
    try {
      if (!await LocalModelStorage().isModelAvailable()) {
        hub.notify(
          'Yerel yapay zekâ modeli indirilmedi. Ayarlar > Genel AI Ayarları bölümünde "İndir ve yükle" düğmesine basın (≈430 MB).',
          level: 'warn',
        );
        return;
      }
      hub.setAgent('cio', 'Yerel yapay zekâ yükleniyor');
      final ok = await localModelService.ensureLoaded();
      hub.setAgent('cio', '');
      hub.notify(
        ok
            ? 'Yerel yapay zekâ hazır: ${LocalModelConfig.fileName}'
            : 'Yerel yapay zekâ yüklenemedi: ${localModelService.lastError}',
        level: ok ? 'ok' : 'error',
      );
    } catch (error) {
      hub.setAgent('cio', '');
      hub.notify('Yerel yapay zekâ başlatılamadı: $error', level: 'error');
    }
  });

  Future<void>(() async {
    try {
      await radar.scan();
    } catch (_) {
      // Radar hatası uygulamayı etkilemesin.
    }
  });
}
