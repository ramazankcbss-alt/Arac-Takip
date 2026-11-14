import 'package:flutter/material.dart';

import '../servis/api.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'ariza_bildir.dart';
import 'bilesen.dart';
import 'is_baslat.dart';
import 'is_bitir.dart';

/// Operatörün ana sayfası: devam eden iş, iş başlatma, arıza bildirimi, geçmiş.
class IslerimSayfasi extends StatelessWidget {
  const IslerimSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final v = Depo.ben.veri!;
    final acik = v.acikIs;
    return YenilenirListe(
      children: [
        if (acik != null)
          _DevamEdenIs(is_: acik, arac: v.arac(acik.arac))
        else
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Uzun süreli bir işe başlarken kullandığınız aracı seçin.',
                    style: TextStyle(color: Renk.soluk)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(64, 64)),
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const IsBaslatEkrani())),
                  icon: const Icon(Icons.play_arrow_rounded, size: 30),
                  label: const Text('İş Başlat', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(64, 56),
            foregroundColor: Renk.kirmizi,
            side: const BorderSide(color: Renk.kirmizi),
          ),
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => ArizaBildirEkrani(onSecili: acik?.arac))),
          icon: const Icon(Icons.report_problem_outlined),
          label: const Text('Arıza Bildirimi', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 16),
        if (v.arizalarim.isNotEmpty)
          Panel(
            baslik: 'Arıza bildirimlerim',
            child: Column(
              children: [
                for (final a in v.arizalarim.take(5))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${a.arac} · ${a.aciklama}', maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(a.zaman),
                    trailing: Rozet.durum(a.durum),
                  ),
              ],
            ),
          ),
        Panel(
          baslik: 'Son kayıtlarım',
          child: v.benim.isEmpty
              ? const Bos('Henüz kaydınız yok.')
              : Column(
                  children: [
                    for (final x in v.benim.take(15)) _KayitSatiri(x: x, arac: v.arac(x.arac)),
                  ],
                ),
        ),
      ],
    );
  }
}

class _DevamEdenIs extends StatelessWidget {
  const _DevamEdenIs({required this.is_, required this.arac});
  final Kullanim is_;
  final Arac? arac;

  @override
  Widget build(BuildContext context) {
    return Panel(
      baslik: 'Devam eden iş',
      eylem: Rozet.durum('Devam ediyor'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(arac?.baslik ?? is_.arac, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (arac != null) Text(arac!.alt, style: const TextStyle(color: Renk.soluk)),
          const SizedBox(height: 8),
          BilgiSatiri('Başlangıç', is_.baslangic),
          BilgiSatiri('Başlangıç sayacı', sayiYaz(is_.sayac1)),
          if (is_.is_.isNotEmpty) BilgiSatiri('İş', is_.is_),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 60), backgroundColor: Renk.anaKoyu),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => IsBitirEkrani(is_: is_))),
            icon: const Icon(Icons.stop_rounded, size: 28),
            label: const Text('İşi Bitir', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}

class _KayitSatiri extends StatelessWidget {
  const _KayitSatiri({required this.x, required this.arac});
  final Kullanim x;
  final Arac? arac;

  @override
  Widget build(BuildContext context) {
    final alt = [
      x.tarih,
      if (x.saat != null) '${sayiYaz(x.saat)} saat',
      if (x.is_.isNotEmpty) x.is_,
      if (x.durum != 'Devam ediyor' && !x.bakimTam) 'Eksik kontrol: ${x.eksikKontroller.join(', ')}',
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(arac?.baslik ?? x.arac),
      subtitle: Text(alt),
      trailing: Rozet.durum(x.durum),
    );
  }
}
