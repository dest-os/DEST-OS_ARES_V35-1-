import 'package:flutter/material.dart';

import '../../application/office/approval_store.dart';
import '../../application/office/office_agents.dart';
import '../../application/office/office_hub.dart';
import '../../core/ui/image_stage.dart';

/// Ana ekran PNG'sindeki panel iç renkleri (görselden örneklendi).
const Color kPanelFill = Color(0xFF000E1B);
const Color kPanelLine = Color(0xFF123A57);
const Color kTabOn = Color(0xFF00448A);
const Color kTabOff = Color(0xFF021524);

String hhmm(DateTime time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

Color levelColor(String level) {
  switch (level) {
    case 'ok':
      return const Color(0xFF3DDC84);
    case 'warn':
      return const Color(0xFFF1C40F);
    case 'error':
      return const Color(0xFFFF5A5A);
    default:
      return const Color(0xFF68DEFC);
  }
}

Widget _empty(BuildContext context, IconData icon, String text) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: StageScope.font(context, 44, min: 22), color: const Color(0xFF6C8AA3)),
        const SizedBox(height: 6),
        Text(text, style: TextStyle(color: const Color(0xFF8FA9BF), fontSize: StageScope.font(context, 17))),
      ],
    ),
  );
}

/// CANLI OPERASYON: sekmeler (Aktif / Kuyruk / Onay) ve seçili sekmenin listesi.
class LiveOpsColumn extends StatefulWidget {
  const LiveOpsColumn({super.key, required this.hub, required this.approvals, this.onOpenApprovals});

  final OfficeHub hub;
  final ApprovalStore approvals;
  final VoidCallback? onOpenApprovals;

  @override
  State<LiveOpsColumn> createState() => _LiveOpsColumnState();
}

class _LiveOpsColumnState extends State<LiveOpsColumn> {
  int _tab = 0;

  Widget _tabButton(BuildContext context, int index, String label) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _tab = index),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? kTabOn : kTabOff,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: selected ? const Color(0xFF3BA7FF) : kPanelLine),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: selected ? const Color(0xFF9FE8FF) : const Color(0xFFD7E6F2),
              fontWeight: FontWeight.w700,
              fontSize: StageScope.font(context, 16, min: 8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _opRow(BuildContext context, OfficeOp op) {
    final percent = (op.progress * 100).round();
    final color = op.state == OpState.awaitingApproval ? const Color(0xFFF1C40F) : const Color(0xFF39A0FF);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF05192A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kPanelLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  op.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: StageScope.font(context, 16)),
                ),
              ),
              Text('%$percent', style: TextStyle(color: color, fontSize: StageScope.font(context, 15))),
            ],
          ),
          Text(
            teamLabel(op.team),
            style: TextStyle(color: const Color(0xFF8FA9BF), fontSize: StageScope.font(context, 13, min: 8)),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: op.progress, minHeight: 5, backgroundColor: const Color(0xFF0B2A44), color: color),
          ),
          const SizedBox(height: 3),
          Text(
            op.step,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: const Color(0xFFB5CBDD), fontSize: StageScope.font(context, 13, min: 8)),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_tab == 2) {
      final pending = widget.approvals.pending;
      if (pending.isEmpty) return _empty(context, Icons.fact_check_outlined, 'Kayıt yok');
      return ListView(
        padding: const EdgeInsets.all(6),
        children: [
          for (final request in pending)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onOpenApprovals,
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF241D10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF8A6D1B)),
                ),
                child: Text(
                  request.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: const Color(0xFFFFE08A), fontSize: StageScope.font(context, 14)),
                ),
              ),
            ),
        ],
      );
    }
    final ops = _tab == 0 ? widget.hub.activeOps : widget.hub.queuedOps;
    if (ops.isEmpty) return _empty(context, Icons.description_outlined, 'Kayıt yok');
    return ListView(padding: const EdgeInsets.all(6), children: [for (final op in ops) _opRow(context, op)]);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[widget.hub, widget.approvals]),
      builder: (context, _) {
        final active = widget.hub.activeOps.length;
        final queued = widget.hub.queuedOps.length;
        final pending = widget.approvals.pendingCount;
        return LayoutBuilder(
          builder: (context, constraints) {
            final tabsHeight = constraints.maxHeight * 0.139;
            final gap = constraints.maxHeight * 0.03;
            return Column(
              children: [
                SizedBox(
                  height: tabsHeight,
                  child: Row(
                    children: [
                      _tabButton(context, 0, 'AKTİF ($active)'),
                      _tabButton(context, 1, 'KUYRUK ($queued)'),
                      _tabButton(context, 2, 'ONAY ($pending)'),
                    ],
                  ),
                ),
                SizedBox(height: gap),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(color: kPanelFill),
                    child: _body(context),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// "n/14 Aktif" sayacı.
class AgentCounter extends StatelessWidget {
  const AgentCounter({super.key, required this.hub});

  final OfficeHub hub;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: hub,
      builder: (context, _) {
        final working = hub.workingAgentCount;
        return Container(
          color: const Color(0xFF001129),
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.circle, size: StageScope.font(context, 11, min: 6), color: working > 0 ? const Color(0xFF3DDC84) : const Color(0xFF6C8AA3)),
              const SizedBox(width: 4),
              Text(
                '$working/${hub.totalAgentCount} Aktif',
                style: TextStyle(color: const Color(0xFFD7E6F2), fontSize: StageScope.font(context, 14, min: 8)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// AJAN DURUMLARI listesi.
class AgentsList extends StatelessWidget {
  const AgentsList({super.key, required this.hub});

  final OfficeHub hub;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: hub,
      builder: (context, _) {
        final fs = StageScope.font(context, 15);
        return Container(
          color: kPanelFill,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            children: [
              for (final agent in officeAgents)
                Builder(
                  builder: (context) {
                    final status = hub.statusOf(agent.id);
                    final busy = status.isNotEmpty;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.person, size: fs, color: busy ? const Color(0xFF3DDC84) : const Color(0xFF557089)),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 5,
                            child: Text(agent.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: fs)),
                          ),
                          Expanded(
                            flex: 6,
                            child: Text(
                              busy ? status : 'Beklemede',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: busy ? const Color(0xFF9FE8FF) : const Color(0xFF6C8AA3), fontSize: fs * 0.92),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// SON İŞLEMLER veya SİSTEM BİLDİRİMLERİ listesi.
class NoteList extends StatelessWidget {
  const NoteList({super.key, required this.hub, required this.notifications});

  final OfficeHub hub;

  /// true: sistem bildirimleri, false: son işlemler.
  final bool notifications;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: hub,
      builder: (context, _) {
        final notes = notifications ? hub.notifications : hub.activity;
        if (notes.isEmpty) {
          return Container(
            color: kPanelFill,
            child: _empty(context, notifications ? Icons.notifications_none : Icons.schedule, 'Kayıt yok'),
          );
        }
        final fs = StageScope.font(context, 14);
        return Container(
          color: kPanelFill,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            children: [
              for (final note in notes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hhmm(note.time), style: TextStyle(color: const Color(0xFF6C8AA3), fontSize: fs * 0.9)),
                      const SizedBox(width: 6),
                      Icon(Icons.circle, size: fs * 0.7, color: levelColor(note.level)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          note.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: const Color(0xFFD7E6F2), fontSize: fs),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// SİSTEM DURUMU satırları (CIO'nun rutin kontrol sonuçları).
class SystemStatusRows extends StatelessWidget {
  const SystemStatusRows({super.key, required this.hub});

  final OfficeHub hub;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: hub,
      builder: (context, _) {
        final status = hub.systemStatus;
        final checked = status.isNotEmpty;
        // PNG üzerinde başlıklar var; sadece sağda canlı değer.
        final keys = <String>['ai', 'internet', 'sync', 'security'];
        final fs = StageScope.font(context, 14, min: 8);
        return Padding(
          padding: const EdgeInsets.only(left: 118),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final key in keys)
                Text(
                  !checked
                      ? '…'
                      : (status[key] == true ? 'Aktif' : 'Kapalı'),
                  maxLines: 1,
                  style: TextStyle(
                    color: !checked
                        ? const Color(0xFF8FA9BF)
                        : (status[key] == true
                            ? const Color(0xFF3DDC84)
                            : const Color(0xFFFF9F43)),
                    fontSize: fs,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}


/// CANLI OPERASYON başlığının altındaki canlı alt yazı.
class LiveSubtitle extends StatelessWidget {
  const LiveSubtitle({super.key, required this.hub});

  final OfficeHub hub;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: hub,
      builder: (context, _) {
        final n = hub.activeOps.length;
        return Container(
          color: const Color(0xFF000E1C),
          alignment: Alignment.center,
          child: Text(
            n == 0 ? 'Şu an çalışan görev yok' : '$n görev devam ediyor…',
            maxLines: 1,
            style: TextStyle(color: const Color(0xFFB5CBDD), fontSize: StageScope.font(context, 17, min: 9)),
          ),
        );
      },
    );
  }
}

/// Onay bekleyen istek sayısını gösteren kırmızı rozet.
class ApprovalBadge extends StatelessWidget {
  const ApprovalBadge({super.key, required this.approvals, this.onTap});

  final ApprovalStore approvals;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: approvals,
      builder: (context, _) {
        final count = approvals.pendingCount;
        if (count == 0) return const SizedBox.shrink();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle),
            child: Text(
              '$count',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: StageScope.font(context, 15, min: 9)),
            ),
          ),
        );
      },
    );
  }
}
