import 'package:flutter/material.dart';

import '../servis/api.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'ariza_bildir.dart';
import 'bilesen.dart';

/// İzleme kadrosu (müdür, uzman, veteriner, raporlama) ve formenler için
/// kapsamdaki çiftliklerin anlık durumu: aktif kullanım, iş emirleri, açık arızalar.
class IzlemeSayfasi extends StatefulWidget {
  const IzlemeSayfasi({super.key});

  @override
  State<IzlemeSayfasi> createState() => _IzlemeSayfasiState();
}

class _IzlemeSayfasiState extends State<IzlemeSayfasi> {
  int _gun = 0; // -1 dün, 0 bugün, 1 yarın

  String _tarih(int fark) {
    final d = DateTime.now().add(Duration(days: fark));
    String iki(int x) => x.toString().padLeft(2, '0');
    return '${iki(d.day)}.${iki(d.month)}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final v = Depo.ben.veri!;
    final k = v.kisi;
    final emirler = v.izlemeEmirleri.where((e) => e.tarih == _tarih(_gun)).toList();
    final acikAriza = v.arizalar.where((a) => !a.kapali).toList();
    final arizali = v.araclar.where((a) => a.arizali).length;
    Widget sayac(String ad, int n, Color r) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Renk.cizgi)),
            child: Column(children: [
              Text('$n', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: r)),
              Text(ad, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Renk.soluk)),
            ]),
          ),
        );
    return YenilenirListe(
      children: [
        Text(k.ciftlik == 'Tümü' ? 'Kapsam: tüm çiftlikler' : 'Kapsam: ${k.ciftlik}',
            style: const TextStyle(color: Renk.soluk)),
        const SizedBox(height: 8),
        Row(children: [
          sayac('Aktif kullanım', v.aktif.length, Renk.mavi),
          sayac('Bugünkü iş emri', v.izlemeEmirleri.where((e) => e.tarih == _tarih(0)).length, Renk.ana),
          sayac('Açık arıza', acikAriza.length, Renk.kirmizi),
          sayac('Arızalı araç', arizali, Renk.amber),
        ]),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(64, 52),
            foregroundColor: Renk.kirmizi,
            side: const BorderSide(color: Renk.kirmizi),
          ),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArizaBildirEkrani())),
          icon: const Icon(Icons.warning_amber_rounded),
          label: const Text('Arıza Bildirimi'),
        ),
        const SizedBox(height: 12),
        Panel(
          baslik: 'Aktif Kullanım (${v.aktif.length})',
          child: v.aktif.isEmpty
              ? const Text('Şu an kullanımda araç yok.', style: TextStyle(color: Renk.soluk))
              : Column(
                  children: [
                    for (final x in v.aktif)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${[x.arac, ...x.ekipman].join(' + ')} · ${x.personel}'),
                        subtitle: Text([x.baslangic, x.ciftlik, if (x.is_.isNotEmpty) x.is_].join(' · ')),
                      ),
                  ],
                ),
        ),
        Panel(
          baslik: 'İş Emirleri',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(spacing: 6, children: [
                for (final (g, ad) in const [(-1, 'Dün'), (0, 'Bugün'), (1, 'Yarın')])
                  ChoiceChip(label: Text(ad), selected: _gun == g, onSelected: (_) => setState(() => _gun = g)),
              ]),
              const SizedBox(height: 6),
              if (emirler.isEmpty)
                const Text('İş emri yok.', style: TextStyle(color: Renk.soluk))
              else
                for (final e in emirler)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${e.personel} · ${e.is_}'),
                    subtitle: Text([
                      [e.yerTuru, e.yer].where((x) => x.isNotEmpty).join(': '),
                      e.aracMetni.isEmpty ? 'Araçsız iş' : e.aracMetni,
                      'Formen: ${e.formenAd}',
                    ].join(' · ')),
                    trailing: Rozet.durum(e.durum),
                  ),
            ],
          ),
        ),
        Panel(
          baslik: 'Açık Arızalar (${acikAriza.length})',
          child: acikAriza.isEmpty
              ? const Text('Açık arıza yok.', style: TextStyle(color: Renk.soluk))
              : Column(
                  children: [
                    for (final a in acikAriza)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${a.yer == sinifEkipman ? 'Makine-ekipman' : 'Araç'} ${a.arac} · ${a.aciklama}',
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${a.zaman} · ${a.bildiren}'),
                        trailing: Rozet.durum(a.durum),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
