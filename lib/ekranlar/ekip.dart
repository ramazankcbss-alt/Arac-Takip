import 'package:flutter/material.dart';

import '../servis/api.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesen.dart';
import 'is_emri.dart';

/// Ekipler: personel formene bağlanır; çiftlikler arası geçişte personel başka
/// formene görevlendirilir. Toplu seçim ve formen bazında dağılım.
/// - Formen: kendi ekibi + hiçbir ekibe bağlı olmayan personel.
/// - Yönetici / Çiftlik Sorumlusu: kapsamındaki tüm personel ve formen dağılımı.
class EkipSayfasi extends StatefulWidget {
  const EkipSayfasi({super.key});

  @override
  State<EkipSayfasi> createState() => _EkipSayfasiState();
}

const _bosta = '__bosta__';

class _EkipSayfasiState extends State<EkipSayfasi> {
  String _ara = '';
  String? _formenFiltre; // formen telefonu ya da _bosta
  final _secili = <String>{};

  bool _uyar(EkipUyesi x) {
    if (_formenFiltre != null) {
      if (_formenFiltre == _bosta ? x.formen.isNotEmpty : x.formen != _formenFiltre) return false;
    }
    if (_ara.isEmpty) return true;
    final a = _ara.toLowerCase();
    return '${x.ad} ${x.gorev} ${x.ciftlik} ${x.formenAd}'.toLowerCase().contains(a);
  }

  Future<Formen?> _formenSec(List<Formen> l, {String? haric, required String baslik}) {
    final secenek = l.where((f) => f.telefon != haric).toList();
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
                child: Text(baslik, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

  Future<void> _ata(List<String> telefonlar, String formen, String basari) async {
    final j = await islem(context, 'ekipAta', {'telefonlar': telefonlar, 'formen': formen}, basari: basari);
    if (j != null && mounted) {
      setState(_secili.clear);
      final uyari = j['uyari']?.toString() ?? '';
      if (uyari.isNotEmpty) bildir(context, uyari);
    }
  }

  Future<void> _gorevlendir(List<String> telefonlar, List<Formen> formenler, {String? haric}) async {
    final f = await _formenSec(formenler,
        haric: haric, baslik: '${telefonlar.length} personel · görevlendirilecek formen');
    if (f == null || !mounted) return;
    await _ata(telefonlar, f.telefon, '${telefonlar.length} personel ${f.ad} ekibine görevlendirildi.');
  }

  Future<void> _cikar(List<String> telefonlar) async {
    final evet = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ekipten çıkar'),
        content: Text('${telefonlar.length} personel ekipten çıkarılsın mı? '
            'Bu personel formene bağlı olmayan personel listesine geçer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Çıkar')),
        ],
      ),
    );
    if (evet == true && mounted) await _ata(telefonlar, '', '${telefonlar.length} personel ekipten çıkarıldı.');
  }

  Widget _satir(EkipUyesi x, {required bool ustYonetim, required bool benim}) {
    final secili = _secili.contains(x.telefon);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: secili,
      onChanged: (s) => setState(() => s == true ? _secili.add(x.telefon) : _secili.remove(x.telefon)),
      title: Text(x.ad),
      subtitle: Text([
        x.gorev,
        x.ciftlik,
        if (ustYonetim) x.formenAd.isEmpty ? 'Formene bağlı değil' : 'Formen: ${x.formenAd}',
      ].where((s) => s.isNotEmpty).join(' · ')),
      secondary: benim
          ? IconButton(
              tooltip: 'İş emri ver',
              icon: const Icon(Icons.assignment_ind_outlined),
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => IsEmriFormu(personel: x.telefon))),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = Depo.ben.veri!;
    final ust = v.kisi.ustYonetim;
    final tum = [...v.ekibim, ...v.atanabilir];
    // Formen bazında dağılım
    final dagilim = <String, int>{};
    final formenAdi = {for (final f in v.formenler) f.telefon: f.ad};
    var bosta = 0;
    for (final x in tum) {
      if (x.formen.isEmpty) {
        bosta++;
      } else {
        dagilim[x.formen] = (dagilim[x.formen] ?? 0) + 1;
        formenAdi.putIfAbsent(x.formen, () => x.formenAd);
      }
    }
    final ekibim = v.ekibim.where(_uyar).toList();
    final diger = v.atanabilir.where(_uyar).toList();
    final seciliListe = _secili.toList();
    final seciliBenim = seciliListe.where((t) => v.ekibim.any((x) => x.telefon == t)).toList();
    final seciliBosta = seciliListe.where((t) => v.atanabilir.any((x) => x.telefon == t && x.formen.isEmpty)).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: _secili.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: const BoxDecoration(
                    color: Colors.white, border: Border(top: BorderSide(color: Renk.cizgi))),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${_secili.length} kişi seçildi',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    TextButton(onPressed: () => setState(_secili.clear), child: const Text('Temizle')),
                    if (!ust && seciliBosta.isNotEmpty && seciliBenim.isEmpty)
                      FilledButton(
                        onPressed: () =>
                            _ata(seciliBosta, v.kisi.telefon, '${seciliBosta.length} personel ekibinize alındı.'),
                        child: const Text('Ekibime al'),
                      )
                    else
                      PopupMenuButton<String>(
                        onSelected: (s) {
                          final l = ust ? seciliListe : seciliBenim;
                          if (l.isEmpty) {
                            bildir(context, 'Yalnız kendi ekibinizdeki personeli görevlendirebilirsiniz.');
                            return;
                          }
                          if (s == 'gorev') _gorevlendir(l, v.formenler, haric: ust ? null : v.kisi.telefon);
                          if (s == 'cikar') _cikar(l);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'gorev', child: Text('Formene görevlendir')),
                          PopupMenuItem(value: 'cikar', child: Text('Ekipten çıkar')),
                        ],
                        child: const Chip(
                          avatar: Icon(Icons.swap_horiz, size: 18),
                          label: Text('İşlem'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      body: YenilenirListe(
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IsEmriFormu())),
            icon: const Icon(Icons.assignment_ind_outlined),
            label: const Text('İş Emri Ver', style: TextStyle(fontSize: 17)),
          ),
          const SizedBox(height: 12),
          Panel(
            baslik: ust ? 'Formenlere göre personel dağılımı' : 'Ekip durumu',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (ust)
                  for (final f in (dagilim.keys.toList()..sort((a, b) => (formenAdi[a] ?? '').compareTo(formenAdi[b] ?? ''))))
                    ChoiceChip(
                      label: Text('${formenAdi[f] ?? f} (${dagilim[f]})'),
                      selected: _formenFiltre == f,
                      onSelected: (s) => setState(() => _formenFiltre = s ? f : null),
                    )
                else
                  ChoiceChip(
                    label: Text('Ekibim (${v.ekibim.length})'),
                    selected: _formenFiltre == v.kisi.telefon,
                    onSelected: (s) => setState(() => _formenFiltre = s ? v.kisi.telefon : null),
                  ),
                ChoiceChip(
                  avatar: const Icon(Icons.person_off_outlined, size: 18),
                  label: Text('Formene bağlı olmayan ($bosta)'),
                  selected: _formenFiltre == _bosta,
                  onSelected: (s) => setState(() => _formenFiltre = s ? _bosta : null),
                ),
                if (ust)
                  for (final f in v.formenler.where((f) => !dagilim.containsKey(f.telefon)))
                    ChoiceChip(
                      label: Text('${f.ad} (0)'),
                      selected: false,
                      onSelected: (_) {},
                    ),
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
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.select_all, size: 18),
              label: const Text('Listelenenlerin tümünü seç'),
              onPressed: () => setState(() => _secili.addAll([...ekibim, ...diger].map((x) => x.telefon))),
            ),
          ),
          if (!ust && v.ekibim.isNotEmpty && (_formenFiltre == null || _formenFiltre == v.kisi.telefon))
            Panel(
              baslik: 'Ekibim (${v.ekibim.length})',
              child: ekibim.isEmpty
                  ? const Text('Kayıt yok.', style: TextStyle(color: Renk.soluk))
                  : Column(children: [for (final x in ekibim) _satir(x, ustYonetim: false, benim: true)]),
            ),
          if (_formenFiltre != v.kisi.telefon || ust)
            Panel(
              baslik: ust ? 'Personel (${diger.length})' : 'Ekibe bağlı olmayan personel (${diger.length})',
              child: diger.isEmpty
                  ? const Text('Kayıt yok.', style: TextStyle(color: Renk.soluk))
                  : Column(children: [for (final x in diger) _satir(x, ustYonetim: ust, benim: false)]),
            ),
          const SizedBox(height: 70),
        ],
      ),
    );
  }
}
