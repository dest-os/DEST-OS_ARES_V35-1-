import '../../domain/codegen/code_artifact.dart';
import '../archive/secret_scrubber.dart';
import 'cio_finding.dart';

/// Güvenlik ajanının kural tabanlı kod taraması.
///
/// Yapay zekâ kullanmaz; bilinen riskli kalıpları arar. Bulamaması kodun güvenli
/// olduğu anlamına gelmez, yalnızca bu kalıpların bulunmadığını gösterir.
class SecurityAuditService {
  const SecurityAuditService();

  static final RegExp _cleartext = RegExp(r'http://(?!localhost|127\.0\.0\.1|10\.0\.2\.2|192\.168\.|schemas\.android\.com|www\.w3\.org)[A-Za-z0-9]');
  static final RegExp _dangerousPermission = RegExp(
    r'android\.permission\.(READ_SMS|SEND_SMS|READ_CONTACTS|ACCESS_FINE_LOCATION|RECORD_AUDIO|CAMERA|READ_EXTERNAL_STORAGE|WRITE_EXTERNAL_STORAGE|MANAGE_EXTERNAL_STORAGE)',
  );
  static final RegExp _shellInterpolation = RegExp(r'Process\.(run|start)\([^)]*\$');

  /// Üretilen dosyaları tarar ve bulguları döndürür (en fazla 20).
  List<CioFinding> scanArtifacts(List<CodeArtifact> artifacts) {
    const scrubber = SecretScrubber();
    final findings = <CioFinding>[];
    for (final artifact in artifacts) {
      final path = artifact.relativePath;
      final content = artifact.content;
      if (scrubber.scrub(content) != content) {
        findings.add(CioFinding(
          area: 'Güvenlik',
          level: 'error',
          text: '$path: kodun içinde API anahtarı/parola benzeri metin var.',
          fix: 'Anahtarı koddan çıkarın; çalışma anında Ayarlar ekranından veya güvenli depodan okuyun.',
        ));
      }
      if (_cleartext.hasMatch(content)) {
        findings.add(CioFinding(
          area: 'Güvenlik',
          level: 'warn',
          text: '$path: şifresiz http:// adresi kullanılıyor.',
          fix: 'Mümkünse https:// kullanın; yalnızca yerel ağ adresleri için http bırakın.',
        ));
      }
      if (content.contains('usesCleartextTraffic="true"')) {
        findings.add(CioFinding(
          area: 'Güvenlik',
          level: 'warn',
          text: '$path: şifresiz ağ trafiğine izin veriliyor.',
          fix: 'Yerel AI gerekmiyorsa usesCleartextTraffic değerini kaldırın.',
        ));
      }
      final permission = _dangerousPermission.firstMatch(content);
      if (permission != null) {
        findings.add(CioFinding(
          area: 'Güvenlik',
          level: 'info',
          text: '$path: hassas izin isteniyor (${permission.group(1)}).',
          fix: 'Bu iznin gerçekten gerekli olduğundan emin olun; gerekmiyorsa kaldırın.',
        ));
      }
      if (_shellInterpolation.hasMatch(content)) {
        findings.add(CioFinding(
          area: 'Güvenlik',
          level: 'warn',
          text: '$path: komut çalıştırmada kullanıcı girdisi birleştiriliyor olabilir.',
          fix: 'Komut argümanlarını liste olarak verin ve girdiyi doğrulayın.',
        ));
      }
      if (findings.length >= 20) break;
    }
    return findings;
  }

  /// Bulguları kullanıcıya gösterilecek kısa metne çevirir.
  String summarize(List<CioFinding> findings) {
    if (findings.isEmpty) {
      return 'Güvenlik taraması: bilinen riskli kalıp bulunmadı (kural tabanlı tarama; tam güvenlik garantisi değildir).';
    }
    final b = StringBuffer('Güvenlik taraması ${findings.length} bulgu verdi:\n');
    for (final f in findings.take(8)) {
      b.writeln('- ${f.text}');
      if (f.fix.isNotEmpty) b.writeln('  Çözüm: ${f.fix}');
    }
    return b.toString().trimRight();
  }
}
