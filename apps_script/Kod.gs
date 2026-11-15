/**
 * Panagro Araç-Makine Takip — sunucu (Google Apps Script web uygulaması)
 *
 * Bu kod "Araç Takip – Kayıtlar" tablosuna bağlı Apps Script projesine
 * yapıştırılır. Kurulum: README.md → "Sunucu kurulumu".
 *
 * Sayfalar ilk istekte kendiliğinden oluşturulur:
 *   Araçlar, Kullanım, Bakım_Plan, Bakım_Kayıt, Arıza, Cihazlar, Roller, Bildirimler
 * Personel bilgisi Yönetim Raporu tablosundaki "Personel_Listesi" sayfasından okunur.
 */

var RAPOR_TABLO_ID = '1GkKhf3j-VK8tomjeIqLDMKs-mlq7CYJOfQMyokMGh3Y';
var FOTO_KLASOR_ID = '1lRtoFrA9NyhPF280G9uLnIEIeWU-1tOe'; // Drive "Araç Takip"
var TZ = 'Europe/Istanbul';
var PIN_DENEME_SINIRI = 5;

var BASLIKLAR = {
  'Araçlar': ['Araç No', 'Tür', 'Marka / Model', 'Plaka / Şase No', 'Çiftlik', 'Motor Saati',
    'Durum', 'Model Yılı', 'Not', 'Ekleyen', 'Eklenme', 'Güncelleme', 'Sınıf'],
  'Kullanım': ['Kayıt No', 'Tarih', 'Araç No', 'Personel', 'Telefon', 'Çiftlik', 'Başlangıç',
    'Bitiş', 'Başlangıç Sayacı', 'Bitiş Sayacı', 'Çalışma (saat)', 'İş', 'Gresleme',
    'Hava Filtresi', 'Motor Yağı', 'Radyatör', 'Not', 'Durum', 'Onaylayan', 'Onay Zamanı',
    'Kayıt Şekli', 'Sorumlu Formen', 'Makine-Ekipman'],
  'Bakım_Plan': ['Araç No', 'Bakım Türü', 'Periyot (saat)', 'Son Yapılan (saat)', 'Son Yapılan Tarih'],
  'Bakım_Kayıt': ['Kayıt No', 'Tarih', 'Araç No', 'Kayıt Türü', 'Bakım Türü', 'Motor Saati',
    'Yapılan İş', 'Değişen Parça', 'Firma / Atölye', 'Tutar (TL)', 'Belge No', 'Giren',
    'Giriş Zamanı'],
  'Arıza': ['Arıza No', 'Bildirim Zamanı', 'Araç No', 'Bildiren', 'Telefon', 'Çiftlik',
    'Açıklama', 'Fotoğraf', 'Durum', 'Son Güncelleyen', 'Son Güncelleme', 'Onarım Notu',
    'Kapanış Zamanı', 'Arıza Yeri', 'Birlikte Kullanılan'],
  'Cihazlar': ['Telefon', 'Ad Soyad', 'Cihaz Kimliği', 'Cihaz Adı', 'Oturum Anahtarı',
    'PIN Özeti', 'Durum', 'Onaylayan', 'Talep Zamanı', 'Onay Zamanı'],
  'Roller': ['Telefon', 'Ad Soyad', 'Rol', 'Çiftlik', 'Not'],
  // Personelin bağlı olduğu formen (güncel görevlendirme) ve görevlendirme geçmişi
  // Formenin personele verdiği iş emri: nerede, hangi iş, hangi araç ve makine-ekipmanla
  'İş_Emirleri': ['Emir No', 'Tarih', 'Personel Telefon', 'Personel', 'Formen Telefon', 'Formen', 'Çiftlik',
    'Yer Türü', 'Yer', 'İş', 'Araç No', 'Makine-Ekipman', 'Açıklama', 'Durum', 'Kullanım Kayıt No',
    'Oluşturma', 'Güncelleme'],
  'Ekipler': ['Telefon', 'Ad Soyad', 'Formen Telefon', 'Formen', 'Çiftlik', 'Görevlendirme Zamanı', 'Görevlendiren'],
  'Görevlendirme_Geçmişi': ['Zaman', 'Telefon', 'Ad Soyad', 'Önceki Formen', 'Yeni Formen', 'Yeni Çiftlik', 'İşlemi Yapan'],
  'Bildirimler': ['Zaman', 'Alıcı Telefon', 'Tür', 'Başlık', 'Metin', 'Okundu'],
  // Günlük denetim görevinin yazdığı mutabakat sonuçları (uygulama yalnız okur)
  'Mutabakat': ['Tarih', 'Sonuç', 'Araç No', 'Konu', 'Açıklama', 'Kaynaklar', 'Personel', 'Kimlik']
};

var VARSAYILAN_PLAN = [
  ['Motor yağı ve yağ filtresi', 250],
  ['Hava filtresi', 500],
  ['Yakıt filtresi', 500],
  ['Hidrolik yağ ve filtre', 1000]
];

// Araçlar sayfasında iki sınıf tutulur: motorlu araçlar ve araca bağlanan makine-ekipman.
var SINIF_ARAC = 'Araç';
var SINIF_EKIPMAN = 'Makine-Ekipman';
// Makine-ekipmanın çalışma saati, bağlandığı aracın çalışma süresinden birikir.
var VARSAYILAN_PLAN_EKIPMAN = [
  ['Gresleme ve bağlantı noktaları kontrolü', 50],
  ['Aşınan parça kontrolü (uç, disk, bıçak, zincir)', 200]
];

var ROL_YONETICI = 'Yönetici';
var ROL_FORMEN = 'Formen';
var ROL_SORUMLU = 'Makine-Ekipman Sorumlusu';
var ROL_BAKIM = 'Bakım-Onarım';

// ---------------------------------------------------------------------------
// Giriş noktaları

function doGet(e) {
  return json_({ ok: true, ad: 'Araç Takip sunucusu', zaman: simdi_() });
}

function doPost(e) {
  var p = (e && e.parameter) || {};
  var anahtar = PropertiesService.getScriptProperties().getProperty('ANAHTAR');
  if (!anahtar || p.anahtar !== anahtar) return json_({ ok: false, hata: 'Uygulama anahtarı hatalı.' });
  var g;
  try {
    g = JSON.parse((e && e.postData && e.postData.contents) || '{}');
  } catch (err) {
    return json_({ ok: false, hata: 'İstek okunamadı.' });
  }
  var kilit = LockService.getScriptLock();
  try {
    kilit.waitLock(20000);
    hazirla_();
    if (g.tur === 'giris') return json_(giris_(g));
    var k = oturum_(g.oturum);
    if (!k) return json_({ ok: false, oturum: false, hata: 'Oturum geçersiz. Tekrar giriş yapın.' });
    if (k.cihazDurum !== 'Onaylı') return json_({ ok: true, durum: k.cihazDurum, kisi: kisiOzeti_(k) });
    switch (g.tur) {
      case 'veri': return json_(veri_(k));
      case 'isBaslat': return json_(isBaslat_(k, g));
      case 'isBitir': return json_(isBitir_(k, g));
      case 'ariza': return json_(ariza_(k, g));
      case 'arizaDurum': return json_(arizaDurum_(k, g));
      case 'onayla': return json_(onayla_(k, g));
      case 'kayitDuzelt': return json_(kayitDuzelt_(k, g));
      case 'cihazOnay': return json_(cihazOnay_(k, g));
      case 'aracKaydet': return json_(aracKaydet_(k, g));
      case 'bakimKaydet': return json_(bakimKaydet_(k, g));
      case 'planKaydet': return json_(planKaydet_(k, g));
      case 'bildirimOkundu': return json_(bildirimOkundu_(k));
      case 'ekipAta': return json_(ekipAta_(k, g));
      case 'isEmriVer': return json_(isEmriVer_(k, g));
      case 'bildirimKontrol': return json_(bildirimKontrol_(k, g));
      case 'isEmriDurum': return json_(isEmriDurum_(k, g));
      default: return json_({ ok: false, hata: 'Bilinmeyen işlem: ' + g.tur });
    }
  } catch (err) {
    return json_({ ok: false, hata: String(err && err.message || err) });
  } finally {
    try { kilit.releaseLock(); } catch (e2) {}
  }
}

// ---------------------------------------------------------------------------
// Yardımcılar

function json_(o) {
  return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON);
}
function simdi_() { return Utilities.formatDate(new Date(), TZ, 'dd.MM.yyyy HH:mm'); }
function bugun_() { return Utilities.formatDate(new Date(), TZ, 'dd.MM.yyyy'); }
function ss_() { return SpreadsheetApp.getActiveSpreadsheet(); }
function tel_(s) {
  var d = String(s || '').replace(/\D/g, '');
  if (d.length > 10) d = d.slice(-10);
  return d.length === 10 ? '0' + d : '';
}
function bas_(s) { return String(s == null ? '' : s).trim(); }
function buyuk_(s) { return bas_(s).toLocaleUpperCase('tr-TR'); }
function sayi_(s) {
  var t = String(s == null ? '' : s).replace(/\s/g, '').replace(',', '.');
  var n = parseFloat(t);
  return isNaN(n) ? null : n;
}
function ozet_(metin) {
  var b = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, metin, Utilities.Charset.UTF_8);
  return b.map(function (x) { return ('0' + (x & 0xff).toString(16)).slice(-2); }).join('');
}

function hazirla_() {
  var ss = ss_();
  Object.keys(BASLIKLAR).forEach(function (ad) {
    var sh = ss.getSheetByName(ad);
    if (!sh) {
      sh = ss.insertSheet(ad);
      sh.getRange(1, 1, 1, BASLIKLAR[ad].length).setValues([BASLIKLAR[ad]]).setFontWeight('bold');
      sh.setFrozenRows(1);
      // Telefon ve tarih sütunları metin kalsın (baştaki 0 silinmesin).
      sh.getRange('A:Z').setNumberFormat('@');
    } else if (sh.getLastColumn() < BASLIKLAR[ad].length) {
      // Sonradan eklenen sütunların başlığı (ör. Kullanım → Sorumlu Formen)
      var mevcut = sh.getLastColumn();
      sh.getRange(1, mevcut + 1, 1, BASLIKLAR[ad].length - mevcut)
        .setValues([BASLIKLAR[ad].slice(mevcut)]).setFontWeight('bold');
    }
  });
  var ilk = ss.getSheetByName('Sayfa1') || ss.getSheetByName('Sheet1');
  if (ilk && ilk.getLastRow() === 0 && ss.getSheets().length > 1) ss.deleteSheet(ilk);
}

function tablo_(ad) {
  var sh = ss_().getSheetByName(ad);
  var n = sh.getLastRow();
  var w = BASLIKLAR[ad].length;
  var rows = n < 2 ? [] : sh.getRange(2, 1, n - 1, w).getDisplayValues();
  return { sh: sh, rows: rows };
}
function ekle_(ad, satir) {
  var sh = ss_().getSheetByName(ad);
  sh.appendRow(satir.map(function (x) { return x == null ? '' : String(x); }));
  return sh.getLastRow();
}
function hucre_(ad, satirNo, sutunAdi, deger) {
  var i = BASLIKLAR[ad].indexOf(sutunAdi);
  if (i < 0) throw new Error(ad + ' sayfasında ' + sutunAdi + ' sütunu yok.');
  ss_().getSheetByName(ad).getRange(satirNo, i + 1).setValue(deger == null ? '' : String(deger));
}
function sutun_(ad, sutunAdi) { return BASLIKLAR[ad].indexOf(sutunAdi); }
function yeniNo_(ad, onEk) {
  var t = tablo_(ad);
  var max = 0;
  t.rows.forEach(function (r) {
    var n = parseInt(String(r[0]).replace(/\D/g, ''), 10);
    if (n > max) max = n;
  });
  return onEk + ('00000' + (max + 1)).slice(-5);
}

// ---------------------------------------------------------------------------
// Personel, roller, oturum

function personeller_() {
  var c = CacheService.getScriptCache();
  var j = c.get('personel_arac');
  if (j) return JSON.parse(j);
  var sh = SpreadsheetApp.openById(RAPOR_TABLO_ID).getSheetByName('Personel_Listesi');
  var n = sh.getLastRow();
  var rows = n < 2 ? [] : sh.getRange(2, 1, n - 1, 5).getDisplayValues();
  // Roller sayfası: herhangi bir rol yazılan kişi dahil edilir, 'Hariç' yazılan çıkarılır.
  var rolde = {}, haric = {};
  rollerSatirlari_().forEach(function (r) {
    var t = tel_(r[0]);
    if (!t || !bas_(r[2])) return;
    if (buyuk_(r[2]).indexOf('HARİÇ') >= 0) haric[t] = true; else rolde[t] = true;
  });
  var m = {};
  rows.forEach(function (r) {
    var t = tel_(r[3]);
    if (!t || haric[t]) return;
    if (!aracPersoneli_(r[1]) && !rolde[t]) return;
    m[t] = { ad: bas_(r[0]), gorev: bas_(r[1]), birim: bas_(r[2]) };
  });
  c.put('personel_arac', JSON.stringify(m), 600);
  return m;
}

var ROLLER_ = null;
function rollerSatirlari_() {
  if (!ROLLER_) ROLLER_ = tablo_('Roller').rows;
  return ROLLER_;
}

/** Güncel ekip görevlendirmeleri: personel telefonu → { formen, formenAd, ciftlik }. */
var EKIP_ = null;
function ekipler_() {
  if (EKIP_) return EKIP_;
  var m = {};
  tablo_('Ekipler').rows.forEach(function (r) {
    var t = tel_(r[0]);
    if (t) m[t] = { formen: tel_(r[2]), formenAd: bas_(r[3]), ciftlik: bas_(r[4]), zaman: r[5] };
  });
  EKIP_ = m;
  return m;
}

/**
 * Araç ve makine kullanan görevler (Personel_Listesi → Görev). Güvenlik,
 * veteriner, raporlama, kalite, mühendis, uzman ve müdür kadroları dahil edilmez;
 * gerekirse Roller sayfasından tek tek eklenir ya da 'Hariç' ile çıkarılır.
 */
function aracPersoneli_(gorev) {
  var g = buyuk_(gorev);
  var haric = ['GÜVENLİK', 'VETERİNER', 'RAPORLAMA', 'KALİTE', 'ZOOTEKNİST', 'MÜHENDİS', 'MÜDÜR', 'UZMAN', 'YÖN.'];
  for (var i = 0; i < haric.length; i++) if (g.indexOf(haric[i]) >= 0) return false;
  var dahil = ['PERSONEL', 'OPERATÖR', 'FORMEN', 'ŞEF', 'BAKIM', 'ONARIM', 'USTA', 'TAMİR', 'ATÖLYE', 'ŞOFÖR', 'SÜRÜCÜ'];
  for (var j = 0; j < dahil.length; j++) if (g.indexOf(dahil[j]) >= 0) return true;
  return false;
}

function roller_(telefon, p) {
  var set = {};
  var ciftlik = p ? p.birim : '';
  var e = ekipler_()[telefon];
  if (e && e.ciftlik) ciftlik = e.ciftlik;
  rollerSatirlari_().forEach(function (r) {
    if (tel_(r[0]) === telefon && bas_(r[2])) {
      bas_(r[2]).split(',').forEach(function (x) {
        if (bas_(x) && buyuk_(x).indexOf('HARİÇ') < 0) set[bas_(x)] = true;
      });
      if (bas_(r[3])) ciftlik = bas_(r[3]);
    }
  });
  if (p) {
    var g = buyuk_(p.gorev);
    if (g.indexOf('FORMEN') >= 0 || g.indexOf('ŞEF') >= 0) set[ROL_FORMEN] = true;
    if (g.indexOf('BAKIM') >= 0 || g.indexOf('ATÖLYE') >= 0 || g.indexOf('TAMİR') >= 0) set[ROL_BAKIM] = true;
  }
  return { roller: Object.keys(set), ciftlik: ciftlik };
}

function yetki_(k, rol) {
  if (k.roller.indexOf(ROL_YONETICI) >= 0) return true;
  if (rol === 'sorumlu') return k.roller.indexOf(ROL_SORUMLU) >= 0 || k.roller.indexOf(ROL_BAKIM) >= 0;
  if (rol === 'formen') return k.roller.indexOf(ROL_FORMEN) >= 0;
  return false;
}
function tumCiftlikler_(k) {
  return k.roller.indexOf(ROL_YONETICI) >= 0 || k.ciftlik === 'Tümü';
}
function ayniCiftlik_(k, ciftlik) { return tumCiftlikler_(k) || bas_(ciftlik) === k.ciftlik; }

/**
 * Formenin bir personelden sorumlu olup olmadığı: personel bir formene
 * bağlıysa yalnız o formen; bağlı değilse aynı çiftliğin formenleri.
 * kayitFormen: kaydın açıldığı andaki sorumlu formen (varsa öncelikli).
 */
function sorumlu_(k, telefon, ciftlik, kayitFormen) {
  if (tumCiftlikler_(k)) return true;
  var f = tel_(kayitFormen);
  if (f) return f === k.telefon;
  var e = ekipler_()[tel_(telefon)];
  if (e && e.formen) return e.formen === k.telefon;
  return ayniCiftlik_(k, ciftlik);
}

function kisiOzeti_(k) {
  return { ad: k.ad, telefon: k.telefon, gorev: k.gorev, ciftlik: k.ciftlik, roller: k.roller };
}

function giris_(g) {
  var telefon = tel_(g.telefon);
  var pin = bas_(g.pin);
  var cihaz = bas_(g.cihazId);
  if (!telefon) return { ok: false, hata: 'Telefon numarasını 05xx xxx xx xx biçiminde yazın.' };
  if (!/^\d{4}$/.test(pin)) return { ok: false, hata: 'PIN 4 haneli olmalı.' };
  if (!cihaz) return { ok: false, hata: 'Cihaz kimliği alınamadı.' };
  var p = personeller_()[telefon];
  var r = roller_(telefon, p);
  if (!p && r.roller.length === 0) {
    return { ok: false, hata: 'Bu numara personel listesinde yok. Makine-Ekipman Sorumlusuna başvurun.' };
  }
  var ad = p ? p.ad : bas_(g.adSoyad) || telefon;
  var pinOz = ozet_(telefon + ':' + pin);
  var t = tablo_('Cihazlar');
  var satir = -1, kayit = null;
  t.rows.forEach(function (row, i) { if (tel_(row[0]) === telefon) { satir = i + 2; kayit = row; } });
  var oturum = Utilities.getUuid();
  // Hiçbir cihaz otomatik onaylanmaz. Yöneticinin cihazı, tablo sahibince
  // Cihazlar sayfasında Durum = Onaylı yazılarak onaylanır.
  var otomatik = false;
  var pr = PropertiesService.getScriptProperties();
  var hataAnahtari = 'pinHata_' + telefon;
  if (!kayit) {
    var durum = otomatik ? 'Onaylı' : 'Bekliyor';
    ekle_('Cihazlar', [telefon, ad, cihaz, bas_(g.cihazAdi), oturum, pinOz, durum,
      otomatik ? 'Otomatik (Yönetici)' : '', simdi_(), otomatik ? simdi_() : '']);
    if (!otomatik) cihazBildir_(telefon, ad, r.ciftlik);
    return { ok: true, oturum: oturum, durum: durum, kisi: { ad: ad, telefon: telefon, ciftlik: r.ciftlik, roller: r.roller } };
  }
  if (kayit[6] === 'Kilitli') {
    return { ok: false, hata: 'Hesap, hatalı PIN denemeleri nedeniyle kilitlendi. PIN sıfırlama için formeninize başvurun.' };
  }
  if (kayit[5] && kayit[5] !== pinOz) {
    var sayi = Number(pr.getProperty(hataAnahtari) || 0) + 1;
    pr.setProperty(hataAnahtari, String(sayi));
    if (sayi >= PIN_DENEME_SINIRI) {
      hucre_('Cihazlar', satir, 'Durum', 'Kilitli');
      hucre_('Cihazlar', satir, 'Oturum Anahtarı', '');
      return { ok: false, hata: 'Hatalı PIN sınırı aşıldı; hesap kilitlendi. PIN sıfırlama için formeninize başvurun.' };
    }
    return { ok: false, hata: 'PIN hatalı. Kalan deneme hakkı: ' + (PIN_DENEME_SINIRI - sayi) + '.' };
  }
  pr.deleteProperty(hataAnahtari);
  var ayniCihaz = bas_(kayit[2]) === cihaz;
  var yeniDurum = (ayniCihaz && kayit[6] === 'Onaylı') || otomatik ? 'Onaylı' : 'Bekliyor';
  hucre_('Cihazlar', satir, 'Cihaz Kimliği', cihaz);
  hucre_('Cihazlar', satir, 'Cihaz Adı', bas_(g.cihazAdi));
  hucre_('Cihazlar', satir, 'Oturum Anahtarı', oturum);
  hucre_('Cihazlar', satir, 'PIN Özeti', pinOz);
  if (yeniDurum !== kayit[6] || !ayniCihaz) {
    hucre_('Cihazlar', satir, 'Durum', yeniDurum);
    hucre_('Cihazlar', satir, 'Talep Zamanı', simdi_());
    if (yeniDurum === 'Bekliyor') cihazBildir_(telefon, ad, r.ciftlik);
  }
  return { ok: true, oturum: oturum, durum: yeniDurum, kisi: { ad: ad, telefon: telefon, ciftlik: r.ciftlik, roller: r.roller } };
}

function oturum_(anahtar) {
  anahtar = bas_(anahtar);
  if (!anahtar) return null;
  var t = tablo_('Cihazlar');
  for (var i = 0; i < t.rows.length; i++) {
    var row = t.rows[i];
    if (bas_(row[4]) === anahtar) {
      var telefon = tel_(row[0]);
      var p = personeller_()[telefon];
      var r = roller_(telefon, p);
      // Personel listesinden çıkarılan (işten ayrılan) kişinin erişimi kapanır.
      if (!p && r.roller.length === 0) return null;
      return {
        satir: i + 2, telefon: telefon, ad: p ? p.ad : bas_(row[1]), gorev: p ? p.gorev : '',
        ciftlik: r.ciftlik, roller: r.roller, cihazDurum: bas_(row[6])
      };
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Bildirim

function bildir_(telefonlar, tur, baslik, metin) {
  var gorulen = {};
  telefonlar.forEach(function (t) {
    t = tel_(t);
    if (!t || gorulen[t]) return;
    gorulen[t] = true;
    ekle_('Bildirimler', [simdi_(), t, tur, baslik, metin, '']);
  });
  var webhook = PropertiesService.getScriptProperties().getProperty('CHAT_WEBHOOK');
  if (webhook && (tur === 'Arıza' || tur === 'Arıza durumu')) {
    try {
      UrlFetchApp.fetch(webhook, {
        method: 'post', contentType: 'application/json; charset=UTF-8',
        payload: JSON.stringify({ text: '*' + baslik + '*\n' + metin }), muteHttpExceptions: true
      });
    } catch (e) {}
  }
}

/** Belirli rol(ler)deki ve çiftlikteki kişilerin telefonları. */
function rolTelefonlari_(roller, ciftlik) {
  var sonuc = [];
  var pl = personeller_();
  var adaylar = {};
  Object.keys(pl).forEach(function (t) { adaylar[t] = pl[t]; });
  rollerSatirlari_().forEach(function (r) { var t = tel_(r[0]); if (t && !adaylar[t]) adaylar[t] = null; });
  Object.keys(adaylar).forEach(function (t) {
    var r = roller_(t, adaylar[t]);
    var rolVar = roller.some(function (x) { return r.roller.indexOf(x) >= 0; });
    var ciftlikUyar = !ciftlik || r.ciftlik === ciftlik || r.ciftlik === 'Tümü' || r.roller.indexOf(ROL_YONETICI) >= 0;
    if (rolVar && ciftlikUyar) sonuc.push(t);
  });
  return sonuc;
}

function cihazBildir_(telefon, ad, ciftlik) {
  var e = ekipler_()[tel_(telefon)];
  var alicilar = e && e.formen ? [e.formen] : rolTelefonlari_([ROL_FORMEN], ciftlik);
  bildir_(alicilar.concat(rolTelefonlari_([ROL_SORUMLU], ciftlik)), 'Cihaz onayı',
    'Cihaz onayı bekleniyor', ad + ' (' + telefon + ') uygulamaya giriş yaptı; cihazının onaylanması gerekiyor.');
}

// ---------------------------------------------------------------------------
// Veri

function araclar_() {
  return tablo_('Araçlar').rows.filter(function (r) { return bas_(r[0]); }).map(function (r) {
    return { no: r[0], tur: r[1], model: r[2], plaka: r[3], ciftlik: r[4], sayac: sayi_(r[5]),
      durum: r[6] || 'Aktif', yil: r[7], not: r[8], sinif: r[12] || SINIF_ARAC };
  });
}

function kullanimNesne_(r, i) {
  return { satir: i + 2, no: r[0], tarih: r[1], arac: r[2], personel: r[3], telefon: r[4], ciftlik: r[5],
    baslangic: r[6], bitis: r[7], sayac1: sayi_(r[8]), sayac2: sayi_(r[9]), saat: sayi_(r[10]), is: r[11],
    gresleme: r[12], hava: r[13], yag: r[14], radyator: r[15], not: r[16], durum: r[17],
    onaylayan: r[18], onayZamani: r[19], sekil: r[20], formen: r[21] || '',
    ekipman: bas_(r[22]) ? bas_(r[22]).split(/\s*,\s*/) : [] };
}

function bakimUyarilari_(araclar) {
  var plan = tablo_('Bakım_Plan').rows;
  var sonuc = [];
  araclar.forEach(function (a) {
    if (a.durum === 'Pasif') return;
    plan.filter(function (p) { return p[0] === a.no; }).forEach(function (p) {
      var periyot = sayi_(p[2]);
      var son = sayi_(p[3]);
      if (!periyot || a.sayac == null) return;
      var kalan = (son || 0) + periyot - a.sayac;
      if (kalan <= Math.max(25, periyot * 0.1)) {
        sonuc.push({ arac: a.no, tur: a.tur, model: a.model, ciftlik: a.ciftlik, bakim: p[1],
          periyot: periyot, son: son, sayac: a.sayac, kalan: Math.round(kalan),
          durum: kalan < 0 ? 'Gecikti' : 'Yaklaşıyor' });
      }
    });
  });
  sonuc.sort(function (x, y) { return x.kalan - y.kalan; });
  return sonuc;
}

function veri_(k) {
  var araclar = araclar_();
  var kul = tablo_('Kullanım').rows.map(kullanimNesne_);
  // Personelin araç kullanım sıklığı: sık kullanılan araç listenin başında.
  var sayim = {};
  kul.forEach(function (x) {
    if (x.telefon !== k.telefon) return;
    [x.arac].concat(x.ekipman).forEach(function (n) { sayim[n] = (sayim[n] || 0) + 1; });
  });
  araclar.forEach(function (a) { a.kullanim = sayim[a.no] || 0; });
  var acik = kul.filter(function (x) { return x.telefon === k.telefon && x.durum === 'Devam ediyor'; });
  var benim = kul.filter(function (x) { return x.telefon === k.telefon; }).slice(-30).reverse();
  var aktif = kul.filter(function (x) { return x.durum === 'Devam ediyor' && ayniCiftlik_(k, x.ciftlik); });
  var bildirim = tablo_('Bildirimler').rows
    .filter(function (r) { return tel_(r[1]) === k.telefon; }).slice(-40).reverse()
    .map(function (r) { return { zaman: r[0], tur: r[2], baslik: r[3], metin: r[4], okundu: r[5] === 'Evet' }; });
  var arizalar = tablo_('Arıza').rows.map(function (r, i) {
    return { satir: i + 2, no: r[0], zaman: r[1], arac: r[2], bildiren: r[3], telefon: r[4], ciftlik: r[5],
      aciklama: r[6], foto: r[7], durum: r[8], guncelleyen: r[9], guncelleme: r[10], not: r[11], kapanis: r[12],
      yer: r[13] || SINIF_ARAC, birlikte: r[14] || '' };
  });
  var o = {
    ok: true, durum: 'Onaylı', kisi: kisiOzeti_(k), zaman: simdi_(),
    araclar: araclar, acikIs: acik.length ? acik[acik.length - 1] : null, benim: benim, aktif: aktif,
    bildirimler: bildirim,
    arizalarim: arizalar.filter(function (a) { return a.telefon === k.telefon; }).slice(-10).reverse(),
    ciftlikler: ciftlikler_(),
    isEmirlerim: isEmirleri_().filter(function (e) {
      return e.telefon === k.telefon && (e.durum === 'Verildi' || e.durum === 'Başladı') && gunFarki_(e.tarih) >= -1;
    }).reverse(),
    yerler: yerOnerileri_()
  };
  if (yetki_(k, 'formen')) {
    o.onayBekleyen = kul.filter(function (x) {
      return (x.durum === 'Tamamlandı' || x.durum === 'Devam ediyor') &&
        sorumlu_(k, x.telefon, roller_(tel_(x.telefon), personeller_()[tel_(x.telefon)]).ciftlik, x.formen);
    }).reverse();
    o.cihazBekleyen = tablo_('Cihazlar').rows.map(function (r, i) {
      var t = tel_(r[0]); var p = personeller_()[t];
      return { telefon: t, ad: r[1], cihaz: r[3], durum: r[6], talep: r[8], ciftlik: roller_(t, p).ciftlik };
    }).filter(function (c) { return (c.durum === 'Bekliyor' || c.durum === 'Kilitli') && sorumlu_(k, c.telefon, c.ciftlik); });
    var ek = ekipVerisi_(k);
    o.ekibim = ek.ekibim;
    o.atanabilir = ek.atanabilir;
    o.formenler = ek.formenler;
    o.verdigimEmirler = isEmirleri_().filter(function (e) {
      return (e.formen === k.telefon || tumCiftlikler_(k)) && gunFarki_(e.tarih) <= 3 && gunFarki_(e.tarih) >= -2;
    }).reverse().slice(0, 150);
  }
  if (yetki_(k, 'sorumlu') || yetki_(k, 'formen')) {
    o.arizalar = arizalar.filter(function (a) { return ayniCiftlik_(k, a.ciftlik); }).reverse();
    o.bakimUyari = bakimUyarilari_(araclar.filter(function (a) { return ayniCiftlik_(k, a.ciftlik); }));
  }
  if (yetki_(k, 'sorumlu')) {
    o.plan = tablo_('Bakım_Plan').rows.map(function (r) {
      return { arac: r[0], bakim: r[1], periyot: sayi_(r[2]), son: sayi_(r[3]), sonTarih: r[4] };
    });
    o.bakimKayit = tablo_('Bakım_Kayıt').rows.slice(-200).reverse().map(function (r) {
      return { no: r[0], tarih: r[1], arac: r[2], kayitTuru: r[3], bakim: r[4], sayac: sayi_(r[5]),
        is: r[6], parca: r[7], firma: r[8], tutar: r[9], belge: r[10], giren: r[11] };
    });
  }
  return o;
}

function ciftlikler_() {
  var set = {};
  var pl = personeller_();
  Object.keys(pl).forEach(function (t) { if (pl[t].birim) set[pl[t].birim] = true; });
  return Object.keys(set).sort();
}

function aracBul_(no) {
  var t = tablo_('Araçlar');
  for (var i = 0; i < t.rows.length; i++) if (t.rows[i][0] === no) return { satir: i + 2, row: t.rows[i] };
  return null;
}

// ---------------------------------------------------------------------------
// Operatör işlemleri

function isBaslat_(k, g) {
  var a = aracBul_(bas_(g.arac));
  if (!a) return { ok: false, hata: 'Araç bulunamadı.' };
  if (a.row[6] === 'Arızalı') {
    if (!g.arizaliOnay) return { ok: false, arizali: true, hata: 'Bu araç arızalı olarak kayıtlı. Kullanılmaması gerekir.' };
  }
  if ((a.row[12] || SINIF_ARAC) === SINIF_EKIPMAN) return { ok: false, hata: a.row[0] + ' bir makine-ekipman; önce aracı seçin.' };
  var ekipman = [];
  var ekipArizali = [];
  var istenen = Array.isArray(g.ekipman) ? g.ekipman : [];
  for (var i = 0; i < istenen.length; i++) {
    var e = aracBul_(bas_(istenen[i]));
    if (!e) return { ok: false, hata: 'Makine-ekipman bulunamadı: ' + istenen[i] };
    ekipman.push(e.row[0]);
    if (e.row[6] === 'Arızalı') ekipArizali.push(e.row[0]);
  }
  if (ekipArizali.length && !g.arizaliOnay) {
    return { ok: false, arizali: true, hata: 'Arızalı kayıtlı makine-ekipman: ' + ekipArizali.join(', ') + '. Kullanılmaması gerekir.' };
  }
  var kul = tablo_('Kullanım').rows.map(kullanimNesne_);
  if (kul.some(function (x) { return x.telefon === k.telefon && x.durum === 'Devam ediyor'; })) {
    return { ok: false, hata: 'Devam eden bir işiniz var. Önce onu bitirin.' };
  }
  var baska = kul.filter(function (x) { return x.arac === a.row[0] && x.durum === 'Devam ediyor'; });
  var sayac = sayi_(g.sayac);
  var no = yeniNo_('Kullanım', 'K');
  ekle_('Kullanım', [no, bugun_(), a.row[0], k.ad, k.telefon, a.row[4], simdi_(), '',
    sayac == null ? '' : sayac, '', '', bas_(g.is), '', '', '', '', bas_(g.not), 'Devam ediyor', '', '', 'Personel', formenOf_(k.telefon), ekipman.join(', ')]);
  if (sayac != null && (sayi_(a.row[5]) || 0) < sayac) hucre_('Araçlar', a.satir, 'Motor Saati', sayac);
  var uyari = baska.length ? 'Bu araç sistemde ' + baska[0].personel + ' adına açık görünüyor; formen akşam düzeltecek.' : '';
  if (bas_(g.emirNo)) {
    var em = isEmriBul_(bas_(g.emirNo));
    if (em && em.e.telefon === k.telefon) {
      hucre_('İş_Emirleri', em.satir, 'Durum', 'Başladı');
      hucre_('İş_Emirleri', em.satir, 'Kullanım Kayıt No', no);
      hucre_('İş_Emirleri', em.satir, 'Güncelleme', simdi_());
      if (em.e.arac && em.e.arac !== a.row[0]) {
        hucre_('Kullanım', ss_().getSheetByName('Kullanım').getLastRow(), 'Not',
          [bas_(g.not), 'İş emrinde ' + em.e.arac + ' öngörülmüştü'].filter(String).join(' | '));
      }
    }
  }
  ekipman.forEach(function (n) {
    var d = kul.filter(function (x) { return x.durum === 'Devam ediyor' && x.ekipman.indexOf(n) >= 0; })[0];
    if (d) uyari += (uyari ? ' ' : '') + n + ' sistemde ' + d.personel + ' adına açık görünüyor.';
  });
  return { ok: true, no: no, uyari: uyari };
}

function isBitir_(k, g) {
  var t = tablo_('Kullanım');
  var satir = -1, row = null;
  t.rows.forEach(function (r, i) { if (r[0] === bas_(g.no)) { satir = i + 2; row = r; } });
  if (!row) return { ok: false, hata: 'Kayıt bulunamadı.' };
  if (tel_(row[4]) !== k.telefon && !yetki_(k, 'formen')) return { ok: false, hata: 'Bu kayıt size ait değil.' };
  var s1 = sayi_(row[8]);
  var s2 = sayi_(g.sayac);
  if (s2 != null && s1 != null && s2 < s1) return { ok: false, hata: 'Bitiş sayacı başlangıçtan küçük olamaz (' + s1 + ').' };
  var evet = function (b) { return b ? 'Yapıldı' : 'Yapılmadı'; };
  hucre_('Kullanım', satir, 'Bitiş', simdi_());
  hucre_('Kullanım', satir, 'Bitiş Sayacı', s2 == null ? '' : s2);
  hucre_('Kullanım', satir, 'Çalışma (saat)', s1 != null && s2 != null ? Math.round((s2 - s1) * 10) / 10 : '');
  hucre_('Kullanım', satir, 'Gresleme', evet(g.gresleme));
  hucre_('Kullanım', satir, 'Hava Filtresi', evet(g.hava));
  hucre_('Kullanım', satir, 'Motor Yağı', evet(g.yag));
  hucre_('Kullanım', satir, 'Radyatör', evet(g.radyator));
  if (bas_(g.not)) hucre_('Kullanım', satir, 'Not', [row[16], bas_(g.not)].filter(String).join(' | '));
  hucre_('Kullanım', satir, 'Durum', 'Tamamlandı');
  isEmirleri_().forEach(function (e, i) {
    if (e.kullanim === row[0] && e.durum === 'Başladı') {
      hucre_('İş_Emirleri', e.satir, 'Durum', 'Tamamlandı');
      hucre_('İş_Emirleri', e.satir, 'Güncelleme', simdi_());
    }
  });
  var a = aracBul_(row[2]);
  if (a && s2 != null && (sayi_(a.row[5]) || 0) < s2) {
    hucre_('Araçlar', a.satir, 'Motor Saati', s2);
    hucre_('Araçlar', a.satir, 'Güncelleme', simdi_());
  }
  // Bağlı makine-ekipmanın çalışma saati aracın çalışma süresi kadar artar.
  var calisma = s1 != null && s2 != null ? Math.round((s2 - s1) * 10) / 10 : null;
  if (calisma != null && calisma > 0 && bas_(row[22])) {
    bas_(row[22]).split(/\s*,\s*/).forEach(function (n) {
      var e = aracBul_(n);
      if (!e) return;
      hucre_('Araçlar', e.satir, 'Motor Saati', Math.round(((sayi_(e.row[5]) || 0) + calisma) * 10) / 10);
      hucre_('Araçlar', e.satir, 'Güncelleme', simdi_());
    });
  }
  var eksik = !(g.gresleme && g.hava && g.yag && g.radyator);
  return { ok: true, eksik: eksik };
}

function ariza_(k, g) {
  var a = aracBul_(bas_(g.arac));
  if (!a) return { ok: false, hata: 'Araç ya da makine-ekipman bulunamadı.' };
  var aciklama = bas_(g.aciklama);
  if (!aciklama && !g.foto) return { ok: false, hata: 'Kısa bir açıklama yazın ya da fotoğraf ekleyin.' };
  var no = yeniNo_('Arıza', 'A');
  var link = '';
  if (g.foto) {
    var blob = Utilities.newBlob(Utilities.base64Decode(g.foto), 'image/jpeg', no + '_' + a.row[0] + '.jpg');
    var f = DriveApp.getFolderById(FOTO_KLASOR_ID).createFile(blob);
    link = f.getUrl();
  }
  var yer = a.row[12] || SINIF_ARAC;
  ekle_('Arıza', [no, simdi_(), a.row[0], k.ad, k.telefon, a.row[4], aciklama, link, 'Bildirildi', k.ad, simdi_(), '', '',
    yer, bas_(g.birlikte)]);
  hucre_('Araçlar', a.satir, 'Durum', 'Arızalı');
  hucre_('Araçlar', a.satir, 'Güncelleme', simdi_());
  var arac = a.row[0] + ' (' + [a.row[1], a.row[2]].filter(String).join(' ') + ')';
  var formen = formenOf_(k.telefon);
  bildir_(rolTelefonlari_([ROL_FORMEN, ROL_BAKIM, ROL_SORUMLU], a.row[4]).concat(formen ? [formen] : []), 'Arıza',
    'Arıza bildirimi (' + (yer === SINIF_EKIPMAN ? 'makine-ekipman' : 'araç') + '): ' + arac +
      (bas_(g.birlikte) ? ' – birlikte: ' + bas_(g.birlikte) : ''), k.ad + ' – ' + simdi_() + '\n' + (aciklama || 'Fotoğraflı bildirim') + (link ? '\n' + link : ''));
  return { ok: true, no: no };
}

// ---------------------------------------------------------------------------
// Formen işlemleri

function onayla_(k, g) {
  if (!yetki_(k, 'formen')) return { ok: false, hata: 'Bu işlem için formen yetkisi gerekir.' };
  var t = tablo_('Kullanım');
  var istenen = {};
  (g.nolar || []).forEach(function (n) { istenen[n] = true; });
  var say = 0;
  t.rows.forEach(function (r, i) {
    if (istenen[r[0]] && r[17] === 'Tamamlandı' &&
        sorumlu_(k, r[4], roller_(tel_(r[4]), personeller_()[tel_(r[4])]).ciftlik, r[21])) {
      hucre_('Kullanım', i + 2, 'Durum', 'Onaylandı');
      hucre_('Kullanım', i + 2, 'Onaylayan', k.ad);
      hucre_('Kullanım', i + 2, 'Onay Zamanı', simdi_());
      say++;
    }
  });
  return { ok: true, sayi: say };
}

/** Formen düzeltmesi: personel, araç, sayaçlar, bakım kontrolü; ya da personel yerine yeni kayıt. */
function kayitDuzelt_(k, g) {
  if (!yetki_(k, 'formen')) return { ok: false, hata: 'Bu işlem için formen yetkisi gerekir.' };
  var d = g.kayit || {};
  var kisi = null;
  if (d.telefon) {
    var t0 = tel_(d.telefon);
    var p = personeller_()[t0];
    if (!p) return { ok: false, hata: 'Personel bulunamadı: ' + d.telefon };
    kisi = { telefon: t0, ad: p.ad };
  }
  var a = d.arac ? aracBul_(bas_(d.arac)) : null;
  if (d.arac && !a) return { ok: false, hata: 'Araç bulunamadı.' };
  var s1 = sayi_(d.sayac1), s2 = sayi_(d.sayac2);
  var saat = s1 != null && s2 != null ? Math.round((s2 - s1) * 10) / 10 : '';
  var evet = function (b) { return b ? 'Yapıldı' : 'Yapılmadı'; };
  if (!d.no) {
    if (!kisi || !a) return { ok: false, hata: 'Personel ve araç seçin.' };
    var no = yeniNo_('Kullanım', 'K');
    ekle_('Kullanım', [no, bas_(d.tarih) || bugun_(), a.row[0], kisi.ad, kisi.telefon, a.row[4],
      bas_(d.baslangic), bas_(d.bitis), s1 == null ? '' : s1, s2 == null ? '' : s2, saat, bas_(d.is),
      evet(d.gresleme), evet(d.hava), evet(d.yag), evet(d.radyator), bas_(d.not), 'Onaylandı', k.ad, simdi_(),
      'Formen girişi', formenOf_(kisi.telefon) || k.telefon]);
    return { ok: true, no: no };
  }
  var tb = tablo_('Kullanım');
  var satir = -1;
  tb.rows.forEach(function (r, i) { if (r[0] === d.no) satir = i + 2; });
  if (satir < 0) return { ok: false, hata: 'Kayıt bulunamadı.' };
  if (kisi) { hucre_('Kullanım', satir, 'Personel', kisi.ad); hucre_('Kullanım', satir, 'Telefon', kisi.telefon); }
  if (a) { hucre_('Kullanım', satir, 'Araç No', a.row[0]); hucre_('Kullanım', satir, 'Çiftlik', a.row[4]); }
  if (s1 != null) hucre_('Kullanım', satir, 'Başlangıç Sayacı', s1);
  if (s2 != null) hucre_('Kullanım', satir, 'Bitiş Sayacı', s2);
  if (saat !== '') hucre_('Kullanım', satir, 'Çalışma (saat)', saat);
  ['gresleme', 'hava', 'yag', 'radyator'].forEach(function (x, j) {
    if (d[x] != null) hucre_('Kullanım', satir, ['Gresleme', 'Hava Filtresi', 'Motor Yağı', 'Radyatör'][j], evet(d[x]));
  });
  if (d.bitis) hucre_('Kullanım', satir, 'Bitiş', bas_(d.bitis));
  var eskiNot = tb.rows[satir - 2][16];
  hucre_('Kullanım', satir, 'Not', [eskiNot, 'Formen düzeltmesi (' + k.ad + ', ' + simdi_() + ')' + (d.not ? ': ' + d.not : '')].filter(String).join(' | '));
  hucre_('Kullanım', satir, 'Durum', 'Onaylandı');
  hucre_('Kullanım', satir, 'Onaylayan', k.ad);
  hucre_('Kullanım', satir, 'Onay Zamanı', simdi_());
  return { ok: true, no: d.no };
}

function cihazOnay_(k, g) {
  if (!yetki_(k, 'formen') && !yetki_(k, 'sorumlu')) return { ok: false, hata: 'Yetkiniz yok.' };
  var t = tablo_('Cihazlar');
  var hedef = tel_(g.telefon);
  for (var i = 0; i < t.rows.length; i++) {
    if (tel_(t.rows[i][0]) === hedef) {
      var durum = g.onay ? 'Onaylı' : 'Reddedildi';
      if (g.sifirla) {
        PropertiesService.getScriptProperties().deleteProperty('pinHata_' + hedef);
        hucre_('Cihazlar', i + 2, 'PIN Özeti', '');
        hucre_('Cihazlar', i + 2, 'Oturum Anahtarı', '');
        durum = 'Bekliyor';
      }
      hucre_('Cihazlar', i + 2, 'Durum', durum);
      hucre_('Cihazlar', i + 2, 'Onaylayan', k.ad);
      hucre_('Cihazlar', i + 2, 'Onay Zamanı', simdi_());
      return { ok: true };
    }
  }
  return { ok: false, hata: 'Kayıt bulunamadı.' };
}

// ---------------------------------------------------------------------------
// Ekip (formen–personel bağı) ve çiftlikler arası görevlendirme

function formenOf_(telefon) {
  var e = ekipler_()[tel_(telefon)];
  return e && e.formen ? e.formen : '';
}

function formenListesi_() {
  return rolTelefonlari_([ROL_FORMEN], '').map(function (t) {
    var p = personeller_()[t];
    var r = roller_(t, p);
    if (r.roller.indexOf(ROL_FORMEN) < 0) return null; // yalnız Yönetici olanlar formen listesine girmez
    return { telefon: t, ad: p ? p.ad : t, ciftlik: r.ciftlik };
  }).filter(Boolean).sort(function (a, b) { return a.ad.localeCompare(b.ad, 'tr'); });
}

function ekipVerisi_(k) {
  var pl = personeller_();
  var ek = ekipler_();
  var tum = tumCiftlikler_(k);
  var kisi = function (t) {
    var p = pl[t]; var e = ek[t] || {};
    return { telefon: t, ad: p.ad, gorev: p.gorev, ciftlik: roller_(t, p).ciftlik,
      formen: e.formen || '', formenAd: e.formenAd || '', zaman: e.zaman || '' };
  };
  var ekibim = [], atanabilir = [];
  Object.keys(pl).forEach(function (t) {
    if (t === k.telefon) return;
    var e = ek[t];
    if (e && e.formen === k.telefon) ekibim.push(kisi(t));
    else if (tum || !e || !e.formen) atanabilir.push(kisi(t));
  });
  var sirala = function (a, b) { return a.ad.localeCompare(b.ad, 'tr'); };
  return { ekibim: ekibim.sort(sirala), atanabilir: atanabilir.sort(sirala), formenler: formenListesi_() };
}

/**
 * Personeli bir formenin ekibine bağlar ya da ekipten çıkarır (formen boş).
 * Formen: kendi ekibindeki personeli başka formene görevlendirebilir, hiçbir
 * ekibe bağlı olmayan personeli kendi ekibine alabilir. Yönetici her işlemi yapar.
 */
function ekipAta_(k, g) {
  if (!yetki_(k, 'formen')) return { ok: false, hata: 'Bu işlem için formen yetkisi gerekir.' };
  var hedef = tel_(g.telefon);
  var p = personeller_()[hedef];
  if (!p) return { ok: false, hata: 'Personel listesinde bulunamadı.' };
  var yeni = tel_(g.formen);
  var formenler = formenListesi_();
  var yf = null;
  if (yeni) {
    yf = formenler.filter(function (f) { return f.telefon === yeni; })[0];
    if (!yf) return { ok: false, hata: 'Seçilen kişi formen olarak tanımlı değil.' };
  }
  var e = ekipler_()[hedef];
  var eski = e && e.formen ? e.formen : '';
  if (!tumCiftlikler_(k) && eski && eski !== k.telefon) {
    return { ok: false, hata: p.ad + ' başka bir formenin ekibinde (' + e.formenAd + '). Görevlendirmeyi o formen yapabilir.' };
  }
  if (!tumCiftlikler_(k) && !eski && yeni !== k.telefon) {
    return { ok: false, hata: 'Ekibe bağlı olmayan personeli yalnız kendi ekibinize alabilirsiniz.' };
  }
  if (eski === yeni) return { ok: true };
  var ciftlik = yf ? yf.ciftlik : p.birim;
  var satir = [hedef, p.ad, yeni, yf ? yf.ad : '', ciftlik, simdi_(), k.ad];
  var t = tablo_('Ekipler');
  var bulundu = -1;
  t.rows.forEach(function (r, i) { if (tel_(r[0]) === hedef) bulundu = i + 2; });
  if (bulundu > 0) {
    t.sh.getRange(bulundu, 1, 1, satir.length).setValues([satir.map(String)]);
  } else {
    ekle_('Ekipler', satir);
  }
  EKIP_ = null;
  var eskiAd = e && e.formenAd ? e.formenAd : '';
  ekle_('Görevlendirme_Geçmişi', [simdi_(), hedef, p.ad, eskiAd, yf ? yf.ad : 'Ekipten çıkarıldı', ciftlik, k.ad]);
  var metin = yf
    ? p.ad + ', ' + yf.ad + ' ekibine görevlendirildi (' + ciftlik + ').'
    : p.ad + ', ' + (eskiAd || 'formen') + ' ekibinden çıkarıldı.';
  bildir_([eski, yeni].filter(function (x) { return x && x !== k.telefon; }), 'Görevlendirme', 'Ekip değişikliği', metin);
  if (yf) bildir_([hedef], 'Görevlendirme', 'Yeni görevlendirme',
    yf.ad + ' ekibine görevlendirildiniz (' + ciftlik + '). Araç kayıtlarınızı bundan sonra bu formen onaylayacak.');
  return { ok: true };
}

/**
 * Telefonun arka planda (yaklaşık 15 dakikada bir) sorduğu yeni bildirimler.
 * son: telefonun daha önce gördüğü bildirim satırı sayısı. İlk çağrıda (son boş) yalnız
 * güncel satır döner; eski bildirimler yeniden gösterilmez.
 */
function bildirimKontrol_(k, g) {
  var rows = tablo_('Bildirimler').rows;
  var enSon = rows.length; // görülen bildirim satırı sayısı
  var son = parseInt(g.son, 10);
  if (isNaN(son) || son < 0 || son > enSon) return { ok: true, son: enSon, yeni: [] };
  var yeni = [];
  for (var i = son; i < rows.length; i++) {
    var r = rows[i];
    if (tel_(r[1]) === k.telefon && r[5] !== 'Evet') yeni.push({ tur: r[2], baslik: r[3], metin: r[4] });
  }
  return { ok: true, son: enSon, yeni: yeni.slice(-10) };
}

// ---------------------------------------------------------------------------
// İş emirleri (formen → personel)

function gunFarki_(tarih) {
  var m = /^(\d{1,2})\.(\d{1,2})\.(\d{4})/.exec(bas_(tarih));
  if (!m) return 0;
  var t = new Date(+m[3], +m[2] - 1, +m[1]);
  var b = new Date(Utilities.formatDate(new Date(), TZ, 'yyyy/MM/dd'));
  return Math.round((b - t) / 86400000); // 0 bugün, 1 dün, -1 yarın
}

function isEmirleri_() {
  return tablo_('İş_Emirleri').rows.map(function (r, i) {
    return { satir: i + 2, no: r[0], tarih: r[1], telefon: tel_(r[2]), personel: r[3], formen: tel_(r[4]),
      formenAd: r[5], ciftlik: r[6], yerTuru: r[7], yer: r[8], is: r[9], arac: r[10],
      ekipman: bas_(r[11]) ? bas_(r[11]).split(/\s*,\s*/) : [], aciklama: r[12], durum: r[13],
      kullanim: r[14], olusturma: r[15], guncelleme: r[16] };
  }).filter(function (e) { return bas_(e.no); });
}

function isEmriBul_(no) {
  var l = isEmirleri_();
  for (var i = 0; i < l.length; i++) if (l[i].no === no) return { satir: l[i].satir, e: l[i] };
  return null;
}

/** Daha önce yazılmış yerler (tarla, parsel, ahır bölümü): formen seçim kolaylığı. */
function yerOnerileri_() {
  var say = {};
  isEmirleri_().slice(-500).forEach(function (e) {
    if (!bas_(e.yer)) return;
    var a = e.yerTuru + '|' + e.yer + '|' + e.ciftlik;
    say[a] = (say[a] || 0) + 1;
  });
  return Object.keys(say).sort(function (x, y) { return say[y] - say[x]; }).slice(0, 80).map(function (a) {
    var p = a.split('|');
    return { yerTuru: p[0], yer: p[1], ciftlik: p[2] };
  });
}

function isEmriVer_(k, g) {
  if (!yetki_(k, 'formen')) return { ok: false, hata: 'İş emrini formen verir.' };
  var d = g.emir || {};
  var kisiler = Array.isArray(d.personel) ? d.personel : [d.personel];
  if (!kisiler.filter(Boolean).length) return { ok: false, hata: 'Personel seçin.' };
  if (!bas_(d.is)) return { ok: false, hata: 'Yapılacak işi seçin.' };
  if (!bas_(d.yer)) return { ok: false, hata: 'Çalışılacak yeri yazın (tarla, parsel ya da ahır bölümü).' };
  var arac = bas_(d.arac) ? aracBul_(bas_(d.arac)) : null;
  if (bas_(d.arac) && !arac) return { ok: false, hata: 'Araç bulunamadı.' };
  var ekipman = (Array.isArray(d.ekipman) ? d.ekipman : []).map(bas_).filter(Boolean);
  for (var i = 0; i < ekipman.length; i++) if (!aracBul_(ekipman[i])) return { ok: false, hata: 'Makine-ekipman bulunamadı: ' + ekipman[i] };
  var tarih = bas_(d.tarih) || bugun_();
  var pl = personeller_();
  var verilen = [];
  for (var j = 0; j < kisiler.length; j++) {
    var t = tel_(kisiler[j]);
    var p = pl[t];
    if (!p) return { ok: false, hata: 'Personel listesinde yok: ' + kisiler[j] };
    if (!sorumlu_(k, t, roller_(t, p).ciftlik)) return { ok: false, hata: p.ad + ' sizin ekibinizde değil.' };
    var no = yeniNo_('İş_Emirleri', 'E');
    ekle_('İş_Emirleri', [no, tarih, t, p.ad, k.telefon, k.ad, roller_(t, p).ciftlik, bas_(d.yerTuru), bas_(d.yer),
      bas_(d.is), arac ? arac.row[0] : '', ekipman.join(', '), bas_(d.aciklama), 'Verildi', '', simdi_(), simdi_()]);
    var arAlt = [arac ? arac.row[0] + ' (' + [arac.row[1], arac.row[2]].filter(String).join(' ') + ')' : '',
      ekipman.join(', ')].filter(String).join(' + ');
    bildir_([t], 'İş emri', 'İş emri: ' + bas_(d.is) + ' – ' + bas_(d.yer),
      [tarih + (bas_(d.yerTuru) ? ' · ' + bas_(d.yerTuru) : '') + ' · ' + bas_(d.yer),
       arAlt ? 'Araç / makine: ' + arAlt : 'Araç gerekmiyor',
       bas_(d.aciklama), 'Veren: ' + k.ad].filter(String).join('\n'));
    verilen.push(no);
  }
  return { ok: true, nolar: verilen };
}

/** Personel: araçsız işi tamamlandı bildirir. Formen: iptal eder ya da tamamlandı işaretler. */
function isEmriDurum_(k, g) {
  var em = isEmriBul_(bas_(g.no));
  if (!em) return { ok: false, hata: 'İş emri bulunamadı.' };
  var e = em.e;
  var durum = bas_(g.durum);
  if (['Tamamlandı', 'İptal'].indexOf(durum) < 0) return { ok: false, hata: 'Geçersiz durum.' };
  var formenMi = yetki_(k, 'formen') && (e.formen === k.telefon || tumCiftlikler_(k));
  if (durum === 'İptal' && !formenMi) return { ok: false, hata: 'İş emrini yalnız veren formen iptal eder.' };
  if (durum === 'Tamamlandı' && !formenMi && e.telefon !== k.telefon) return { ok: false, hata: 'Bu iş emri size ait değil.' };
  hucre_('İş_Emirleri', em.satir, 'Durum', durum);
  hucre_('İş_Emirleri', em.satir, 'Güncelleme', simdi_());
  if (durum === 'İptal') bildir_([e.telefon], 'İş emri', 'İş emri iptal edildi', e.is + ' – ' + e.yer + ' (' + e.tarih + ')');
  if (durum === 'Tamamlandı' && e.telefon === k.telefon && e.formen) {
    bildir_([e.formen], 'İş emri', 'İş emri tamamlandı', e.personel + ': ' + e.is + ' – ' + e.yer);
  }
  return { ok: true };
}

// ---------------------------------------------------------------------------
// Makine-Ekipman Sorumlusu işlemleri

function aracKaydet_(k, g) {
  if (!yetki_(k, 'sorumlu')) return { ok: false, hata: 'Bu işlem Makine-Ekipman Sorumlusu yetkisi gerektirir.' };
  var d = g.arac || {};
  var no = buyuk_(d.no).replace(/\s+/g, ' ');
  var sinif = bas_(d.sinif) === SINIF_EKIPMAN ? SINIF_EKIPMAN : SINIF_ARAC;
  if (!no) return { ok: false, hata: 'Kayıt numarası (kısa ad) zorunlu. Örnek: TRK-07 ya da PLK-02' };
  if (!bas_(d.tur)) return { ok: false, hata: 'Türü seçin.' };
  if (!bas_(d.ciftlik)) return { ok: false, hata: 'Çiftliği seçin.' };
  var var_ = aracBul_(no);
  var sayac = sayi_(d.sayac);
  var satir = [no, bas_(d.tur), bas_(d.model), buyuk_(d.plaka), bas_(d.ciftlik), sayac == null ? '' : sayac,
    bas_(d.durum) || 'Aktif', bas_(d.yil), bas_(d.not)];
  if (var_) {
    if (d.yeni) return { ok: false, hata: no + ' numarası zaten kayıtlı.' };
    var sh = ss_().getSheetByName('Araçlar');
    sh.getRange(var_.satir, 1, 1, satir.length).setValues([satir.map(String)]);
    hucre_('Araçlar', var_.satir, 'Güncelleme', simdi_());
    hucre_('Araçlar', var_.satir, 'Sınıf', sinif);
  } else {
    ekle_('Araçlar', satir.concat([k.ad, simdi_(), simdi_(), sinif]));
    // Varsayılan periyodik bakım planı (sonradan düzenlenebilir).
    if (!tablo_('Bakım_Plan').rows.some(function (r) { return r[0] === no; })) {
      (sinif === SINIF_EKIPMAN ? VARSAYILAN_PLAN_EKIPMAN : VARSAYILAN_PLAN).forEach(function (p) { ekle_('Bakım_Plan', [no, p[0], p[1], sayac == null ? '' : sayac, bugun_()]); });
    }
  }
  if (bas_(d.durum) === 'Aktif' && var_ && var_.row[6] === 'Arızalı') {
    // Araç aktife alındıysa açık arızaları kapatma işi arıza ekranındadır; burada yalnız durum değişir.
  }
  return { ok: true, no: no };
}

function planKaydet_(k, g) {
  if (!yetki_(k, 'sorumlu')) return { ok: false, hata: 'Yetkiniz yok.' };
  var d = g.plan || {};
  var arac = bas_(d.arac), bakim = bas_(d.bakim);
  if (!arac || !bakim) return { ok: false, hata: 'Araç ve bakım türü zorunlu.' };
  var t = tablo_('Bakım_Plan');
  for (var i = 0; i < t.rows.length; i++) {
    if (t.rows[i][0] === arac && t.rows[i][1] === bakim) {
      if (d.sil) { ss_().getSheetByName('Bakım_Plan').deleteRow(i + 2); return { ok: true }; }
      hucre_('Bakım_Plan', i + 2, 'Periyot (saat)', sayi_(d.periyot));
      if (d.son != null) hucre_('Bakım_Plan', i + 2, 'Son Yapılan (saat)', sayi_(d.son));
      return { ok: true };
    }
  }
  ekle_('Bakım_Plan', [arac, bakim, sayi_(d.periyot), d.son == null ? '' : sayi_(d.son), '']);
  return { ok: true };
}

function bakimKaydet_(k, g) {
  if (!yetki_(k, 'sorumlu')) return { ok: false, hata: 'Bu işlem Makine-Ekipman Sorumlusu yetkisi gerektirir.' };
  var d = g.kayit || {};
  var a = aracBul_(bas_(d.arac));
  if (!a) return { ok: false, hata: 'Araç bulunamadı.' };
  if (!bas_(d.kayitTuru)) return { ok: false, hata: 'Kayıt türünü seçin.' };
  var sayac = sayi_(d.sayac);
  var no = yeniNo_('Bakım_Kayıt', 'B');
  ekle_('Bakım_Kayıt', [no, bas_(d.tarih) || bugun_(), a.row[0], bas_(d.kayitTuru), bas_(d.bakim),
    sayac == null ? '' : sayac, bas_(d.is), bas_(d.parca), bas_(d.firma), bas_(d.tutar), bas_(d.belge), k.ad, simdi_()]);
  // Periyodik bakımsa planın "son yapılan" bilgisi güncellenir.
  if (bas_(d.bakim)) {
    var t = tablo_('Bakım_Plan');
    t.rows.forEach(function (r, i) {
      if (r[0] === a.row[0] && r[1] === bas_(d.bakim) && sayac != null && (sayi_(r[3]) || 0) <= sayac) {
        hucre_('Bakım_Plan', i + 2, 'Son Yapılan (saat)', sayac);
        hucre_('Bakım_Plan', i + 2, 'Son Yapılan Tarih', bas_(d.tarih) || bugun_());
      }
    });
  }
  if (sayac != null && (sayi_(a.row[5]) || 0) < sayac) hucre_('Araçlar', a.satir, 'Motor Saati', sayac);
  if (d.arizaNo) arizaDurum_(k, { no: d.arizaNo, durum: 'Onarıldı', not: bas_(d.is) });
  return { ok: true, no: no };
}

function arizaDurum_(k, g) {
  if (!yetki_(k, 'sorumlu') && !yetki_(k, 'formen')) return { ok: false, hata: 'Yetkiniz yok.' };
  var gecerli = ['Bildirildi', 'Atölyede', 'Parça bekleniyor', 'Onarıldı', 'Geçersiz bildirim'];
  if (gecerli.indexOf(g.durum) < 0) return { ok: false, hata: 'Geçersiz durum.' };
  var t = tablo_('Arıza');
  for (var i = 0; i < t.rows.length; i++) {
    var r = t.rows[i];
    if (r[0] === bas_(g.no)) {
      hucre_('Arıza', i + 2, 'Durum', g.durum);
      hucre_('Arıza', i + 2, 'Son Güncelleyen', k.ad);
      hucre_('Arıza', i + 2, 'Son Güncelleme', simdi_());
      if (bas_(g.not)) hucre_('Arıza', i + 2, 'Onarım Notu', [r[11], bas_(g.not)].filter(String).join(' | '));
      var kapali = g.durum === 'Onarıldı' || g.durum === 'Geçersiz bildirim';
      if (kapali) hucre_('Arıza', i + 2, 'Kapanış Zamanı', simdi_());
      var a = aracBul_(r[2]);
      if (a) {
        var acikBaska = t.rows.some(function (x, j) {
          return j !== i && x[2] === r[2] && ['Onarıldı', 'Geçersiz bildirim'].indexOf(x[8]) < 0;
        });
        hucre_('Araçlar', a.satir, 'Durum', kapali && !acikBaska ? 'Aktif' : 'Arızalı');
      }
      bildir_([r[4]].concat(rolTelefonlari_([ROL_FORMEN], r[5])), 'Arıza durumu',
        'Arıza ' + r[0] + ' – ' + r[2] + ': ' + g.durum, (bas_(g.not) || '') + ' (' + k.ad + ')');
      return { ok: true };
    }
  }
  return { ok: false, hata: 'Arıza kaydı bulunamadı.' };
}

function bildirimOkundu_(k) {
  var t = tablo_('Bildirimler');
  t.rows.forEach(function (r, i) {
    if (tel_(r[1]) === k.telefon && r[5] !== 'Evet') hucre_('Bildirimler', i + 2, 'Okundu', 'Evet');
  });
  return { ok: true };
}

// ---------------------------------------------------------------------------
// Kurulum yardımcıları (Apps Script düzenleyicisinden elle çalıştırılır)

/** Uygulama anahtarını oluşturur ve günlüğe yazar. Bir kez çalıştırın. */
function kurulum() {
  hazirla_();
  var pr = PropertiesService.getScriptProperties();
  var a = pr.getProperty('ANAHTAR');
  if (!a) {
    a = Utilities.getUuid().replace(/-/g, '') + Utilities.getUuid().replace(/-/g, '').slice(0, 8);
    pr.setProperty('ANAHTAR', a);
  }
  Logger.log('Sayfalar hazır. Uygulama anahtarı: ' + a);
}

/** İsteğe bağlı: arıza bildirimlerini Google Chat alanına da düşürmek için webhook adresi. */
function chatWebhookAyarla() {
  var url = ''; // Chat alanı → Uygulamalar ve entegrasyonlar → Webhook ekle → adresi buraya yapıştırın
  PropertiesService.getScriptProperties().setProperty('CHAT_WEBHOOK', url);
  Logger.log(url ? 'Webhook kaydedildi.' : 'Webhook adresi boş.');
}
