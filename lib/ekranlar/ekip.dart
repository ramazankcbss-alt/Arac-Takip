import 'package:flutter/material.dart';

import '../servis/api.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesen.dart';
import 'is_emri.dart';

/// Formenin ekibi: personel formene bağlanır; çiftlikler arası geçişte formen
/// personeli başka formene görevlendirir. Ekibe bağlı olmayan personel ekibe alınır.
class EkipSayfasi extends StatefulWidget {
  const EkipSayfasi({super.key});

  @override
  State<EkipSayfasi> createState() => _EkipSayfasiState();
}

class _EkipSayfasiState extends State<EkipSayfasi> {
  String _ara = '';

  bool _uyar(EkipUyesi x) {
    if (_ara.isEmpty) return true;
    final a = _ara.toLowerCase();
    return '${x.ad} ${x.gorev} ${x.ciftlik} ${x.formenAd}'.toLowerCase().contains(a);
  }

  Future<Formen?> _formenSec(BuildContext context, EkipUyesi x, List<Formen> l) {
    final secenek = l.where((f) => f.telefon != x.formen).toList();
    return showModalBottomSheet<Formen>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('${x.ad} · görevlendirilecek formen',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final f in secenek)
                      ListTile(
                        leading: const Icon(Icons.person_pin_outlined),
                        title: Text(f.ad),
                        subtitle: Text(f.ciftlik),
                        onTap: () => Navigator.pop(ctx, f),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _gorevlendir(BuildContext context, EkipUyesi x, List<Formen> formenler) async {
    final f = await _formenSec(context, x, formenler);
    if (f == null || !context.mounted) return;
    await islem(context, 'ekipAta', {'telefon': x.telefon, 'formen': f.telefon},
        basari: '${x.ad}, ${f.ad} ekibine görevlendirildi.');
  }

  Future<void> _cikar(BuildContext context, EkipUyesi x) async {
    final evet = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ekipten çıkar'),
        content: Text('${x.ad} ekipten çıkarılsın mı? Personel, çiftliğinin formenlerine bağlı olmayan '
            'personel listesine geçer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Çıkar')),
        ],
      ),
    );
    if (evet == true && context.mounted) {
      await islem(context, 'ekipAta', {'telefon': x.telefon, 'formen': ''}, basari: '${x.ad} ekipten çıkarıldı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = Depo.ben.veri!;
    final yonetici = v.kisi.yonetici;
    final ekibim = v.ekibim.where(_uyar).toList();
    final diger = v.atanabilir.where(_uyar).toList();
    return YenilenirListe(
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IsEmriFormu())),
          icon: const Icon(Icons.assignment_ind_outlined),
          label: const Text('İş Emri Ver', style: TextStyle(fontSize: 17)),
        ),
        const SizedBox(height: 12),
        if (v.verdigimEmirler.isNotEmpty)
          Panel(
            baslik: 'Verilen iş emirleri (son 3 gün)',
            child: Column(
              children: [
                for (final e in v.verdigimEmirler.take(30)) IsEmriKarti(e: e, formenGorunumu: true),
              ],
            ),
          ),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Personel, görev ya da çiftlik ara',
          ),
          onChanged: (s) => setState(() => _ara = s.trim()),
        ),
        const SizedBox(height: 8),
        if (!yonetici)
          Panel(
            baslik: 'Ekibim (${v.ekibim.length})',
            child: ekibim.isEmpty
                ? const Text(
                    'Ekibinize bağlı personel yok. Aşağıdaki listeden personeli ekibinize alın.',
                    style: TextStyle(color: Renk.soluk))
                : Column(
                    children: [
                      for (final x in ekibim)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(x.ad),
                          subtitle: Text([x.gorev, x.ciftlik].where((s) => s.isNotEmpty).join(' · ')),
                          trailing: PopupMenuButton<String>(
                            onSelected: (s) {
                              if (s == 'emir') {
                                Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => IsEmriFormu(personel: x.telefon)));
                              }
                              if (s == 'gorev') _gorevlendir(context, x, v.formenler);
                              if (s == 'cikar') _cikar(context, x);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'emir', child: Text('İş emri ver')),
                              PopupMenuItem(value: 'gorev', child: Text('Başka formene görevlendir')),
                              PopupMenuItem(value: 'cikar', child: Text('Ekipten çıkar')),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        Panel(
          baslik: yonetici ? 'Personel ve bağlı olduğu formen' : 'Ekibe bağlı olmayan personel (${v.atanabilir.length})',
          child: diger.isEmpty
              ? const Text('Kayıt yok.', style: TextStyle(color: Renk.soluk))
              : Column(
                  children: [
                    for (final x in diger)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(x.ad),
                        subtitle: Text([
                          x.gorev,
                          x.ciftlik,
                          if (yonetici) x.formenAd.isEmpty ? 'Formene bağlı değil' : 'Formen: ${x.formenAd}',
                        ].where((s) => s.isNotEmpty).join(' · ')),
                        trailing: yonetici
                            ? const Icon(Icons.swap_horiz)
                            : TextButton(
                                onPressed: () => islem(context, 'ekipAta',
                                    {'telefon': x.telefon, 'formen': v.kisi.telefon},
                                    basari: '${x.ad} ekibinize alındı.'),
                                child: const Text('Ekibime al'),
                              ),
                        onTap: yonetici ? () => _gorevlendir(context, x, v.formenler) : null,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
