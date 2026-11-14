# Araç Takip

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

Roller, "Personel_Listesi"ndeki görev adından (Formen, Bakım/Atölye) kendiliğinden
çıkarılır; ek ya da farklı rol vermek için tablodaki **Roller** sayfasına satır
eklenir (Telefon | Ad Soyad | Rol | Çiftlik). Bir kişiye birden fazla rol
virgülle yazılabilir. Yönetici için Çiftlik = `Tümü`.

## Giriş

- Telefon numarası (Personel_Listesi'nde kayıtlı olmalı) + kendi belirlediği 4 haneli PIN.
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
