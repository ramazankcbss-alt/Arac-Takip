import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../veri/model.dart';

class ApiHatasi implements Exception {
  ApiHatasi(this.mesaj, {this.oturumGecersiz = false, this.arizali = false});
  final String mesaj;
  final bool oturumGecersiz;
  final bool arizali;
  @override
  String toString() => mesaj;
}

/// Sunucu bağlantısı ve oturum. Sunucu adresi ile uygulama anahtarı derleme
/// sırasında verilir (GitHub gizli ayarları → --dart-define).
class Depo extends ChangeNotifier {
  Depo._();
  static final Depo ben = Depo._();

  static const _adres = String.fromEnvironment('API_URL');
  static const _anahtar = String.fromEnvironment('API_ANAHTAR');

  static const _kOturum = 'oturum';
  static const _kCihaz = 'cihaz_kimligi';
  static const _kKisi = 'kisi';
  static const _kDurum = 'cihaz_durum';
  static const _kOnbellek = 'veri_onbellek';

  SharedPreferences? _sp;
  String? oturum;
  String cihazId = '';
  String cihazDurum = '';
  Kisi? kisi;
  Veri? veri;
  bool yukleniyor = false;
  String? hata;

  /// Testlerde ağ yerine kullanılır.
  @visibleForTesting
  Future<Map<String, dynamic>> Function(Map<String, dynamic> govde)? sahte;

  bool get sunucuTanimli => _adres.isNotEmpty && _anahtar.isNotEmpty;
  bool get girisYapildi => oturum != null && oturum!.isNotEmpty;
  bool get onayli => cihazDurum == 'Onaylı';

  Future<void> baslat() async {
    final sp = _sp = await SharedPreferences.getInstance();
    oturum = sp.getString(_kOturum);
    cihazDurum = sp.getString(_kDurum) ?? '';
    var c = sp.getString(_kCihaz);
    if (c == null || c.isEmpty) {
      final r = Random.secure();
      c = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await sp.setString(_kCihaz, c);
    }
    cihazId = c;
    final k = sp.getString(_kKisi);
    if (k != null) {
      try {
        kisi = Kisi.oku((jsonDecode(k) as Map).cast<String, dynamic>());
      } catch (_) {}
    }
    final o = sp.getString(_kOnbellek);
    if (o != null && onayli) {
      try {
        veri = Veri((jsonDecode(o) as Map).cast<String, dynamic>());
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> _istek(Map<String, dynamic> govde) async {
    if (sahte != null) return sahte!(govde);
    if (!sunucuTanimli) throw ApiHatasi('Bu derlemede sunucu adresi tanımlı değil.');
    final adres = Uri.parse(_adres).replace(queryParameters: {'anahtar': _anahtar});
    http.Response r;
    try {
      r = await http
          .post(adres, body: jsonEncode(govde), headers: {'Content-Type': 'text/plain;charset=utf-8'})
          .timeout(const Duration(seconds: 60));
      final yer = r.headers['location'];
      if ((r.statusCode == 302 || r.statusCode == 303) && yer != null) {
        r = await http.get(adres.resolve(yer)).timeout(const Duration(seconds: 45));
      }
    } on TimeoutException {
      throw ApiHatasi('Sunucu yanıt vermedi. İnternet bağlantınızı kontrol edip tekrar deneyin.');
    } catch (_) {
      throw ApiHatasi('Bağlantı kurulamadı. İnternet bağlantınızı kontrol edin.');
    }
    if (r.statusCode != 200) throw ApiHatasi('Sunucu hatası (${r.statusCode}).');
    final Object? j;
    try {
      j = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      throw ApiHatasi('Sunucudan beklenmeyen cevap geldi.');
    }
    if (j is! Map) throw ApiHatasi('Sunucudan beklenmeyen cevap geldi.');
    return j.cast<String, dynamic>();
  }

  /// Oturumlu istek; hata varsa [ApiHatasi] fırlatır.
  Future<Map<String, dynamic>> gonder(String tur, [Map<String, dynamic> alan = const {}]) async {
    final j = await _istek({'tur': tur, 'oturum': oturum, ...alan});
    if (j['ok'] != true) {
      if (j['oturum'] == false) {
        await cikis();
        throw ApiHatasi(j['hata']?.toString() ?? 'Oturum kapandı.', oturumGecersiz: true);
      }
      throw ApiHatasi(j['hata']?.toString() ?? 'İşlem yapılamadı.', arizali: j['arizali'] == true);
    }
    return j;
  }

  Future<void> giris({required String telefon, required String pin, required String cihazAdi}) async {
    final j = await _istek({
      'tur': 'giris',
      'telefon': telefon,
      'pin': pin,
      'cihazId': cihazId,
      'cihazAdi': cihazAdi,
    });
    if (j['ok'] != true) throw ApiHatasi(j['hata']?.toString() ?? 'Giriş yapılamadı.');
    oturum = j['oturum']?.toString();
    cihazDurum = j['durum']?.toString() ?? '';
    if (j['kisi'] is Map) {
      kisi = Kisi.oku((j['kisi'] as Map).cast<String, dynamic>());
      await _sp?.setString(_kKisi, jsonEncode(j['kisi']));
    }
    await _sp?.setString(_kOturum, oturum ?? '');
    await _sp?.setString(_kDurum, cihazDurum);
    notifyListeners();
  }

  /// Verileri sunucudan yeniler. Cihaz onay bekliyorsa yalnız durumu günceller.
  Future<void> yenile() async {
    if (!girisYapildi) return;
    yukleniyor = true;
    hata = null;
    notifyListeners();
    try {
      final j = await gonder('veri');
      cihazDurum = j['durum']?.toString() ?? cihazDurum;
      await _sp?.setString(_kDurum, cihazDurum);
      if (j['kisi'] is Map) {
        kisi = Kisi.oku((j['kisi'] as Map).cast<String, dynamic>());
        await _sp?.setString(_kKisi, jsonEncode(j['kisi']));
      }
      if (onayli && j['araclar'] != null) {
        veri = Veri(j);
        await _sp?.setString(_kOnbellek, jsonEncode(j));
      }
    } on ApiHatasi catch (e) {
      hata = e.mesaj;
    } finally {
      yukleniyor = false;
      notifyListeners();
    }
  }

  Future<void> cikis() async {
    oturum = null;
    cihazDurum = '';
    veri = null;
    kisi = null;
    await _sp?.remove(_kOturum);
    await _sp?.remove(_kDurum);
    await _sp?.remove(_kOnbellek);
    await _sp?.remove(_kKisi);
    notifyListeners();
  }
}

/// "05xx xxx xx xx" → "05xxxxxxxxx"; geçersizse null.
String? telefonDuzelt(String s) {
  var d = s.replaceAll(RegExp(r'\D'), '');
  if (d.length > 10) d = d.substring(d.length - 10);
  if (d.length != 10 || !d.startsWith('5')) return null;
  return '0$d';
}

/// Sayaç girişi: "1.234,5" / "1234.5" → 1234.5
double? sayiOku(String s) {
  var t = s.trim().replaceAll(' ', '');
  if (t.isEmpty) return null;
  if (t.contains(',') && t.contains('.')) t = t.replaceAll('.', '');
  return double.tryParse(t.replaceAll(',', '.'));
}

String sayiYaz(double? d) {
  if (d == null) return '–';
  if (d == d.roundToDouble()) return d.toStringAsFixed(0);
  return d.toStringAsFixed(1).replaceAll('.', ',');
}
