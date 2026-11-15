import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'api.dart';
import 'firebase_ayar.dart';

/// Telefon bildirimleri (iş emri, arıza, cihaz onayı vb.):
/// 1) Anlık: Firebase Cloud Messaging — sunucu bildirimi saniyeler içinde iter.
/// 2) Yedek: uygulama kapalıyken yaklaşık 15 dakikada bir, anlık gönderilemeyen
///    bildirimler sunucudan sorulur ve gösterilir.
class ArkaPlan {
  static const _gorev = 'bildirim_kontrol';
  static const _kSon = 'bildirim_son';
  static final _bildirim = FlutterLocalNotificationsPlugin();

  static const _kanal = AndroidNotificationChannel(
    'arac_takip',
    'Araç Takip bildirimleri',
    description: 'İş emri, arıza ve onay bildirimleri',
    importance: Importance.high,
  );

  static Future<void> _hazirla() async {
    const ayar = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await _bildirim.initialize(ayar);
    await _bildirim
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_kanal);
  }

  static Future<void> _goster(String baslik, String metin) async {
    await _bildirim.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
      baslik,
      metin,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kanal.id,
          _kanal.name,
          channelDescription: _kanal.description,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(metin),
        ),
      ),
    );
  }

  static bool _anlikKuruldu = false;

  /// Firebase anlık bildirim: anahtar sunucuya kaydedilir.
  static Future<void> _anlik() async {
    if (_anlikKuruldu) return;
    _anlikKuruldu = true;
    await Firebase.initializeApp(options: firebaseAyar);
    final fm = FirebaseMessaging.instance;
    await fm.requestPermission();
    final anahtar = await fm.getToken();
    if (anahtar != null) await Depo.ben.gonder('fcmKaydet', {'anahtar': anahtar});
    fm.onTokenRefresh.listen((a) => Depo.ben.gonder('fcmKaydet', {'anahtar': a}).catchError((_) => <String, dynamic>{}));
    // Uygulama açıkken gelen bildirim: göster ve verileri yenile.
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n != null) _goster(n.title ?? 'Araç Takip', n.body ?? '');
      Depo.ben.yenile();
    });
  }

  /// Uygulama açılışında çağrılır: izin ister ve periyodik görevi kaydeder.
  static Future<void> baslat() async {
    try {
      await _hazirla();
      await _bildirim
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      if (Depo.ben.onayli) {
        try {
          await _anlik();
        } catch (_) {
          // Firebase kurulamazsa 15 dakikalık yedek kontrol çalışır.
        }
      }
      await Workmanager().initialize(arkaPlanGirisi);
      await Workmanager().registerPeriodicTask(
        _gorev,
        _gorev,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
      );
      // İlk kurulumda sayaç başlatılır; eski bildirimler yeniden gösterilmez.
      final sp = await SharedPreferences.getInstance();
      if (sp.getInt(_kSon) == null) await kontrol();
    } catch (_) {
      // Bildirim altyapısı kurulamazsa uygulama içi bildirimler çalışmaya devam eder.
    }
  }

  /// Sunucudan yeni bildirimleri çeker ve gösterir.
  static Future<void> kontrol() async {
    // Arka plan görevinde uygulama belleği boştur; oturum telefondan okunur.
    if (!Depo.ben.girisYapildi) await Depo.ben.baslat();
    if (!Depo.ben.girisYapildi || !Depo.ben.onayli) return;
    final sp = await SharedPreferences.getInstance();
    final son = sp.getInt(_kSon);
    final j = await Depo.ben.gonder('bildirimKontrol', {'son': son ?? -1});
    final yeniSon = j['son'];
    if (yeniSon is num) await sp.setInt(_kSon, yeniSon.toInt());
    final yeni = j['yeni'];
    if (son == null || yeni is! List || yeni.isEmpty) return;
    await _hazirla();
    for (final b in yeni.whereType<Map>()) {
      await _goster((b['baslik'] ?? 'Araç Takip').toString(), (b['metin'] ?? '').toString());
    }
  }
}

@pragma('vm:entry-point')
void arkaPlanGirisi() {
  Workmanager().executeTask((gorev, girdi) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await ArkaPlan.kontrol();
    } catch (_) {
      // Bağlantı yoksa bir sonraki turda tekrar denenir.
    }
    return true;
  });
}
