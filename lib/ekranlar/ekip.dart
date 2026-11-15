import 'package:flutter/material.dart';

import '../servis/api.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesen.dart';
import 'is_emri.dart';
import 'organizasyon.dart';

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

  /// Yönetici: erişimi kapatma / programdan çıkarma (toplu).
  Future<void> _kullanici(List<String> telefonlar, String islem_) async {
    final cikar = islem_ == 'cikar';
    final evet = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(cikar ? 'Programdan çıkar' : 'Uygulama erişimini kapat'),
        content: Text(cikar
            ? '${telefonlar.length} kişi programdan tamamen çıkarılacak: uygulamaya giremez, ekip ve iş emri '
                'listelerinde görünmez; cihaz, ekip ve rol kayıtları silinir. Geçmiş kullanım, arıza ve iş emri '
                'kayıtları korunur. ${Depo.ben.veri!.kisi.yonetici ? 'Kullanıcılar ekranından geri alınabilir.' : 'Yöneticiye bildirim gider; geri alma Yöneticidedir.'}'
            : '${telefonlar.length} kişi uygulamaya giremeyecek. Ekibi, rolü ve kayıtları korunur; '
                'Kullanıcılar ekranından yeniden açılabilir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(
            style: cikar ? FilledButton.styleFrom(backgroundColor: Renk.kirmizi) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(cikar ? 'Programdan çıkar' : 'Erişimi kapat'),
          ),
        ],
      ),
    );
    if (evet != true || !mounted) return;
    final j = await islem(context, 'kullaniciIslem', {'telefonlar': telefonlar, 'islem': islem_});
    if (j != null && mounted) {
      setState(_secili.clear);
      final m = j['mesaj']?.toString() ?? '';
      if (m.isNotEmpty) bildir(context, m);
    }
  }

  /// Yönetici: Çiftlik Sorumlusu atama ve kapsam.
  Future<String?> _ciftlikSec(List<String> ciftlikler, String baslik) => showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(baslik, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('Tüm çiftlikler'),
                onTap: () => Navigator.pop(ctx, 'Tümü'),
              ),
              for (final c in ciftlikler)
                ListTile(leading: const Icon(Icons.agriculture_outlined), title: Text(c), onTap: () => Navigator.pop(ctx, c)),
            ],
          ),
        ),
      );

  Future<void> _sorumluAta(Veri v) async {
    final mevcut = {for (final c in v.ciftlikSorumlulari) c.telefon};
    var ara = '';
    final kisi = await showModalBottomSheet<PersonelKaydi>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          final l = v.personelTum
              .where((p) => !mevcut.contains(p.telefon) && p.telefon != v.kisi.telefon)
              .where((p) => ara.isEmpty || '${p.ad} ${p.gorev} ${p.ciftlik}'.toLowerCase().contains(ara))
              .toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.8,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8 + MediaQuery.of(ctx).viewInsets.bottom * 0),
                    child: TextField(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Personel ara'),
                      onChanged: (x) => ss(() => ara = x.trim().toLowerCase()),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final p in l)
                          ListTile(
                            title: Text(p.ad),
                            subtitle: Text([p.gorev, p.ciftlik].where((x) => x.isNotEmpty).join(' · ')),
                            onTap: () => Navigator.pop(ctx, p),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (kisi == null || !mounted) return;
    final c = await _ciftlikSec(v.ciftlikler, '${kisi.ad} · sorumlu olacağı çiftlik');
    if (c == null || !mounted) return;
    final j = await islem(context, 'ciftlikSorumlusuAta', {'telefon': kisi.telefon, 'ciftlik': c});
    if (j != null && mounted) bildir(context, j['mesaj']?.toString() ?? 'Atandı.');
  }

  Widget _sorumluPaneli(Veri v) => Panel(
        baslik: 'Çiftlik Sorumluları',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Kapsamındaki çiftliklerde personeli formenlere görevlendirir, iş emri verir ve günlük kayıtları onaylar.',
              style: TextStyle(color: Renk.soluk, fontSize: 12),
            ),
            for (final c in v.ciftlikSorumlulari)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined),
                title: Text(c.ad),
                subtitle: Text(c.ciftlik == 'Tümü' ? 'Tüm çiftlikler' : c.ciftlik),
                trailing: PopupMenuButton<String>(
                  onSelected: (x) async {
                    if (x == 'kapsam') {
                      final yeni = await _ciftlikSec(v.ciftlikler, '${c.ad} · sorumlu olacağı çiftlik');
                      if (yeni == null || !mounted) return;
                      final j = await islem(context, 'ciftlikSorumlusuAta', {'telefon': c.telefon, 'ciftlik': yeni});
                      if (j != null && mounted) bildir(context, j['mesaj']?.toString() ?? '');
                    }
                    if (x == 'kaldir') {
                      final j = await islem(context, 'ciftlikSorumlusuAta', {'telefon': c.telefon, 'kaldir': true});
                      if (j != null && mounted) bildir(context, j['mesaj']?.toString() ?? '');
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'kapsam', child: Text('Çiftliği değiştir')),
                    PopupMenuItem(value: 'kaldir', child: Text('Yetkiyi kaldır')),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => _sorumluAta(v),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Çiftlik Sorumlusu ata'),
            ),
          ],
        ),
      );

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
                    PopupMenuButton<String>(
                      onSelected: (s) {
                        if (s == 'al') {
                          _ata(seciliBosta, v.kisi.telefon, '${seciliBosta.length} personel ekibinize alındı.');
                          return;
                        }
                        if (s == 'erisim') {
                          _kullanici(seciliListe, 'kapat');
                          return;
                        }
                        if (s == 'program') {
                          _kullanici(seciliListe, 'cikar');
                          return;
                        }
                        final l = ust ? seciliListe : seciliBenim;
                        if (l.isEmpty) {
                          bildir(context, 'Yalnız kendi ekibinizdeki personeli görevlendirebilirsiniz.');
                          return;
                        }
                        if (s == 'gorev') _gorevlendir(l, v.formenler, haric: ust ? null : v.kisi.telefon);
                        if (s == 'cikar') _cikar(l);
                      },
                      itemBuilder: (_) => [
                        if (!ust && seciliBosta.isNotEmpty) const PopupMenuItem(value: 'al', child: Text('Ekibime al')),
                        const PopupMenuItem(value: 'gorev', child: Text('Formene görevlendir')),
                        const PopupMenuItem(value: 'cikar', child: Text('Ekipten çıkar')),
                        const PopupMenuDivider(),
                        if (v.kisi.yonetici)
                          const PopupMenuItem(value: 'erisim', child: Text('Uygulama erişimini kapat')),
                        PopupMenuItem(
                          value: 'program',
                          child: Text(v.kisi.yonetici ? 'Programdan çıkar' : 'Programdan çıkar (araç işi yapmıyor)',
                              style: const TextStyle(color: Renk.kirmizi)),
                        ),
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
          if (ust)
            Panel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_tree_outlined, color: Renk.ana, size: 32),
                title: const Text('Organizasyon Şeması', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(v.kisi.yonetici
                    ? 'Tüm personel çiftlik ve kademe sırasıyla. Kim kimden sorumlu ve nereye bakacak: düzeltme yetkisi sizde.'
                    : 'Tüm personel çiftlik ve kademe sırasıyla.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrganizasyonEkrani())),
              ),
            ),
          if (v.kisi.yonetici) _sorumluPaneli(v),
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
