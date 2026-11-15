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

  /// Kişinin bağlı olduğu amir: önce formen (ekip), yoksa organizasyon şemasındaki amir.
  Map<String, OrgKisi> _org = const {};
  String _amir(EkipUyesi x) => x.formen.isNotEmpty ? x.formen : (_org[x.telefon]?.ust ?? '');
  String _amirAd(EkipUyesi x) => x.formen.isNotEmpty ? x.formenAd : (_org[x.telefon]?.ustAd ?? '');

  bool _uyar(EkipUyesi x) {
    if (_formenFiltre != null) {
      final a = _amir(x);
      if (_formenFiltre == _bosta ? a.isNotEmpty : a != _formenFiltre) return false;
    }
    if (_ara.isEmpty) return true;
    final a = _ara.toLowerCase();
    return '${x.ad} ${x.gorev} ${x.ciftlik} ${_amirAd(x)}'.toLowerCase().contains(a);
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
    final v = Depo.ben.veri!;
    if (v.kisi.yonetici && v.organizasyon.isNotEmpty) return _amireBagla(v, telefonlar);
    final f = await _formenSec(formenler,
        haric: haric, baslik: '${telefonlar.length} personel · görevlendirilecek formen');
    if (f == null || !mounted) return;
    await _ata(telefonlar, f.telefon, '${telefonlar.length} personel ${f.ad} ekibine görevlendirildi.');
  }

  /// Yönetici: personeli bir amire bağlar. Amir formen ise ekibine görevlendirilir;
  /// formen değilse (ör. sorumlu veteriner hekim) organizasyon şemasında ona bağlanır.
  Future<void> _amireBagla(Veri v, List<String> telefonlar) async {
    var ara = '';
    final secenek = v.organizasyon.where((p) => !telefonlar.contains(p.telefon) && p.kademe != 'Saha Personeli').toList()
      ..sort((a, b) {
        final fa = a.kademe == 'Formen' ? 0 : 1, fb = b.kademe == 'Formen' ? 0 : 1;
        return fa != fb ? fa - fb : a.ad.compareTo(b.ad);
      });
    final amir = await showModalBottomSheet<OrgKisi>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          final l = secenek
              .where((p) => ara.isEmpty || '${p.ad} ${p.gorev} ${p.grup}'.toLowerCase().contains(ara))
              .toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.8,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('${telefonlar.length} personel · bağlanacağı amir',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Amir ara'),
                      onChanged: (x) => ss(() => ara = x.trim().toLowerCase()),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final p in l)
                          ListTile(
                            leading: Icon(p.kademe == 'Formen' ? Icons.engineering_outlined : Icons.badge_outlined,
                                color: p.kademe == 'Formen' ? Renk.yesil : Renk.mavi),
                            title: Text(p.ad),
                            subtitle: Text('${p.gorev} · ${p.grup}'),
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
    if (amir == null || !mounted) return;
    if (amir.kademe == 'Formen') {
      await _ata(telefonlar, amir.telefon, '${telefonlar.length} personel ${amir.ad} ekibine görevlendirildi.');
      return;
    }
    var tamam = 0;
    for (final t in telefonlar) {
      final kademe = _org[t]?.kademe ?? 'Saha Personeli';
      final j = await islem(context, 'orgDuzenle', {'telefon': t, 'kademe': kademe, 'ust': amir.telefon}, yenile: false);
      if (!mounted) return;
      if (j == null) break;
      tamam++;
    }
    setState(_secili.clear);
    if (tamam > 0) bildir(context, '$tamam personel ${amir.ad} kişisine bağlandı.');
    await Depo.ben.yenile();
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

  /// Yönetici: Çiftlik Sorumluları (kapalı başlayan bölüm).
  Widget _sorumluPaneli(Veri v) => Panel(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: const Icon(Icons.badge_outlined, color: Renk.mavi),
            title: Text('Çiftlik Sorumluları (${v.ciftlikSorumlulari.length})',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Personel görevlendirme, iş emri ve günlük onay yetkisi',
                style: TextStyle(fontSize: 12, color: Renk.soluk)),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            children: [
              for (final c in v.ciftlikSorumlulari)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: _Bas(c.ad, renk: Renk.mavi),
                  title: Text(c.ad, style: const TextStyle(fontWeight: FontWeight.w600)),
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
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _sorumluAta(v),
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Çiftlik Sorumlusu ata'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _satir(EkipUyesi x, {required bool ustYonetim, required bool benim}) {
    final secili = _secili.contains(x.telefon);
    final amirAd = _amirAd(x);
    final amirFormen = x.formen.isNotEmpty;
    final alt = [
      x.gorev,
      if (ustYonetim) x.ciftlik,
      if (ustYonetim || !benim)
        amirAd.isEmpty ? 'Amiri belirlenmemiş' : (amirFormen ? 'Formen: $amirAd' : 'Bağlı: $amirAd'),
    ].where((s) => s.isNotEmpty).join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => secili ? _secili.remove(x.telefon) : _secili.add(x.telefon)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _Bas(x.ad, renk: secili ? Renk.ana : Renk.soluk, secili: secili),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(x.ad, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(alt, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: amirAd.isEmpty && ustYonetim ? Renk.amber : Renk.soluk)),
                ],
              ),
            ),
            if (benim)
              IconButton(
                tooltip: 'İş emri ver',
                icon: const Icon(Icons.assignment_ind_outlined, color: Renk.ana),
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => IsEmriFormu(personel: x.telefon))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filtre(String etiket, String? deger, {IconData? ikon}) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          avatar: ikon == null ? null : Icon(ikon, size: 16),
          label: Text(etiket),
          selected: _formenFiltre == deger,
          onSelected: (s) => setState(() => _formenFiltre = s ? deger : null),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final v = Depo.ben.veri!;
    final ust = v.kisi.ustYonetim;
    _org = {for (final o in v.organizasyon) o.telefon: o};
    final tum = [...v.ekibim, ...v.atanabilir];
    // Amir (formen ya da şemadaki amir) bazında dağılım
    final dagilim = <String, int>{};
    final amirAdi = <String, String>{};
    var bosta = 0;
    for (final x in tum) {
      final a = _amir(x);
      if (a.isEmpty) {
        bosta++;
      } else {
        dagilim[a] = (dagilim[a] ?? 0) + 1;
        amirAdi.putIfAbsent(a, () => _amirAd(x));
      }
    }
    final amirler = dagilim.keys.toList()..sort((a, b) => (amirAdi[a] ?? '').compareTo(amirAdi[b] ?? ''));
    final ekibim = v.ekibim.where(_uyar).toList();
    final diger = v.atanabilir.where(_uyar).toList();
    final liste = [...ekibim, ...diger];
    final seciliListe = _secili.toList();
    final seciliBenim = seciliListe.where((t) => v.ekibim.any((x) => x.telefon == t)).toList();
    final seciliBosta = seciliListe.where((t) => v.atanabilir.any((x) => x.telefon == t && x.formen.isEmpty)).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: _secili.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
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
                        PopupMenuItem(
                            value: 'gorev',
                            child: Text(v.kisi.yonetici ? 'Amire bağla / görevlendir' : 'Formene görevlendir')),
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: Renk.ana, borderRadius: BorderRadius.circular(20)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz, size: 18, color: Colors.white),
                            SizedBox(width: 6),
                            Text('İşlem', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: YenilenirListe(
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(64, 52)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IsEmriFormu())),
                  icon: const Icon(Icons.assignment_ind_outlined),
                  label: const Text('İş Emri Ver', style: TextStyle(fontSize: 16)),
                ),
              ),
              if (ust) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(64, 52)),
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const OrganizasyonEkrani())),
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('Organizasyon', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (v.kisi.yonetici) _sorumluPaneli(v),
          Panel(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(ust ? 'Personel (${liste.length})' : 'Ekip ve personel (${liste.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    TextButton(
                      onPressed: liste.isEmpty
                          ? null
                          : () => setState(() => _secili.addAll(liste.map((x) => x.telefon))),
                      child: const Text('Tümünü seç'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Personel ara'),
                  onChanged: (s) => setState(() => _ara = s.trim()),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _filtre('Tümü (${tum.length})', null),
                      if (ust)
                        for (final a in amirler) _filtre('${amirAdi[a] ?? a} (${dagilim[a]})', a)
                      else
                        _filtre('Ekibim (${v.ekibim.length})', v.kisi.telefon),
                      _filtre('Amiri belirlenmemiş ($bosta)', _bosta, ikon: Icons.person_off_outlined),
                    ],
                  ),
                ),
                const Divider(height: 20),
                if (liste.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Kayıt yok.', textAlign: TextAlign.center, style: TextStyle(color: Renk.soluk)),
                  )
                else ...[
                  for (final x in ekibim) _satir(x, ustYonetim: false, benim: true),
                  for (final x in diger) _satir(x, ustYonetim: ust, benim: false),
                ],
              ],
            ),
          ),
          const SizedBox(height: 70),
        ],
      ),
    );
  }
}

/// Baş harfli yuvarlak; seçiliyse onay işareti.
class _Bas extends StatelessWidget {
  const _Bas(this.ad, {required this.renk, this.secili = false});
  final String ad;
  final Color renk;
  final bool secili;

  @override
  Widget build(BuildContext context) {
    final p = ad.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final b = p.isEmpty ? '?' : (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: secili ? Renk.ana : renk.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: secili
          ? const Icon(Icons.check, color: Colors.white, size: 20)
          : Text(b, style: TextStyle(color: renk, fontWeight: FontWeight.w700, fontSize: 14)),
    );
  }
}
