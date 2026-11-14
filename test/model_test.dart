import 'package:arac_takip/servis/api.dart';
import 'package:arac_takip/veri/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('telefon düzeltme', () {
    expect(telefonDuzelt('0500 000 00 13'), '05000000013');
    expect(telefonDuzelt('+90 500 000 0013'), '05000000013');
    expect(telefonDuzelt('1234'), isNull);
  });

  test('sayı okuma', () {
    expect(sayiOku('1.234,5'), 1234.5);
    expect(sayiOku('1234.5'), 1234.5);
    expect(sayiOku(''), isNull);
    expect(sayiYaz(1250), '1250');
    expect(sayiYaz(12.5), '12,5');
  });

  test('araç seçim listesi: sık kullanılan ve kendi çiftliği başta, pasif yok', () {
    final v = Veri({
      'kisi': {'ad': 'A', 'telefon': '05000000000', 'ciftlik': 'Aslım', 'roller': <String>[]},
      'araclar': [
        {'no': 'TRK-01', 'ciftlik': 'Şekersüt', 'kullanim': 0},
        {'no': 'TRK-02', 'ciftlik': 'Aslım', 'kullanim': 0},
        {'no': 'TRK-03', 'ciftlik': 'Şekersüt', 'kullanim': 5},
        {'no': 'TRK-04', 'ciftlik': 'Aslım', 'durum': 'Pasif'},
      ],
    });
    expect(v.secimListesi().map((a) => a.no), ['TRK-03', 'TRK-02', 'TRK-01']);
  });

  test('roller ve bakım kontrolü', () {
    final k = Kisi.oku({'roller': ['Formen']});
    expect(k.formen, isTrue);
    expect(k.sorumlu, isFalse);
    final x = Kullanim({'gresleme': 'Yapıldı', 'hava': 'Yapılmadı', 'yag': 'Yapıldı', 'radyator': 'Yapıldı'});
    expect(x.bakimTam, isFalse);
    expect(x.eksikKontroller, ['Hava filtresi']);
  });
}
