import 'package:flutter/material.dart';

import '../servis/api.dart';
import '../servis/arka_plan.dart';
import '../servis/guncelleme.dart';
import '../tema.dart';
import 'araclar.dart';
import 'arizalar.dart';
import 'bildirimler.dart';
import 'ekip.dart';
import 'islerim.dart';
import 'izleme.dart';
import 'kullanicilar.dart';
import 'onay.dart';

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> with WidgetsBindingObserver {
  int _sekme = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Depo.ben.yenile();
      Guncelleme.kontrolEt(context);
      ArkaPlan.baslat();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Uygulamaya her dönüşte veriler yenilenir (bildirimler dahil).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) Depo.ben.yenile();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Depo.ben,
      builder: (context, _) {
        final d = Depo.ben;
        final v = d.veri;
        final k = v?.kisi ?? d.kisi;
        final sekmeler = <({String ad, IconData ikon, Widget sayfa, int rozet})>[
          if ((k?.izleyici ?? false) || (k?.ustYonetim ?? false))
            (ad: 'Genel Durum', ikon: Icons.dashboard_outlined, sayfa: const IzlemeSayfasi(), rozet: 0)
          else
            (ad: 'İşlerim', ikon: Icons.assignment_outlined, sayfa: const IslerimSayfasi(), rozet: 0),
          if (k?.formen ?? false)
            (
              ad: 'Günlük Onay',
              ikon: Icons.fact_check_outlined,
              sayfa: const OnaySayfasi(),
              rozet: (v?.onayBekleyen.where((x) => x.durum == 'Tamamlandı').length ?? 0) +
                  (v?.cihazBekleyen.length ?? 0),
            ),
          if (k?.formen ?? false)
            (
              ad: (k?.ustYonetim ?? false) ? 'Ekipler' : 'Ekibim',
              ikon: Icons.groups_outlined,
              sayfa: const EkipSayfasi(),
              rozet: 0,
            ),
          if ((k?.sorumlu ?? false) || (k?.formen ?? false) || (k?.izleyici ?? false))
            (
              ad: 'Araçlar',
              ikon: Icons.agriculture_outlined,
              sayfa: const AraclarSayfasi(),
              rozet: v?.bakimUyari.where((b) => b.gecikti).length ?? 0,
            ),
          if ((k?.sorumlu ?? false) || (k?.formen ?? false) || (k?.izleyici ?? false))
            (
              ad: 'Arızalar',
              ikon: Icons.build_circle_outlined,
              sayfa: const ArizalarSayfasi(),
              rozet: v?.arizalar.where((a) => !a.kapali).length ?? 0,
            ),
        ];
        if (_sekme >= sekmeler.length) _sekme = 0;
        final s = sekmeler[_sekme];
        return Scaffold(
          appBar: AppBar(
            title: Text(s.ad == 'İşlerim' ? 'İş ve Araç Takip' : s.ad),
            actions: [
              IconButton(
                tooltip: 'Bildirimler',
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const BildirimlerSayfasi())),
                icon: Badge(
                  isLabelVisible: (v?.okunmamis ?? 0) > 0,
                  label: Text('${v?.okunmamis ?? 0}'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
              IconButton(
                tooltip: 'Yenile',
                onPressed: d.yukleniyor ? null : d.yenile,
                icon: d.yukleniyor
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh),
              ),
              PopupMenuButton<String>(
                onSelected: (x) async {
                  if (x == 'guncelle') Guncelleme.kontrolEt(context, elle: true);
                  if (x == 'kullanicilar') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const KullanicilarSayfasi()));
                  }
                  if (x == 'cikis') {
                    final evet = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Oturumu kapat'),
                        content: const Text(
                            'Tekrar girişte cihazınızın yeniden onaylanması gerekebilir. Devam edilsin mi?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kapat')),
                        ],
                      ),
                    );
                    if (evet == true) await Depo.ben.cikis();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Text('${k?.ad ?? ''}\n${k?.rolMetni ?? ''}',
                        style: const TextStyle(color: Renk.yazi)),
                  ),
                  if (k?.yonetici ?? false)
                    const PopupMenuItem(value: 'kullanicilar', child: Text('Kullanıcılar')),
                  const PopupMenuItem(value: 'guncelle', child: Text('Güncelleme kontrolü')),
                  const PopupMenuItem(value: 'cikis', child: Text('Oturumu kapat')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              if (d.hata != null)
                Material(
                  color: Renk.amberAcik,
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.cloud_off, color: Renk.amber),
                    title: Text(d.hata!, style: const TextStyle(color: Renk.amber)),
                  ),
                ),
              Expanded(
                child: v == null
                    ? const Center(child: CircularProgressIndicator())
                    : s.sayfa,
              ),
            ],
          ),
          bottomNavigationBar: sekmeler.length < 2
              ? null
              : NavigationBar(
                  selectedIndex: _sekme,
                  onDestinationSelected: (i) => setState(() => _sekme = i),
                  destinations: [
                    for (final x in sekmeler)
                      NavigationDestination(
                        icon: Badge(
                          isLabelVisible: x.rozet > 0,
                          label: Text('${x.rozet}'),
                          child: Icon(x.ikon),
                        ),
                        label: x.ad,
                      ),
                  ],
                ),
        );
      },
    );
  }
}
