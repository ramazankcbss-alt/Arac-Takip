import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../servis/api.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'araclar.dart';
import 'bilesen.dart';

/// Arıza takibi: açık arızalar üstte; durum güncelleme ve onarım kaydı.
class ArizalarSayfasi extends StatelessWidget {
  const ArizalarSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final v = Depo.ben.veri!;
    final acik = v.arizalar.where((a) => !a.kapali).toList();
    final kapali = v.arizalar.where((a) => a.kapali).take(30).toList();
    return YenilenirListe(
      children: [
        Panel(
          baslik: 'Açık arızalar (${acik.length})',
          child: acik.isEmpty
              ? const Bos('Açık arıza yok.', ikon: Icons.check_circle_outline)
              : Column(children: [for (final a in acik) _ArizaSatiri(a: a)]),
        ),
        if (kapali.isNotEmpty)
          Panel(
            baslik: 'Kapanan arızalar',
            child: Column(children: [for (final a in kapali) _ArizaSatiri(a: a)]),
          ),
      ],
    );
  }
}

class _ArizaSatiri extends StatelessWidget {
  const _ArizaSatiri({required this.a});
  final Ariza a;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${a.arac} · ${a.aciklama}', maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${a.zaman} · ${a.bildiren}'
          '${a.guncelleme.isNotEmpty && a.guncelleme != a.zaman ? '\nSon: ${a.guncelleyen}, ${a.guncelleme}' : ''}'),
      isThreeLine: a.guncelleme.isNotEmpty && a.guncelleme != a.zaman,
      trailing: Rozet.durum(a.durum),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ArizaDetay(a: a),
      ),
    );
  }
}

class _ArizaDetay extends StatefulWidget {
  const _ArizaDetay({required this.a});
  final Ariza a;

  @override
  State<_ArizaDetay> createState() => _ArizaDetayState();
}

class _ArizaDetayState extends State<_ArizaDetay> {
  late String _durum = widget.a.durum;
  final _not = TextEditingController();

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    final sorumlu = Depo.ben.veri!.kisi.sorumlu;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Arıza ${a.no} · ${a.arac}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            BilgiSatiri('Bildiren', a.bildiren),
            BilgiSatiri('Zaman', a.zaman),
            BilgiSatiri('Çiftlik', a.ciftlik),
            BilgiSatiri('Açıklama', a.aciklama),
            if (a.not.isNotEmpty) BilgiSatiri('Onarım notu', a.not),
            if (a.foto.isNotEmpty)
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(a.foto), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.image_outlined),
                label: const Text('Fotoğrafı aç'),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: arizaDurumlari.contains(_durum) ? _durum : null,
              decoration: const InputDecoration(labelText: 'Durum'),
              items: [for (final d in arizaDurumlari) DropdownMenuItem(value: d, child: Text(d))],
              onChanged: (s) => setState(() => _durum = s ?? _durum),
            ),
            const SizedBox(height: 12),
            TextField(controller: _not, maxLines: 2, decoration: const InputDecoration(labelText: 'Not')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final j = await islem(context, 'arizaDurum', {'no': a.no, 'durum': _durum, 'not': _not.text.trim()},
                    basari: 'Durum güncellendi; bildiren personel ve formen bilgilendirildi.');
                if (j != null && context.mounted) Navigator.pop(context);
              },
              child: const Text('Durumu kaydet'),
            ),
            if (sorumlu && !a.kapali) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push(
                    MaterialPageRoute(
                      builder: (_) => BakimFormu(
                        arac: a.arac,
                        sayac: Depo.ben.veri!.arac(a.arac)?.sayac,
                        arizaNo: a.no,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.build),
                label: const Text('Onarım kaydı gir ve kapat'),
              ),
            ],
            const SizedBox(height: 4),
            const Text('Onarım kaydı girildiğinde arıza "Onarıldı" olarak kapanır.',
                style: TextStyle(color: Renk.soluk, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
