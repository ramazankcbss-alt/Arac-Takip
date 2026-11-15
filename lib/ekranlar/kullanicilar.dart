import 'package:flutter/material.dart';

import '../servis/api.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesen.dart';

/// Yönetici: uygulama kullanıcıları — cihaz onayı, erişimi kapatma,
/// programdan çıkarma ve geri alma.
class KullanicilarSayfasi extends StatefulWidget {
  const KullanicilarSayfasi({super.key});

  @override
  State<KullanicilarSayfasi> createState() => _KullanicilarSayfasiState();
}

class _KullanicilarSayfasiState extends State<KullanicilarSayfasi> {
  String _ara = '';
  String? _durum;

  static const _durumlar = ['Onaylı', 'Bekliyor', 'Kilitli', 'Erişim kapatıldı', 'Programdan çıkarıldı'];

  Future<bool> _onay(String baslik, String metin, String dugme) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(baslik),
        content: Text(metin),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(dugme)),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _islem(Kullanici u, String islem) async {
    switch (islem) {
      case 'onayla':
        await islem_(context, 'cihazOnay', {'telefon': u.telefon, 'onay': true}, '${u.ad} cihazı onaylandı.');
      case 'reddet':
        await islem_(context, 'cihazOnay', {'telefon': u.telefon, 'onay': false}, '${u.ad} talebi reddedildi.');
      case 'pin':
        if (await _onay('PIN sıfırla', '${u.ad} yeni PIN belirleyecek; ardından cihazını yeniden onaylamanız gerekecek.',
            'Sıfırla')) {
          if (!mounted) return;
          await islem_(context, 'cihazOnay', {'telefon': u.telefon, 'onay': false, 'sifirla': true}, 'PIN sıfırlandı.');
        }
      case 'kapat':
        if (await _onay('Erişimi kapat',
            '${u.ad} uygulamaya giremeyecek. Ekibi, rolü ve geçmiş kayıtları korunur; dilediğiniz zaman geri açabilirsiniz.',
            'Erişimi kapat')) {
          if (!mounted) return;
          await islem_(context, 'kullaniciIslem', {'telefon': u.telefon, 'islem': 'kapat'}, null);
        }
      case 'cikar':
        if (await _onay('Programdan çıkar',
            '${u.ad} programdan tamamen çıkarılacak: cihaz kaydı, ekip bağlantısı ve rolü silinir, uygulamaya giriş '
                'yapamaz, ekip ve iş emri listelerinde görünmez. Geçmiş kullanım, arıza ve iş emri kayıtları korunur.',
            'Programdan çıkar')) {
          if (!mounted) return;
          await islem_(context, 'kullaniciIslem', {'telefon': u.telefon, 'islem': 'cikar'}, null);
        }
      case 'geriAl':
        await islem_(context, 'kullaniciIslem', {'telefon': u.telefon, 'islem': 'geriAl'}, null);
    }
  }

  Future<void> islem_(BuildContext context, String tur, Map<String, dynamic> alan, String? basari) async {
    final j = await islem(context, tur, alan, basari: basari);
    if (j != null && basari == null && context.mounted) {
      final m = j['mesaj']?.toString() ?? '';
      if (m.isNotEmpty) bildir(context, m);
    }
  }

  List<PopupMenuEntry<String>> _menu(Kullanici u) {
    switch (u.durum) {
      case 'Bekliyor':
        return const [
          PopupMenuItem(value: 'onayla', child: Text('Cihazı onayla')),
          PopupMenuItem(value: 'reddet', child: Text('Talebi reddet')),
          PopupMenuItem(value: 'cikar', child: Text('Programdan çıkar')),
        ];
      case 'Kilitli':
        return const [
          PopupMenuItem(value: 'pin', child: Text('PIN sıfırla')),
          PopupMenuItem(value: 'kapat', child: Text('Erişimi kapat')),
          PopupMenuItem(value: 'cikar', child: Text('Programdan çıkar')),
        ];
      case 'Erişim kapatıldı':
      case 'Programdan çıkarıldı':
        return const [PopupMenuItem(value: 'geriAl', child: Text('Erişimi yeniden aç'))];
      default:
        return const [
          PopupMenuItem(value: 'pin', child: Text('PIN sıfırla')),
          PopupMenuItem(value: 'kapat', child: Text('Erişimi kapat')),
          PopupMenuItem(value: 'cikar', child: Text('Programdan çıkar')),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Depo.ben,
      builder: (context, _) {
        final v = Depo.ben.veri!;
        final q = _ara.toLowerCase();
        final l = v.kullanicilar
            .where((u) => u.telefon != v.kisi.telefon)
            .where((u) => _durum == null || u.durum == _durum)
            .where((u) => q.isEmpty || '${u.ad} ${u.gorev} ${u.ciftlik} ${u.telefon}'.toLowerCase().contains(q))
            .toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Kullanıcılar')),
          body: YenilenirListe(
            children: [
              TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Ad, görev, çiftlik ya da telefon'),
                onChanged: (s) => setState(() => _ara = s.trim()),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in _durumlar)
                    ChoiceChip(
                      label: Text('$d (${v.kullanicilar.where((u) => u.durum == d).length})'),
                      selected: _durum == d,
                      onSelected: (s) => setState(() => _durum = s ? d : null),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (l.isEmpty)
                const Bos('Kayıt yok.')
              else
                for (final u in l)
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Renk.cizgi)),
                    child: ListTile(
                      title: Text(u.ad, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text([
                        u.gorev,
                        u.ciftlik,
                        if (u.roller.isNotEmpty) u.roller.join(', '),
                        u.telefon,
                      ].where((x) => x.isNotEmpty).join(' · ')),
                      leading: Rozet.durum(u.durum),
                      trailing: PopupMenuButton<String>(
                        onSelected: (x) => _islem(u, x),
                        itemBuilder: (_) => _menu(u),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}
