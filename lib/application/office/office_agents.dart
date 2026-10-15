/// Sanal ofisin çalışan ajanları.
class OfficeAgent {
  const OfficeAgent({
    required this.id,
    required this.name,
    required this.title,
    required this.team,
    required this.persona,
  });

  final String id;
  final String name;
  final String title;

  /// listener, management, research, development, content, support
  final String team;

  /// Bu ajanın yapay zekâ çağrısındaki rol tanımı.
  final String persona;
}

/// Tüm ajanlar için ortak kurallar (senaryo madde 4).
const String officeRules =
    'Kurallar: Hayali sonuç, kaynak veya bilgi üretme; bilmiyorsan açıkça "bilmiyorum" de. '
    'Onay almadan kendi başına ekleme veya çıkarma yapma. Kullanıcının isteğini tam karşıla. '
    'Türkçe, açık ve düzenli yaz.';

const List<OfficeAgent> officeAgents = <OfficeAgent>[
  OfficeAgent(
    id: 'listener',
    name: 'Dinleyici',
    title: 'Yazılı / Sesli Komut',
    team: 'listener',
    persona: 'Sen Dinleyici\'sin: kullanıcının komutlarını alır ve sonuçları ona iletirsin.',
  ),
  OfficeAgent(
    id: 'ceo',
    name: 'CEO',
    title: 'Planlama, İş Dağıtımı, Kontrol',
    team: 'management',
    persona: 'Sen CEO\'sun: görevleri inceler, ekiplere dağıtır ve sonuçları kontrol edersin.',
  ),
  OfficeAgent(
    id: 'cio',
    name: 'CIO',
    title: 'Sistem, AI Altyapısı, Güvenlik',
    team: 'management',
    persona: 'Sen CIO\'sun: sistem sağlığı, AI altyapısı, güvenlik ve veri entegrasyonundan sorumlusun.',
  ),
  OfficeAgent(
    id: 'radar',
    name: 'AI Radar',
    title: 'Yeni AI\'ları tarar',
    team: 'support',
    persona: 'Sen AI Radar\'sın: yalnızca doğrulanabilir yapay zekâ servislerini önerirsin.',
  ),
  OfficeAgent(
    id: 'archivist',
    name: 'Arşiv Uzmanı',
    title: 'Eğitim klasörü kayıtları',
    team: 'support',
    persona: 'Sen Arşiv Uzmanı\'sın: başarılı işleri tarih ve konu başlığıyla eğitim klasörüne kaydedersin.',
  ),
  OfficeAgent(
    id: 'trainer',
    name: 'Eğitim Ajanı',
    title: 'Seviyeye göre ders verir',
    team: 'support',
    persona: 'Sen Eğitim Ajanı\'sın: kullanıcının seviyesine göre adım adım ders verir, önceki derslerden devam edersin.',
  ),
  OfficeAgent(
    id: 'support',
    name: 'Teknik Destek',
    title: 'Nasıl yapılır yardımı',
    team: 'support',
    persona: 'Sen Teknik Destek ajanısın: kullanıcıya uygulamayı nasıl kullanacağını anlatırsın.',
  ),
  OfficeAgent(
    id: 'security',
    name: 'Security-1',
    title: 'Güvenlik kontrolü',
    team: 'support',
    persona: 'Sen Güvenlik uzmanısın: güvenlik açıklarını bulur ve düzeltme önerirsin.',
  ),
  OfficeAgent(
    id: 'tester',
    name: 'Tester-1',
    title: 'Test ve kontrol',
    team: 'support',
    persona: 'Sen Test uzmanısın: sonucu isteğe göre kontrol eder, eksikleri listelersin.',
  ),
  OfficeAgent(
    id: 'researcher',
    name: 'Researcher-1',
    title: 'Bilgi toplama',
    team: 'research',
    persona: 'Sen Araştırmacısın: bilinen bilgileri toplar, bilmediğini açıkça belirtirsin.',
  ),
  OfficeAgent(
    id: 'analyst',
    name: 'Analyst-1',
    title: 'Veri analizi',
    team: 'research',
    persona: 'Sen Analistsin: bulguları karşılaştırır ve net sonuç çıkarırsın.',
  ),
  OfficeAgent(
    id: 'developer',
    name: 'Developer-1',
    title: 'Kod yazımı',
    team: 'development',
    persona: 'Sen Geliştiricisin: temiz, ayrı dosyalara bölünmüş kod yazarsın.',
  ),
  OfficeAgent(
    id: 'designer',
    name: 'Designer-1',
    title: 'Arayüz tasarımı',
    team: 'development',
    persona: 'Sen Tasarımcısın: arayüz ve görsel düzeni önerirsin.',
  ),
  OfficeAgent(
    id: 'writer',
    name: 'Writer-1',
    title: 'Metin ve içerik',
    team: 'content',
    persona: 'Sen Yazarsın: açık, düzenli ve akıcı metinler yazarsın.',
  ),
];

OfficeAgent? agentById(String id) {
  for (final a in officeAgents) {
    if (a.id == id) return a;
  }
  return null;
}

String teamLabel(String team) {
  switch (team) {
    case 'research':
      return 'Araştırma Ekibi';
    case 'development':
      return 'Geliştirme Ekibi';
    case 'content':
      return 'İçerik Ekibi';
    case 'support':
      return 'Destek Ekibi';
    case 'management':
      return 'Yönetim';
    default:
      return 'Dinleyici';
  }
}
