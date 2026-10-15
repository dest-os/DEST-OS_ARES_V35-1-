import 'package:flutter/material.dart';

import '../../application/office/chat_history_store.dart';
import '../../application/office/notes_store.dart';
import '../../application/office/office_agents.dart';
import '../../application/office/office_hub.dart';
import '../../application/office/office_service.dart';
import '../../core/format/tr_date.dart';
import '../../core/ui/image_stage.dart';

/// ARES Sohbet (Dinleyici masası).
///
/// Tasarım PNG'si olduğu gibi kalır; dokunma alanları ve canlı içerik görsele
/// göre hizalı katmanlardır. Mesaj yazılınca komut Dinleyici → CEO → ekipler
/// hattından geçer ve sonuç burada görünür.
class AresChatScreen extends StatefulWidget {
  const AresChatScreen({
    super.key,
    required this.office,
    required this.hub,
    required this.history,
    required this.notes,
    this.initialDraft,
    this.initialSection,
    this.onOpenSettings,
    this.onOpenMobile,
    this.onOpenVideo,
    this.onOpenContent,
    this.onOpenArchive,
  });

  final OfficeService office;
  final OfficeHub hub;
  final ChatHistoryStore history;
  final NotesStore notes;

  /// Yazı kutusuna önceden konacak metin.
  final String? initialDraft;

  /// history, tasks, files, vision, notes, archive
  final String? initialSection;

  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenMobile;
  final VoidCallback? onOpenVideo;
  final VoidCallback? onOpenContent;
  final VoidCallback? onOpenArchive;

  @override
  State<AresChatScreen> createState() => _AresChatScreenState();
}

class _AresChatScreenState extends State<AresChatScreen> {
  static const String _asset = 'assets/images/ares_sohbet_ekrani.png';
  static const Size _imageSize = Size(1482, 1061);

  final TextEditingController _controller = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();
  final List<OfficeAttachment> _attachments = <OfficeAttachment>[];

  late ChatConversation _conv;
  String? _section;
  bool _busy = false;

  // Koordinatlar 1291x924 referans uzayında ölçüldü (görselin ölçekli görünümü).
  static StageRect _r(double x1, double y1, double x2, double y2) {
    return StageRect.px(x1, y1, x2, y2, refWidth: 1291, refHeight: 924);
  }

  List<ChatMessageData> get _messages => _conv.messages;

  ChatConversation _blankConversation() {
    final now = DateTime.now();
    return ChatConversation(
      id: 'chat_${now.microsecondsSinceEpoch}',
      title: '',
      startedAt: now,
      messages: <ChatMessageData>[],
    );
  }

  @override
  void initState() {
    super.initState();
    _conv = _blankConversation();
    _section = widget.initialSection;
    final draft = widget.initialDraft;
    if (draft != null && draft.isNotEmpty) {
      _controller.text = draft;
      _controller.selection = TextSelection.collapsed(offset: draft.length);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_section == 'archive') {
        setState(() => _section = null);
        widget.onOpenArchive?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _noteController.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 4)));
  }

  String _historyText() {
    final usable = _messages.where((m) => !m.isError).toList();
    final recent = usable.length > 6 ? usable.sublist(usable.length - 6) : usable;
    final b = StringBuffer();
    for (final m in recent) {
      b.writeln('${m.fromUser ? 'Kullanıcı' : 'ARES'}: ${clipText(m.text, 500)}');
    }
    return b.toString().trim();
  }

  Future<void> _persist() async {
    if (_messages.isEmpty) return;
    final first = _messages.firstWhere((m) => m.fromUser, orElse: () => _messages.first);
    _conv.title = clipText(first.text, 40);
    try {
      await widget.history.save(_conv);
    } catch (_) {
      // Geçmiş yazılamazsa sohbet devam eder.
    }
  }

  Future<void> _newChat() async {
    await _persist();
    if (!mounted) return;
    setState(() {
      _conv = _blankConversation();
      _section = null;
      _attachments.clear();
      _controller.clear();
    });
  }

  void _openConversation(ChatConversation c) {
    setState(() {
      _conv = ChatConversation(
        id: c.id,
        title: c.title,
        startedAt: c.startedAt,
        messages: List<ChatMessageData>.from(c.messages),
      );
      _section = null;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    final files = List<OfficeAttachment>.from(_attachments);
    final historyText = _historyText();
    setState(() {
      _messages.add(ChatMessageData(text: text, fromUser: true));
      _controller.clear();
      _attachments.clear();
      _busy = true;
      _section = null;
    });
    _scrollToEnd();

    OfficeReply reply;
    try {
      reply = await widget.office.handle(text, attachments: files, history: historyText);
    } catch (error) {
      reply = OfficeReply(text: 'Beklenmeyen hata: $error', agent: 'CIO', ok: false);
    }
    if (!mounted) return;
    final report = reply.report;
    final full = report == null ? reply.text : '${reply.text}\n\n$report';
    setState(() {
      _messages.add(ChatMessageData(text: full, fromUser: false, isError: !reply.ok, agent: reply.agent));
      _busy = false;
    });
    _scrollToEnd();
    await _persist();
  }

  void _draft(String text) {
    setState(() => _section = null);
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _focus.requestFocus();
  }

  Future<void> _pasteDocument() async {
    final nameController = TextEditingController();
    final textController = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Belge metni ekle'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Belge adı (isteğe bağlı)')),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(labelText: 'Belge metnini buraya yapıştırın', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Ekle')),
        ],
      ),
    );
    final text = textController.text.trim();
    final name = nameController.text.trim();
    nameController.dispose();
    textController.dispose();
    if (added != true || text.isEmpty || !mounted) return;
    setState(() {
      _attachments.add(OfficeAttachment(name: name.isEmpty ? 'Belge ${_attachments.length + 1}' : name, path: '', text: text));
    });
    _notice('Belge eklendi; bir sonraki mesajınızla birlikte ekibe iletilecek.');
  }

  void _plusMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF08131D),
      builder: (ctx) {
        Widget tile(IconData icon, String title, VoidCallback? action) {
          return ListTile(
            leading: Icon(icon, color: Colors.cyanAccent),
            title: Text(title, style: const TextStyle(color: Colors.white)),
            enabled: action != null,
            onTap: action == null
                ? null
                : () {
                    Navigator.of(ctx).pop();
                    action();
                  },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(Icons.add_comment_outlined, 'Yeni sohbet', _newChat),
              tile(Icons.description_outlined, 'Belge metni ekle', _pasteDocument),
              tile(Icons.sticky_note_2_outlined, 'Notlar', () => setState(() => _section = 'notes')),
              tile(Icons.phone_android, 'Mobil uygulama üret (Üretim Merkezi)', widget.onOpenMobile),
              tile(Icons.movie_creation_outlined, 'Video içerik üret', widget.onOpenVideo),
              tile(Icons.article_outlined, 'Genel içerik üret', widget.onOpenContent),
            ],
          ),
        );
      },
    );
  }

  // —— Merkez panel içerikleri ——

  Widget _title(BuildContext ctx, String text) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: const Color(0xFF68DEFC), fontWeight: FontWeight.bold, fontSize: StageScope.font(ctx, 26)),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _section = null),
          child: Text('Sohbete dön', style: TextStyle(fontSize: StageScope.font(ctx, 18))),
        ),
      ],
    );
  }

  Widget _hint(BuildContext ctx, String text) {
    return Text(text, style: TextStyle(color: const Color(0xFF8FA9BF), height: 1.4, fontSize: StageScope.font(ctx, 19)));
  }

  Widget _bubble(BuildContext ctx, ChatMessageData m) {
    final fs = StageScope.font(ctx, 20);
    final color = m.isError
        ? const Color(0xFF3A1F1A)
        : m.fromUser
            ? const Color(0xFF0E3050)
            : const Color(0xFF0A1B2B);
    return Align(
      alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF123A57))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!m.fromUser && m.agent.isNotEmpty)
              Text(m.agent, style: TextStyle(color: const Color(0xFF68DEFC), fontSize: fs * 0.8, fontWeight: FontWeight.bold)),
            SelectableText(
              m.text,
              style: TextStyle(color: m.isError ? const Color(0xFFFFB27A) : Colors.white, height: 1.35, fontSize: fs),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messagesView(BuildContext ctx) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            itemCount: _messages.length,
            itemBuilder: (c, i) => _bubble(c, _messages[i]),
          ),
        ),
        if (_busy)
          AnimatedBuilder(
            animation: widget.hub,
            builder: (c, _) {
              final ops = widget.hub.activeOps;
              final step = ops.isEmpty ? 'Çalışıyor…' : ops.first.step;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: const Color(0xFF9FE8FF), fontSize: StageScope.font(c, 18)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _historyView(BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(ctx, 'Sohbet Geçmişi'),
        Expanded(
          child: AnimatedBuilder(
            animation: widget.history,
            builder: (c, _) {
              final items = widget.history.items;
              if (items.isEmpty) return Center(child: _hint(c, 'Henüz kayıtlı sohbet yok.'));
              return ListView(
                children: [
                  for (final item in items)
                    Card(
                      color: const Color(0xFF0A1B2B),
                      child: ListTile(
                        title: Text('${formatTrDate(item.startedAt)} — ${item.title}', style: TextStyle(color: Colors.white, fontSize: StageScope.font(c, 19))),
                        subtitle: Text('${item.messages.length} mesaj', style: const TextStyle(color: Colors.white54)),
                        onTap: () => _openConversation(item),
                        trailing: IconButton(
                          tooltip: 'Sil',
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => widget.history.delete(item.id),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _stateLabel(OpState state) {
    switch (state) {
      case OpState.queued:
        return 'Kuyrukta';
      case OpState.running:
        return 'Çalışıyor';
      case OpState.awaitingApproval:
        return 'Onay bekliyor';
      case OpState.done:
        return 'Tamamlandı';
      case OpState.failed:
        return 'Tamamlanamadı';
    }
  }

  Widget _tasksView(BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(ctx, 'Görevler'),
        Expanded(
          child: AnimatedBuilder(
            animation: widget.hub,
            builder: (c, _) {
              final ops = widget.hub.ops;
              if (ops.isEmpty) return Center(child: _hint(c, 'Henüz görev yok.'));
              final fs = StageScope.font(c, 19);
              return ListView(
                children: [
                  for (final op in ops)
                    Card(
                      color: const Color(0xFF0A1B2B),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(op.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: fs, fontWeight: FontWeight.bold))),
                                Text(_stateLabel(op.state), style: TextStyle(color: const Color(0xFF9FE8FF), fontSize: fs * 0.85)),
                                if (!op.active)
                                  IconButton(
                                    tooltip: 'Listeden kaldır',
                                    icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                                    onPressed: () => widget.hub.removeOp(op.id),
                                  ),
                              ],
                            ),
                            Text('${teamLabel(op.team)} • ${op.step}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white54, fontSize: fs * 0.8)),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(value: op.progress, minHeight: 5),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filesView(BuildContext ctx) {
    final fs = StageScope.font(ctx, 19);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(ctx, 'Dosyalar'),
        _hint(ctx, 'Dosya seçici (ataç) bu sürümde henüz yok. Belgenin metnini yapıştırarak ekleyebilirsiniz; metin bir sonraki mesajınızla birlikte ekibe iletilir.'),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(onPressed: _pasteDocument, icon: const Icon(Icons.note_add_outlined), label: const Text('Belge metni ekle')),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _attachments.isEmpty
              ? Center(child: _hint(ctx, 'Eklenmiş belge yok.'))
              : ListView(
                  children: [
                    for (var i = 0; i < _attachments.length; i++)
                      Card(
                        color: const Color(0xFF0A1B2B),
                        child: ListTile(
                          leading: const Icon(Icons.description_outlined, color: Colors.cyanAccent),
                          title: Text(_attachments[i].name, style: TextStyle(color: Colors.white, fontSize: fs)),
                          subtitle: Text(clipText(_attachments[i].text, 90), style: const TextStyle(color: Colors.white54)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, color: Colors.redAccent),
                            onPressed: () => setState(() => _attachments.removeAt(i)),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _visionView(BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(ctx, 'Görsel Analiz'),
        _hint(
          ctx,
          'Görsel çözümleme için görüntü destekli bir yapay zekâ modeli ve görselin modele gönderilmesi gerekir. '
          'Bu sürümde görsel gönderme desteği yok; bu yüzden görsel analiz yapılamıyor. '
          'Görseldeki metni kendiniz yazıp Dosyalar bölümünden belge olarak ekleyebilirsiniz.',
        ),
      ],
    );
  }

  Widget _notesView(BuildContext ctx) {
    final fs = StageScope.font(ctx, 19);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(ctx, 'Notlar'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _noteController,
                style: TextStyle(color: Colors.white, fontSize: fs),
                decoration: const InputDecoration(hintText: 'Yeni not yazın…', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                await widget.notes.add(_noteController.text);
                _noteController.clear();
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: AnimatedBuilder(
            animation: widget.notes,
            builder: (c, _) {
              final items = widget.notes.items;
              if (items.isEmpty) return Center(child: _hint(c, 'Henüz not yok.'));
              return ListView(
                children: [
                  for (final note in items)
                    Card(
                      color: const Color(0xFF0A1B2B),
                      child: ListTile(
                        title: Text(note.text, style: TextStyle(color: Colors.white, fontSize: fs)),
                        subtitle: Text(formatTrDate(note.createdAt), style: const TextStyle(color: Colors.white54)),
                        trailing: IconButton(
                          tooltip: 'Sil',
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => widget.notes.delete(note.id),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _centerPanel(BuildContext ctx) {
    Widget content;
    switch (_section) {
      case 'history':
        content = _historyView(ctx);
        break;
      case 'tasks':
        content = _tasksView(ctx);
        break;
      case 'files':
        content = _filesView(ctx);
        break;
      case 'vision':
        content = _visionView(ctx);
        break;
      case 'notes':
        content = _notesView(ctx);
        break;
      default:
        content = _messagesView(ctx);
        break;
    }
    return Container(
      color: const Color(0xFF00101F),
      padding: const EdgeInsets.all(12),
      child: content,
    );
  }

  Widget _rightPanel() {
    return AnimatedBuilder(
      animation: widget.hub,
      builder: (context, _) {
        final ops = widget.hub.ops.take(6).toList();
        return Builder(
          builder: (ctx) {
            final fs = StageScope.font(ctx, 18);
            if (ops.isEmpty) {
              return Container(
                color: const Color(0xFF010F1A),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description_outlined, size: StageScope.font(ctx, 54, min: 24), color: const Color(0xFF6C8AA3)),
                    const SizedBox(height: 8),
                    Text('Aktif görev yok', style: TextStyle(color: const Color(0xFF9DB4C8), fontSize: StageScope.font(ctx, 22))),
                  ],
                ),
              );
            }
            return Container(
              color: const Color(0xFF010F1A),
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  for (final op in ops)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(op.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: fs, fontWeight: FontWeight.bold))),
                              Text(
                                op.active ? '%${(op.progress * 100).round()}' : (op.state == OpState.done ? '✓' : '✗'),
                                style: TextStyle(color: op.state == OpState.failed ? const Color(0xFFFF5A5A) : const Color(0xFF68DEFC), fontSize: fs),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          LinearProgressIndicator(value: op.progress, minHeight: 5),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _inputField() {
    return Builder(
      builder: (ctx) {
        final fs = StageScope.font(ctx, 22);
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF071C2D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1B4E73)),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            minLines: 1,
            maxLines: 3,
            style: TextStyle(color: Colors.white, fontSize: fs),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: _attachments.isEmpty ? 'Mesajınızı buraya yazın...' : 'Mesajınız (${_attachments.length} belge ekli)...',
              hintStyle: TextStyle(color: const Color(0xFF8FA9BF), fontSize: fs),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showCenter = _messages.isNotEmpty || _section != null;
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    final layers = <StageLayer>[
      StageLayer(rect: _r(960, 203, 1250, 577), child: _rightPanel()),
    ];
    if (showCenter) {
      layers.add(StageLayer(rect: _r(300, 130, 933, 680), child: Builder(builder: _centerPanel)));
    }
    layers
      ..add(stageHit(rect: _r(35, 22, 100, 85), label: 'Ana ekran', onTap: () => Navigator.of(context).maybePop()))
      ..add(stageHit(rect: _r(1212, 28, 1262, 78), label: 'Kapat', onTap: () => Navigator.of(context).maybePop()))
      ..add(stageHit(rect: _r(37, 125, 283, 203), label: 'Yeni sohbet', onTap: _newChat))
      ..add(stageHit(rect: _r(37, 215, 283, 275), label: 'Sohbet geçmişi', onTap: () => setState(() => _section = 'history')))
      ..add(stageHit(rect: _r(37, 292, 283, 348), label: 'Görevler', onTap: () => setState(() => _section = 'tasks')))
      ..add(stageHit(rect: _r(37, 370, 283, 425), label: 'Dosyalar', onTap: () => setState(() => _section = 'files')))
      ..add(stageHit(rect: _r(37, 447, 283, 502), label: 'Görsel analiz', onTap: () => setState(() => _section = 'vision')))
      ..add(stageHit(rect: _r(37, 523, 283, 578), label: 'Notlar', onTap: () => setState(() => _section = 'notes')))
      ..add(stageHit(
        rect: _r(37, 600, 283, 655),
        label: 'Çalışma arşivi',
        onTap: () {
          final open = widget.onOpenArchive;
          if (open != null) {
            open();
          } else {
            _notice('Çalışma arşivi bağlı değil.');
          }
        },
      ));

    if (!showCenter) {
      layers
        ..add(stageHit(rect: _r(316, 475, 506, 543), label: 'Bir görev planla', onTap: () => _draft('Bir görev planla: ')))
        ..add(stageHit(rect: _r(520, 475, 737, 543), label: 'Bir belgeyi analiz et', onTap: () {
          setState(() => _section = 'files');
          _controller.text = 'Ekli belgeyi analiz et.';
        }))
        ..add(stageHit(rect: _r(750, 475, 927, 543), label: 'Araştırma yap', onTap: () => _draft('Şunu araştır: ')))
        ..add(stageHit(rect: _r(520, 560, 737, 628), label: 'Notlarımı düzenle', onTap: () => setState(() => _section = 'notes')));
    }

    layers
      ..add(StageLayer(rect: _r(548, 712, 1018, 800), child: _inputField()))
      ..add(stageHit(rect: _r(335, 712, 414, 799), label: 'Menü', onTap: _plusMenu))
      ..add(stageHit(rect: _r(439, 712, 517, 799), label: 'Belge ekle', onTap: _pasteDocument))
      ..add(stageHit(
        rect: _r(1056, 709, 1140, 803),
        label: 'Mikrofon',
        onTap: () => _notice(
          'Sesli komut bu sürümde yok. Klavyenizdeki mikrofon simgesine basarak konuşup yazdırabilirsiniz.',
        ),
      ))
      ..add(stageHit(rect: _r(1154, 709, 1238, 803), label: 'Gönder', onTap: _send));

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF05080D),
      body: ImageStage(
        asset: _asset,
        imageSize: _imageSize,
        keyboardInset: inset,
        keyboardAnchor: 802 / 924,
        layers: layers,
      ),
    );
  }
}
