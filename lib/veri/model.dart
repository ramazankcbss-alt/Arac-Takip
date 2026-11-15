/// Sunucudan gelen veriyi taşıyan sade sınıflar.
library;

String _s(Object? v) => v == null ? '' : v.toString();
double? _d(Object? v) => v is num ? v.toDouble() : double.tryParse(_s(v).replaceAll(',', '.'));
List<Map<String, dynamic>> _liste(Object? v) =>
    v is List ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];

const sinifArac = 'Araç';
const sinifEkipman = 'Makine-Ekipman';

const rolYonetici = 'Yönetici';
const rolIzleyici = 'İzleyici';
const rolCiftlik = 'Çiftlik Sorumlusu';
const rolFormen = 'Formen';
const rolSorumlu = 'Makine-Ekipman Sorumlusu';
const rolBakim = 'Bakım-Onarım';

class Kisi {
  Kisi({required this.ad, required this.telefon, required this.ciftlik, required this.roller});
  factory Kisi.oku(Map<String, dynamic> j) => Kisi(
        ad: _s(j['ad']),
        telefon: _s(j['telefon']),
        ciftlik: _s(j['ciftlik']),
        roller: (j['roller'] is List) ? (j['roller'] as List).map(_s).toList() : const [],
      );
  final String ad, telefon, ciftlik;
  final List<String> roller;

  bool get yonetici => roller.contains(rolYonetici);
  bool get formen => yonetici || roller.contains(rolFormen) || roller.contains(rolCiftlik);
  /// Tüm ekipleri yöneten: Yönetici ya da (kendi kapsamında) Çiftlik Sorumlusu.
  bool get ustYonetim => yonetici || roller.contains(rolCiftlik);
  bool get sorumlu => yonetici || roller.contains(rolSorumlu) || roller.contains(rolBakim);
  /// Bakım-onarım ekibi: arıza, servis ve malzeme taleplerini tüm çiftliklerde takip eder.
  bool get bakimEkibi => yonetici || roller.contains(rolSorumlu) || roller.contains(rolBakim);
  /// Araç-makine kullanmayan kadro (müdür, uzman, veteriner, raporlama): izler, işlem yapmaz.
  bool get izleyici => roller.contains(rolIzleyici) && !formen && !sorumlu;

  String get rolMetni {
    if (roller.isEmpty) return 'Operatör';
    return roller.join(', ');
  }
}

class Arac {
  Arac({
    required this.no,
    required this.tur,
    required this.model,
    required this.plaka,
    required this.ciftlik,
    required this.sayac,
    required this.durum,
    required this.yil,
    required this.not,
    required this.kullanim,
    this.sinif = sinifArac,
  });
  factory Arac.oku(Map<String, dynamic> j) => Arac(
        no: _s(j['no']),
        tur: _s(j['tur']),
        model: _s(j['model']),
        plaka: _s(j['plaka']),
        ciftlik: _s(j['ciftlik']),
        sayac: _d(j['sayac']),
        durum: _s(j['durum']).isEmpty ? 'Aktif' : _s(j['durum']),
        yil: _s(j['yil']),
        not: _s(j['not']),
        kullanim: (j['kullanim'] is num) ? (j['kullanim'] as num).toInt() : 0,
        sinif: _s(j['sinif']) == sinifEkipman ? sinifEkipman : sinifArac,
      );
  final String no, tur, model, plaka, ciftlik, durum, yil, not, sinif;
  final double? sayac;
  final int kullanim;

  bool get arizali => durum == 'Arızalı';
  bool get ekipman => sinif == sinifEkipman;
  /// Araçta motor saati, makine-ekipmanda birikmiş çalışma saati.
  String get sayacAdi => ekipman ? 'Çalışma saati' : 'Motor saati';
  bool get pasif => durum == 'Pasif';
  String get baslik => [no, tur].where((x) => x.isNotEmpty).join(' · ');
  String get alt => [model, plaka, ciftlik].where((x) => x.isNotEmpty).join(' · ');
}

class Kullanim {
  Kullanim(this.j);
  final Map<String, dynamic> j;
  String get no => _s(j['no']);
  String get tarih => _s(j['tarih']);
  String get arac => _s(j['arac']);
  String get personel => _s(j['personel']);
  String get telefon => _s(j['telefon']);
  String get ciftlik => _s(j['ciftlik']);
  String get baslangic => _s(j['baslangic']);
  String get bitis => _s(j['bitis']);
  double? get sayac1 => _d(j['sayac1']);
  double? get sayac2 => _d(j['sayac2']);
  double? get saat => _d(j['saat']);
  String get is_ => _s(j['is']);
  String get not => _s(j['not']);
  String get durum => _s(j['durum']);
  String get onaylayan => _s(j['onaylayan']);
  String get sekil => _s(j['sekil']);
  List<String> get ekipman => (j['ekipman'] is List) ? (j['ekipman'] as List).map(_s).where((x) => x.isNotEmpty).toList() : const [];
  bool kontrol(String alan) => _s(j[alan]) == 'Yapıldı';
  bool get bakimTam =>
      kontrol('gresleme') && kontrol('hava') && kontrol('yag') && kontrol('radyator');
  List<String> get eksikKontroller => [
        if (!kontrol('gresleme')) 'Gresleme',
        if (!kontrol('hava')) 'Hava filtresi',
        if (!kontrol('yag')) 'Motor yağı',
        if (!kontrol('radyator')) 'Radyatör',
      ];
}

class Ariza {
  Ariza(this.j);
  final Map<String, dynamic> j;
  String get no => _s(j['no']);
  String get zaman => _s(j['zaman']);
  String get arac => _s(j['arac']);
  String get bildiren => _s(j['bildiren']);
  String get ciftlik => _s(j['ciftlik']);
  String get aciklama => _s(j['aciklama']);
  String get foto => _s(j['foto']);
  String get durum => _s(j['durum']);
  String get guncelleyen => _s(j['guncelleyen']);
  String get guncelleme => _s(j['guncelleme']);
  String get not => _s(j['not']);
  bool get kapali => durum == 'Onarıldı' || durum == 'Geçersiz bildirim';
  String get yer => _s(j['yer']).isEmpty ? sinifArac : _s(j['yer']);
  String get birlikte => _s(j['birlikte']);
}

class BakimUyari {
  BakimUyari(this.j);
  final Map<String, dynamic> j;
  String get arac => _s(j['arac']);
  String get tur => _s(j['tur']);
  String get model => _s(j['model']);
  String get bakim => _s(j['bakim']);
  double? get periyot => _d(j['periyot']);
  double? get son => _d(j['son']);
  double? get sayac => _d(j['sayac']);
  int get kalan => (_d(j['kalan']) ?? 0).round();
  bool get gecikti => _s(j['durum']) == 'Gecikti';
  /// 'saat' (motor saati) ya da 'gün' (servis kaydındaki sonraki bakım tarihi)
  String get birim => _s(j['birim']).isEmpty ? 'saat' : _s(j['birim']);
  String get hedef => _s(j['hedef']);
  String get kalanMetni {
    final ek = birim == 'gün' ? ' (son tarih $hedef)' : ' (sayaç ${_s(j['sayac'])})';
    if (gecikti) return '${-kalan} $birim gecikti$ek';
    if (birim == 'gün' && kalan == 0) return 'Bugün yapılmalı$ek';
    return '$kalan $birim kaldı$ek';
  }
}

/// Malzeme / parça / bakım talebi (bakım-onarım ekibi takip eder).
class Talep {
  Talep(this.j);
  final Map<String, dynamic> j;
  String get no => _s(j['no']);
  String get tarih => _s(j['tarih']);
  String get arac => _s(j['arac']);
  String get tur => _s(j['tur']);
  String get malzeme => _s(j['malzeme']);
  String get miktar => _s(j['miktar']);
  String get aciklama => _s(j['aciklama']);
  List<String> get fotolar =>
      (j['fotolar'] is List) ? (j['fotolar'] as List).map(_s).where((x) => x.isNotEmpty).toList() : const [];
  String get talepEden => _s(j['talepEden']);
  String get telefon => _s(j['telefon']);
  String get ciftlik => _s(j['ciftlik']);
  String get durum => _s(j['durum']);
  String get guncelleyen => _s(j['guncelleyen']);
  String get guncelleme => _s(j['guncelleme']);
  String get not => _s(j['not']);
  bool get kapali => durum == 'Tamamlandı' || durum == 'İptal';
}

const talepTurleri = ['Parça değişimi', 'Bakım ihtiyacı', 'Malzeme alımı', 'Lastik', 'Diğer'];
const talepDurumlari = ['Talep edildi', 'Değerlendiriliyor', 'Satınalmada', 'Tedarik edildi', 'Tamamlandı', 'İptal'];

class Plan {
  Plan(this.j);
  final Map<String, dynamic> j;
  String get arac => _s(j['arac']);
  String get bakim => _s(j['bakim']);
  double? get periyot => _d(j['periyot']);
  double? get son => _d(j['son']);
  String get sonTarih => _s(j['sonTarih']);
}

class BakimKaydi {
  BakimKaydi(this.j);
  final Map<String, dynamic> j;
  String get no => _s(j['no']);
  String get tarih => _s(j['tarih']);
  String get arac => _s(j['arac']);
  String get kayitTuru => _s(j['kayitTuru']);
  String get bakim => _s(j['bakim']);
  double? get sayac => _d(j['sayac']);
  String get is_ => _s(j['is']);
  String get parca => _s(j['parca']);
  String get firma => _s(j['firma']);
  String get tutar => _s(j['tutar']);
  String get belge => _s(j['belge']);
  String get giren => _s(j['giren']);
}

class Bildirim {
  Bildirim(this.j);
  final Map<String, dynamic> j;
  String get zaman => _s(j['zaman']);
  String get tur => _s(j['tur']);
  String get baslik => _s(j['baslik']);
  String get metin => _s(j['metin']);
  bool get okundu => j['okundu'] == true;
}

class CihazTalebi {
  CihazTalebi(this.j);
  final Map<String, dynamic> j;
  String get telefon => _s(j['telefon']);
  String get ad => _s(j['ad']);
  String get cihaz => _s(j['cihaz']);
  String get talep => _s(j['talep']);
  String get ciftlik => _s(j['ciftlik']);
  bool get kilitli => _s(j['durum']) == 'Kilitli';
}

/// Personel listesindeki kişi (Yönetici seçimleri için).
class PersonelKaydi {
  PersonelKaydi(this.j);
  final Map<String, dynamic> j;
  String get telefon => _s(j['telefon']);
  String get ad => _s(j['ad']);
  String get gorev => _s(j['gorev']);
  String get ciftlik => _s(j['ciftlik']);
}

/// Uygulama kullanıcısı (Yönetici: kullanıcı yönetimi).
class Kullanici {
  Kullanici(this.j);
  final Map<String, dynamic> j;
  String get telefon => _s(j['telefon']);
  String get ad => _s(j['ad']);
  String get gorev => _s(j['gorev']);
  String get ciftlik => _s(j['ciftlik']);
  List<String> get roller => (j['roller'] is List) ? (j['roller'] as List).map(_s).toList() : const [];
  String get cihaz => _s(j['cihaz']);
  String get durum => _s(j['durum']);
  String get onay => _s(j['onay']);
}

/// Formenin personele verdiği iş emri.
class IsEmri {
  IsEmri(this.j);
  final Map<String, dynamic> j;
  String get no => _s(j['no']);
  String get tarih => _s(j['tarih']);
  String get telefon => _s(j['telefon']);
  String get personel => _s(j['personel']);
  String get formenAd => _s(j['formenAd']);
  String get ciftlik => _s(j['ciftlik']);
  String get yerTuru => _s(j['yerTuru']);
  String get yer => _s(j['yer']);
  String get is_ => _s(j['is']);
  String get arac => _s(j['arac']);
  List<String> get ekipman =>
      (j['ekipman'] is List) ? (j['ekipman'] as List).map(_s).where((x) => x.isNotEmpty).toList() : const [];
  String get aciklama => _s(j['aciklama']);
  String get durum => _s(j['durum']);
  bool get acik => durum == 'Verildi' || durum == 'Başladı';
  String get aracMetni => [arac, ...ekipman].where((x) => x.isNotEmpty).join(' + ');
}

class YerOnerisi {
  YerOnerisi(this.j);
  final Map<String, dynamic> j;
  String get yerTuru => _s(j['yerTuru']);
  String get yer => _s(j['yer']);
  String get ciftlik => _s(j['ciftlik']);
}

/// Ekip görünümündeki personel (formen–personel bağı).
class EkipUyesi {
  EkipUyesi(this.j);
  final Map<String, dynamic> j;
  String get telefon => _s(j['telefon']);
  String get ad => _s(j['ad']);
  String get gorev => _s(j['gorev']);
  String get ciftlik => _s(j['ciftlik']);
  String get formen => _s(j['formen']);
  String get formenAd => _s(j['formenAd']);
  String get zaman => _s(j['zaman']);
}

class Formen {
  Formen(this.j);
  final Map<String, dynamic> j;
  String get telefon => _s(j['telefon']);
  String get ad => _s(j['ad']);
  String get ciftlik => _s(j['ciftlik']);
}

/// Ana veri paketi (sunucudaki `veri` işleminin cevabı).
class Veri {
  Veri(this.j)
      : kisi = Kisi.oku((j['kisi'] as Map?)?.cast<String, dynamic>() ?? const {}),
        araclar = _liste(j['araclar']).map(Arac.oku).toList(),
        acikIs = j['acikIs'] is Map ? Kullanim((j['acikIs'] as Map).cast<String, dynamic>()) : null,
        benim = _liste(j['benim']).map(Kullanim.new).toList(),
        aktif = _liste(j['aktif']).map(Kullanim.new).toList(),
        bildirimler = _liste(j['bildirimler']).map(Bildirim.new).toList(),
        arizalarim = _liste(j['arizalarim']).map(Ariza.new).toList(),
        onayBekleyen = _liste(j['onayBekleyen']).map(Kullanim.new).toList(),
        cihazBekleyen = _liste(j['cihazBekleyen']).map(CihazTalebi.new).toList(),
        arizalar = _liste(j['arizalar']).map(Ariza.new).toList(),
        bakimUyari = _liste(j['bakimUyari']).map(BakimUyari.new).toList(),
        plan = _liste(j['plan']).map(Plan.new).toList(),
        bakimKayit = _liste(j['bakimKayit']).map(BakimKaydi.new).toList(),
        ciftlikSorumlulari = _liste(j['ciftlikSorumlulari']).map(PersonelKaydi.new).toList(),
        personelTum = _liste(j['personelTum']).map(PersonelKaydi.new).toList(),
        talepler = _liste(j['talepler']).map(Talep.new).toList(),
        kullanicilar = _liste(j['kullanicilar']).map(Kullanici.new).toList(),
        izlemeEmirleri = _liste(j['izlemeEmirleri']).map(IsEmri.new).toList(),
        isEmirlerim = _liste(j['isEmirlerim']).map(IsEmri.new).toList(),
        verdigimEmirler = _liste(j['verdigimEmirler']).map(IsEmri.new).toList(),
        yerler = _liste(j['yerler']).map(YerOnerisi.new).toList(),
        ekibim = _liste(j['ekibim']).map(EkipUyesi.new).toList(),
        atanabilir = _liste(j['atanabilir']).map(EkipUyesi.new).toList(),
        formenler = _liste(j['formenler']).map(Formen.new).toList(),
        ciftlikler = (j['ciftlikler'] is List) ? (j['ciftlikler'] as List).map(_s).toList() : const [];

  final Map<String, dynamic> j;
  final Kisi kisi;
  final List<Arac> araclar;
  final Kullanim? acikIs;
  final List<Kullanim> benim, aktif, onayBekleyen;
  final List<Bildirim> bildirimler;
  final List<Ariza> arizalarim, arizalar;
  final List<CihazTalebi> cihazBekleyen;
  final List<BakimUyari> bakimUyari;
  final List<Plan> plan;
  final List<BakimKaydi> bakimKayit;
  final List<String> ciftlikler;
  final List<EkipUyesi> ekibim, atanabilir;
  final List<IsEmri> isEmirlerim, verdigimEmirler, izlemeEmirleri;
  final List<Kullanici> kullanicilar;
  final List<Talep> talepler;
  final List<PersonelKaydi> ciftlikSorumlulari, personelTum;
  final List<YerOnerisi> yerler;
  final List<Formen> formenler;

  int get okunmamis => bildirimler.where((b) => !b.okundu).length;

  Arac? arac(String no) {
    for (final a in araclar) {
      if (a.no == no) return a;
    }
    return null;
  }

  /// İş başlatma listesi: personelin en sık kullandığı araçlar başta, ardından
  /// kendi çiftliğinin araçları, sonra diğerleri; pasif araçlar listelenmez.
  List<Arac> secimListesi({bool ekipman = false}) {
    final l = araclar.where((a) => !a.pasif && a.ekipman == ekipman).toList();
    l.sort((x, y) {
      final k = y.kullanim.compareTo(x.kullanim);
      if (k != 0) return k;
      final cx = x.ciftlik == kisi.ciftlik ? 0 : 1;
      final cy = y.ciftlik == kisi.ciftlik ? 0 : 1;
      if (cx != cy) return cx.compareTo(cy);
      return x.no.compareTo(y.no);
    });
    return l;
  }
}

/// Araç türleri (Makine-Ekipman Sorumlusunun seçimi için).
const aracTurleri = [
  'Traktör',
  'Kamyon',
  'Kamyonet',
  'Manitou / Teleskopik Yükleyici',
  'Kepçe / Loder',
  'Biçerdöver',
  'Pancar Söküm Makinesi (kendi yürür)',
  'Silaj Makinesi (kendi yürür)',
  'Yem Karma Vagonu (kendi yürür)',
  'Forklift',
  'Pick-up / Binek',
  'Diğer',
];

/// Araca bağlanan makine ve ekipman türleri.
const ekipmanTurleri = [
  'Pulluk',
  'Kültivatör',
  'Diskaro',
  'Rotovatör',
  'Merdane',
  'Mibzer',
  'Pnömatik Mibzer',
  'Gübre Serpme Makinesi',
  'İlaçlama Makinesi',
  'Römork',
  'Tanker',
  'Çayır Biçme Makinesi',
  'Tırmık',
  'Balya Makinesi',
  'Silaj Makinesi (çekilir)',
  'Pancar Söküm Makinesi (çekilir)',
  'Yem Karma Vagonu (çekilir)',
  'Gübre Tankeri / Fıçısı',
  'Gübre Sıyırma Bıçağı / Kürek',
  'Dışkı Sıyırıcı (sabit sistem)',
  'Balya Kıskacı / Taşıma Aparatı',
  'Silaj Blok Kesici / Kesme Kovası',
  'Altlık Serme Makinesi',
  'Yükleyici Kovası',
  'Hayvan Taşıma Römorku',
  'Diğer',
];

/// İş emrinde çalışma yeri türleri.
const yerTurleri = ['Tarla', 'Ahır', 'Silaj / Yem Deposu', 'Atölye', 'Diğer'];

const tarlaIsleri = [
  'Toprak işleme',
  'Ekim',
  'Gübreleme',
  'İlaçlama',
  'Sulama',
  'Çapalama',
  'Hasat / Söküm',
  'Biçme',
  'Balya yapma',
  'Silaj hasadı',
];

const ahirIsleri = [
  'Yem karma ve yemleme',
  'Balya taşıma',
  'Kaba yem taşıma',
  'Silaj açma ve taşıma',
  'Dışkı temizleme / gübre sıyırma',
  'Gübre çıkarma (tanker / römork)',
  'Altlık serme',
  'Yalak ve bölme temizliği',
  'Hayvan sevki / nakli',
  'Ahır bakım ve onarım',
];

const digerIsler = ['Nakliye', 'Atölye / bakım', 'Diğer'];

/// Yer türüne göre önerilen işler.
List<String> islerFor(String? yerTuru) {
  switch (yerTuru) {
    case 'Tarla':
      return [...tarlaIsleri, ...digerIsler];
    case 'Ahır':
    case 'Silaj / Yem Deposu':
      return [...ahirIsleri, ...digerIsler];
    default:
      return [...tarlaIsleri, ...ahirIsleri, ...digerIsler];
  }
}

const isTurleri = [...tarlaIsleri, ...ahirIsleri, ...digerIsler];

const bakimKayitTurleri = ['Periyodik bakım', 'Onarım', 'Parça değişimi', 'Lastik', 'Muayene', 'Diğer'];
const arizaDurumlari = ['Bildirildi', 'Atölyede', 'Parça bekleniyor', 'Onarıldı', 'Geçersiz bildirim'];
