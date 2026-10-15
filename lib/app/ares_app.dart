import 'package:flutter/material.dart';

import '../application/environment/environment_health_service.dart';
import '../application/office/approval_store.dart';
import '../application/office/office_hub.dart';
import '../domain/codegen/generation_result.dart';
import '../domain/content/content_generation_result.dart';
import '../domain/content/content_mode.dart';
import '../infrastructure/video/ffmpeg_command_runner.dart';
import '../presentation/home/ares_home_screen.dart';

/// Root Flutter application for DEST-OS ARES.
class AresApp extends StatelessWidget {
  /// Creates the application.
  const AresApp({
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

  /// Application-layer mobile generation facade.
  final Future<GenerationResult> Function(String request, {void Function(String status)? onProgress})? onCodeGenerate;

  /// Explicitly approved video render facade.
  final Future<VideoRenderResult> Function({required List<String> arguments, required String relativeOutputRoot})? onVideoRender;

  /// Optional dependency health facade.
  final EnvironmentHealthService? environmentHealthService;

  /// Ana ekran masaları: sohbet, ayarlar, arşiv, CIO raporu ve üretim merkezi.
  final ChatRouteBuilder? chatBuilder;
  final SettingsRouteBuilder? settingsBuilder;
  final WidgetBuilder? learningBuilder;
  final EnvironmentHealthService Function()? healthServiceFactory;
  final OfficeHub? hub;
  final ApprovalStore? approvals;
  final WidgetBuilder? cioReportBuilder;
  final WidgetBuilder? productionBuilder;

  /// Application-layer content generation facade.
  final Future<ContentGenerationResult> Function({
    required ContentMode mode,
    required String request,
    String duration,
    String style,
    String platform,
    String contentType,
    void Function(String status)? onProgress,
  })? onContentGenerate;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'DEST-OS ARES',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true, colorSchemeSeed: Colors.cyan),
        home: AresHomeScreen(
          onCodeGenerate: onCodeGenerate,
          onContentGenerate: onContentGenerate,
          environmentHealthService: environmentHealthService,
          onVideoRender: onVideoRender,
          chatBuilder: chatBuilder,
          settingsBuilder: settingsBuilder,
          learningBuilder: learningBuilder,
          healthServiceFactory: healthServiceFactory,
          hub: hub,
          approvals: approvals,
          cioReportBuilder: cioReportBuilder,
          productionBuilder: productionBuilder,
        ),
      );
}
