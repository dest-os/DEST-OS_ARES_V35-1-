import '../../domain/office/ai_provider.dart';
import 'approval_store.dart';
import 'office_hub.dart';
import 'provider_catalog_seed.dart';
import 'provider_store.dart';

/// Kullanıcının Onaylar sekmesindeki kararını uygular.
class ApprovalActions {
  ApprovalActions({required this.approvals, required this.providers, this.hub});

  final ApprovalStore approvals;
  final ProviderStore providers;
  final OfficeHub? hub;

  /// Kararı kaydeder ve türüne göre sonucu uygular. Kullanıcıya gösterilecek özeti döndürür.
  Future<String> decide(ApprovalRequest request, {required bool approved}) async {
    await approvals.resolve(request.id, approved: approved);
    switch (request.kind) {
      case 'paid_ai':
        {
        final p = providers.byId(request.refId);
        if (p == null) return 'Sağlayıcı bulunamadı.';
        await providers.upsert(p.copyWith(paidApproved: approved));
        hub?.log('${p.name} ücretli kullanım: ${approved ? 'onaylandı' : 'reddedildi'}', level: approved ? 'warn' : 'info');
        return approved ? '${p.name} için ücretli kullanım açıldı.' : '${p.name} ücretli kullanıma kapalı kaldı.';
        }
      case 'new_ai':
        {
        if (!approved) return 'Öneri reddedildi.';
        for (final s in curatedSuggestions()) {
          if (s.id == request.refId) {
            await providers.upsert(s.copyWith(verified: true, autoFilled: true, enabled: false));
            hub?.log('${s.name} kataloğa eklendi (API anahtarını siz girin).', level: 'ok');
            return '${s.name} AI Kataloğu\'na eklendi. Bilgileri dolduruldu; API anahtarını ve modelini girip etkinleştirin.';
          }
        }
        return 'Öneri listede bulunamadı.';
        }
      case 'new_model':
        {
        if (!approved) return 'Yeni model reddedildi.';
        final parts = request.refId.split('|');
        if (parts.length < 2) return 'Model bilgisi okunamadı.';
        final p = providers.byId(parts.first);
        if (p == null) return 'Sağlayıcı bulunamadı.';
        await providers.upsert(p.copyWith(model: parts.sublist(1).join('|')));
        return '${p.name} artık ${parts.sublist(1).join('|')} modelini kullanıyor.';
        }
      default:
        return approved ? 'Onaylandı.' : 'Reddedildi.';
    }
  }
}
