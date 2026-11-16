# İş ve Araç Takip

Panagro çiftliklerinde traktör, kamyon, manitou ve diğer iş makinelerinin
uzun süreli kullanımını, günlük bakım kontrolünü, periyodik bakımı ve arıza
takibini kayıt altına alan Android uygulaması. Veriler "Araç Takip – Kayıtlar"
Google tablosunda tutulur; Yönetim Raporu uygulamasındaki "Araçlar" bölümü
aynı tabloyu okur.

## Roller

| Rol | Ne yapar |
| --- | --- |
| Operatör (herkes) | Uzun süreli işte **İş Başlat** → aracı listeden seçer → **İşi Bitir** → Günlük Bakım Kontrolü. Arıza Bildirimi. |
| Formen | Akşam **Günlük Onay**: kayıtları toplu onaylar, eksikleri düzeltir, personel yerine kayıt girer. Cihaz onayı verir. |
| Makine-Ekipman Sorumlusu / Bakım-Onarım | Araç ekler, geçmiş bakım ve onarımları girer, bakım planını düzenler, arıza durumunu günceller. |
| Yönetici | Tüm çiftlikleri görür, tüm yetkilere sahiptir. |

Roller, "Araç_Personeli"ndeki görev adından (Formen, Bakım/Atölye) kendiliğinden
çıkarılır; ek ya da farklı rol vermek için tablodaki **Roller** sayfasına satır
eklenir (Telefon | Ad Soyad | Rol | Çiftlik). Bir kişiye birden fazla rol
virgülle yazılabilir. Yönetici için Çiftlik = `Tümü`.

## Giriş

- Telefon numarası (Araç_Personeli'nde kayıtlı olmalı) + kendi belirlediği 4 haneli PIN.
- İlk girişte cihaz, formen ya da Makine-Ekipman Sorumlusu tarafından onaylanır.
- Sonraki açılışlarda giriş otomatiktir.

## Sunucu kurulumu (bir kez)

1. Drive → **Araç Takip** klasörü → **Araç Takip – Kayıtlar** tablosunu açın.
2. Uzantılar → Apps Script. `apps_script/Kod.gs` içeriğini yapıştırıp kaydedin.
3. Üstteki işlev listesinden **kurulum** seçip **Çalıştır**. İzin isteyince onaylayın.
   Günlükte (Yürütme günlüğü) **Uygulama anahtarı** yazar; kopyalayın.
4. Dağıt → Yeni dağıtım → Tür: **Web uygulaması**; Yürüten: **Ben**; Erişim: **Herkes**.
   Dağıtın ve **…/exec** ile biten web uygulaması adresini kopyalayın.
5. Roller sayfasına kendinizi ekleyin: telefonunuz | adınız | `Yönetici` | `Tümü`.
   Uygulamada ilk girişinizi yaptıktan sonra **Cihazlar** sayfasında kendi satırınızın
   **Durum** hücresine `Onaylı` yazın. Hiçbir cihaz otomatik onaylanmaz; diğer personelin
   cihazları uygulamadan formen veya Makine-Ekipman Sorumlusu tarafından onaylanır.
   Arka arkaya 5 hatalı PIN girişinde hesap **Kilitli** olur; formen PIN sıfırlar.
6. İsteğe bağlı: Arıza bildirimlerinin Google Chat'e de düşmesi için `chatWebhookAyarla`
   işlevine Chat alanının webhook adresini yazıp çalıştırın.

## GitHub gizli ayarları (Settings → Secrets and variables → Actions)

| Ad | Değer |
| --- | --- |
| `ARAC_API_URL` | 4. adımdaki …/exec adresi |
| `ARAC_API_ANAHTAR` | 3. adımdaki uygulama anahtarı |
| `ARAC_KEYSTORE_PASSWORD` | İmza anahtarı şifresi |

Gizli ayarlar girildikten sonra Actions → **APK Derle** → Run workflow ile yeni
sürüm derlenir. APK, Releases bölümünde `arac-takip.apk` olarak yayımlanır;
kurulu uygulamalar güncellemeyi kendileri alır.

## Tablo sayfaları

- **Araçlar**: Araç No, Tür, Marka/Model, Plaka/Şase, Çiftlik, Motor Saati, Durum (Aktif/Arızalı/Pasif)…
- **Kullanım**: her uzun süreli iş; başlangıç/bitiş, sayaçlar, çalışma saati, Günlük Bakım Kontrolü, onay.
- **Bakım_Plan**: araç başına periyodik bakım türü ve periyodu (motor saati). Yeni araçta varsayılan plan oluşur.
- **Bakım_Kayıt**: periyodik bakım, onarım, parça değişimi; tarih, sayaç, parça, firma, tutar, belge no.
- **Arıza**: bildirim, fotoğraf (Drive), durum akışı: Bildirildi → Atölyede → Parça bekleniyor → Onarıldı.
- **Cihazlar**, **Roller**, **Bildirimler**: oturum, yetki ve uygulama içi bildirimler.

## Ekipler ve çiftlikler arası görevlendirme

- Her personel bir formene bağlanır (**Ekipler** sayfası). Personelin kullanım kayıtlarını,
  cihaz onayını ve PIN sıfırlamasını yalnız bağlı olduğu formen görür ve onaylar.
  Formene bağlı olmayan personel, çiftliğinin formenleri tarafından görülür.
- Formen, uygulamada **Ekibim** sekmesinden ekibine bağlı olmayan personeli ekibine alır;
  kendi ekibindeki personeli **Başka formene görevlendir** ile diğer çiftliğin formenine aktarır.
  Personelin çiftliği görevlendirildiği formenin çiftliği olur. Eski ve yeni formen ile personel bilgilendirilir.
- Yönetici **Ekipler** sekmesinden tüm personeli görür ve dilediği formene görevlendirir.
- Tüm değişiklikler **Görevlendirme_Geçmişi** sayfasında tutulur.
- Kullanım kaydı açıldığı anda personelin formeni **Sorumlu Formen** sütununa yazılır;
  personel sonradan aktarılsa da o günün kaydını önceki formen onaylar.
- Araç_Personeli'nden çıkarılan kişinin (işten ayrılan) oturumu en geç 10 dakika içinde kapanır.

## İş emirleri

- Formen **Ekibim → İş Emri Ver** ile bir ya da birden çok personele bugün/yarın için iş emri verir:
  çalışma yeri (Tarla, Ahır, Silaj / Yem Deposu, Atölye, Diğer) ve yer adı, yapılacak iş, araç, makine-ekipman, talimat.
- Ahır işleri: yem karma ve yemleme, balya taşıma, kaba yem ve silaj taşıma, dışkı temizleme / gübre sıyırma,
  gübre çıkarma, altlık serme, yalak ve bölme temizliği, hayvan sevki, ahır bakım ve onarım.
- Personele bildirim gider; **İşlerim** ekranının üstünde iş emri görünür. **İşe Başla** ile araç, ekipman ve iş
  hazır seçili gelir. Araç gerektirmeyen işte personel **Tamamlandı** bildirir; formene bildirim gider.
- Araçlı işte kullanım kaydı bitince iş emri kendiliğinden tamamlanır. Personel farklı araç seçerse kayda not düşülür.
- Kayıtlar **İş_Emirleri** sayfasında tutulur.

## Kadrolar ve izleme erişimi

- **Araç-makine kadrosu** (Araç_Personeli → Görev): çiftlik personeli, işletme operatörü, formen,
  bakım-onarım personeli ve ustası. Araç kullanır, iş emri alır, ekiplere bağlanır.
- **İzleme kadrosu**: müdür, müdür yardımcısı, uzman, veteriner, veteriner sağlık teknikeri, zooteknist,
  kalite kontrol, raporlama, mühendis, güvenlik. Uygulamaya girer; **Genel Durum** (aktif kullanım,
  iş emirleri, açık arızalar), **Araçlar** ve **Arızalar** ekranlarını görür, arıza bildirir; işlem yapamaz.
  Çiftliğe bağlı olanlar kendi çiftliğini, direktörlük/müdürlük kadrosu tüm çiftlikleri görür.
  Cihazlarını yalnız Yönetici onaylar; ekip ve iş emri listelerinde görünmezler.
- Yönetmek isteyen kişiye Roller sayfasından rol verilir: `Formen`, `Makine-Ekipman Sorumlusu`,
  `Bakım-Onarım` ya da `Yönetici` (çiftlik sütunu: çiftlik adı ya da `Tümü`). Araç kullanacaksa `Personel`.
- Roller sayfasında `Hariç` yazılan kişi uygulamaya hiç giremez.

## Anlık bildirim (Firebase)

- Firebase projesi: `arac-takip-b5139`, Android paketi `com.panagro.arac_takip`. İstemci ayarları
  `lib/servis/firebase_ayar.dart` içindedir (gizli değildir).
- Sunucu anahtarı: Firebase → Proje ayarları → Hizmet hesapları → yeni özel anahtar. Dosya Drive'daki
  "Araç Takip" klasörüne yüklenir, Apps Script'te **fcmKur** bir kez çalıştırılır (anahtar komut dosyası
  özelliklerine taşınır), ardından Drive'daki dosya silinir.
- Her bildirim önce anlık gönderilir; gönderilemeyen telefon 15 dakikalık yedek kontrolde alır.

## Çiftlik Sorumlusu (beyaz yaka) ve toplu görevlendirme

- Roller sayfasında `Çiftlik Sorumlusu` rolü verilen kişi (müdür, müdür yardımcısı, uzman), Çiftlik
  sütununda yazan çiftlikte (ya da `Tümü`) formen yetkilerinin tamamına sahiptir: personeli formenlere
  görevlendirir, iş emri verir, günlük kayıtları onaylar. Cihaz onayı ve PIN sıfırlama yapamaz.
  Formen listesinde yer almaz.
- **Ekipler** ekranı: formenlere göre personel dağılımı ve formene bağlı olmayan personel sayısı;
  dokununca liste süzülür. Personel işaretlenerek toplu **Formene görevlendir / Ekipten çıkar / Ekibime al**.
  Formenler ekip üyesi listelerinde görünmez.

## Cihaz onayı ve PIN sıfırlama (güncel kural)

- Cihaz onayı ve PIN sıfırlama **yalnız Yönetici** tarafından yapılır (Günlük Onay ekranı ya da
  Cihazlar sayfasında Durum = `Onaylı`). Formen, Makine-Ekipman Sorumlusu ve Çiftlik Sorumlusu yapamaz.
  Yeni cihaz talepleri yalnız Yöneticiye bildirilir. Bu bölümdeki önceki ifadelerin yerine geçer.

## Kullanıcı yönetimi (Yönetici)

Sağ üst menü → **Kullanıcılar**: tüm uygulama kullanıcıları durumlarıyla (Onaylı, Bekliyor, Kilitli,
Erişim kapatıldı, Programdan çıkarıldı). İşlemler:
- **Cihazı onayla / Talebi reddet / PIN sıfırla**
- **Erişimi kapat**: kişi giriş yapamaz; ekibi, rolü ve kayıtları korunur.
- **Programdan çıkar**: Roller'a `Hariç` yazılır; cihaz, ekip ve rol kayıtları silinir; ekip ve iş emri
  listelerinde görünmez. Geçmiş kullanım, arıza ve iş emri kayıtları korunur.
- **Erişimi yeniden aç**: iki işlemi de geri alır.

## Servis kayıtları, sonraki bakım ve malzeme talepleri

- **Bakım / Onarım kaydı**: fatura ve servis belgesi kamerayla eklenir (en fazla 3 fotoğraf, Drive'a kaydedilir).
  Servisin belirttiği **sonraki bakım** tarih ya da motor saati olarak girilir; tarihe 15 gün, saate 25 saat
  kala ve geciktiğinde bakım uyarılarında görünür.
- **Parça / Bakım Talebi**: formen ve personel, kırılan / değişecek parça, alınacak malzeme ya da bakım
  ihtiyacını (araç, açıklama, fotoğraf) bildirir. Talep anında bakım-onarım ekibine gider.
- **Bakım-onarım ekibi**: görevi bakım-onarım olanlar, bakım-onarım formeninin (Serdar Öz) ekibindeki personel
  ve Makine-Ekipman Sorumlusu. Tüm çiftliklerin arızalarını, bakım uyarılarını ve taleplerini görür; talep
  durumunu (Değerlendiriliyor, Satınalmada, Tedarik edildi, Tamamlandı, İptal) günceller, talepten bakım kaydı girer.
  Talep eden ve çiftlik formeni her durum değişikliğinde bilgilendirilir.

## Formenin personel çıkarması ve talebin paylaşılması

- Formen (ve Çiftlik Sorumlusu) Ekipler ekranında araç-makine işleriyle ilgisi olmayan personeli
  **Programdan çıkar (araç işi yapmıyor)** ile çıkarabilir: yalnız kendi ekibindeki ya da çiftliğinde ekibe
  bağlı olmayan personel; formen ve yönetim rolleri hariç. Yöneticiye bildirim gider; geri alma Yöneticidedir.
- Malzeme / parça talebi kaydedildikten sonra **Paylaş** ile kurumsal metin olarak Google Chat satınalma
  grubuna (ya da WhatsApp / e-posta) gönderilebilir. Kayıt uygulamada tutulur; günlük mutabakat kontrolü
  Chat'teki satınalma yazışmalarını uygulama kayıtlarıyla karşılaştırır.

## İş emri: makam silsilesi ve beden işçiliği

- Beyaz yaka (Yönetici, Çiftlik Sorumlusu, müdür, müdür yardımcısı, uzman, veteriner, ziraat mühendisi,
  raporlama vb.) iş emrini **formene** verir (Genel Durum → Formene İş Emri Ver).
- Formen kendisine gelen iş emrini **Personele dağıt** ile ekibindeki personele aktarır: yer, iş ve talimat
  yeniden yazılmaz; araç, makine-ekipman ve ek talimat değiştirilebilir. Formen işi kendisi de tamamlayabilir.
- Formen yalnız kendi ekibine iş emri verir. Personelin tüm alt iş emirleri kapanınca formene verilen iş emri
  kendiliğinden tamamlanır ve veren beyaz yakaya bildirim gider. Veren kişi iptal ederse alt iş emirleri de iptal olur.
- İş listesi yer türüne göre **Makineli işler** ve **Beden işçiliği** (çapa, ot temizliği, sulama hattı,
  sağım, buzağı besleme, hayvan bakımı, padok temizliği, dezenfeksiyon, veteriner uygulamasına yardım vb.) olarak ayrılır.
