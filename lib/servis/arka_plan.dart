import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'api.dart';

/// Uygulama kapalıyken yaklaşık 15 dakikada bir yeni bildirimleri sorar ve
/// telefonun bildirim alanında gösterir (iş emri, arıza, cihaz onayı vb.).
/// Veri yalnız şirketin Google tablosundan gelir; ek bir bildirim servisi yoktur.
class ArkaPlan {
  static const _gorev = 'bildirim_kontrol';
  static const _kSon = 'bildirim_son';
  static final _bildirim = FlutterLocalNotificationsPlugin();

  static Future<void> _hazirla() async {
    const ayar = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await _bildirim.initialize(ayar);
  }

  /// Uygulama açılışında çağrılır: izin ister ve periyodik görevi kaydeder.
  static Future<void> baslat() async {
    try {
      await _hazirla();
      await _bildirim
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
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
    var id = DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000;
    for (final b in yeni.whereType<Map>()) {
      final baslik = (b['baslik'] ?? 'Araç Takip').toString();
      final metin = (b['metin'] ?? '').toString();
      await _bildirim.show(
        id++,
        baslik,
        metin,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'arac_takip',
            'Araç Takip bildirimleri',
            channelDescription: 'İş emri, arıza ve onay bildirimleri',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(metin),
          ),
        ),
      );
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
