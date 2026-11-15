import 'package:flutter/material.dart';

import '../servis/api.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesen.dart';

/// Organizasyon şeması: tüm personel çiftlik bazında, kurumsal hiyerarşiye göre
/// (Merkez Yönetim → Çiftlik Yönetimi → Uzman ve Teknik Personel → Formen → Saha Personeli).
/// Yönetici her kişinin kademesini, bağlı olduğu amiri, çiftliğini ve görüş kapsamını düzeltir.
class OrganizasyonEkrani extends StatefulWidget {
  const OrganizasyonEkrani({super.key});

  @override
  State<OrganizasyonEkrani> createState() => _OrganizasyonEkraniState();
}

const _merkez = 'Merkez Yönetim';

IconData _ikon(String kademe) {
  switch (kademe) {
    case 'Merkez Yönetim':
      return Icons.account_balance_outlined;
    case 'Çiftlik Yönetimi':
      return Icons.badge_outlined;
    case 'Uzman ve Teknik Personel':
      return Icons.science_outlined;
    case 'Formen':
      return Icons.engineering_outlined;
    case 'Destek Hizmetleri':
      return Icons.shield_outlined;
    default:
      return Icons.person_outline;
  }
}

Color _renk(String kademe) {
  switch (kademe) {
    case 'Merkez Yönetim':
      return Renk.anaKoyu;
    case 'Çiftlik Yönetimi':
      return Renk.mavi;
    case 'Uzman ve Teknik Personel':
      return Renk.turuncu;
    case 'Formen':
      return Renk.yesil;
    case 'Destek Hizmetleri':
      return Renk.soluk;
    default:
      return Renk.yazi;
  }
}

class _OrganizasyonEkraniState extends State<OrganizasyonEkrani> {
  String _ara = '';
  String? _grup;

  List<String> _gruplar(List<OrgKisi> l) {
    final g = l.map((x) => x.grup).toSet().toList()
      ..sort((a, b) {
        if (a == _merkez) return -1;
        if (b == _merkez) return 1;
        return a.compareTo(b);
      });
    return g;
  }

  int _sira(Veri v, OrgKisi a, OrgKisi b) {
    final k = v.kademeler.indexOf(a.kademe).compareTo(v.kademeler.indexOf(b.kademe));
    return k != 0 ? k : a.ad.compareTo(b.ad);
  }

  Future<void> _duzenle(Veri v, OrgKisi x) async {
    final kaydedildi = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DuzenleFormu(v: v, x: x),
    );
    if (kaydedildi == true && mounted) setState(() {});
  }

  Widget _kisi(Veri v, OrgKisi x, int derinlik, {required bool yonetici, String? disAmir}) {
    final altBilgi = [
      if (x.gorev.isNotEmpty) x.gorev,
      if (disAmir != null) 'Bağlı olduğu: $disAmir',
      'Görüş: ${x.kapsamMetni}',
    ].join(' · ');
    return Padding(
      padding: EdgeInsets.only(left: derinlik * 18.0),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 4, right: 0),
        leading: Icon(_ikon(x.kademe), color: _renk(x.kademe)),
        title: Row(
          children: [
            Flexible(child: Text(x.ad, style: const TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(width: 6),
            Rozet(x.kademe, renk: _renk(x.kademe), zemin: Renk.zemin),
          ],
        ),
        subtitle: Text(altBilgi),
        trailing: yonetici
            ? IconButton(
                tooltip: 'Düzelt',
                icon: Icon(x.duzeltildi ? Icons.edit_note : Icons.edit_outlined,
                    color: x.duzeltildi ? Renk.ana : Renk.soluk),
                onPressed: () => _duzenle(v, x),
              )
            : null,
      ),
    );
  }

  /// Kişi ve (varsa) ona bağlı olanlar; formen ekipleri kapalı başlar.
  List<Widget> _agac(Veri v, OrgKisi x, Map<String, List<OrgKisi>> altlar, int derinlik, bool yonetici,
      Set<String> gorulen) {
    if (!gorulen.add(x.telefon)) return const [];
    final cocuk = altlar[x.telefon] ?? const <OrgKisi>[];
    if (cocuk.isEmpty) return [_kisi(v, x, derinlik, yonetici: yonetici)];
    return [
      Padding(
        padding: EdgeInsets.only(left: derinlik * 18.0),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.only(left: 4),
            childrenPadding: EdgeInsets.zero,
            initiallyExpanded: x.kademe != 'Formen',
            leading: Icon(_ikon(x.kademe), color: _renk(x.kademe)),
            title: Text(x.ad, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${x.kademe} · ${x.gorev} · ${cocuk.length} kişi bağlı · Görüş: ${x.kapsamMetni}',
                style: const TextStyle(fontSize: 12)),
            trailing: yonetici
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Düzelt',
                        icon: Icon(x.duzeltildi ? Icons.edit_note : Icons.edit_outlined,
                            color: x.duzeltildi ? Renk.ana : Renk.soluk),
                        onPressed: () => _duzenle(v, x),
                      ),
                      const Icon(Icons.expand_more),
                    ],
                  )
                : null,
            children: [
              for (final c in cocuk) ..._agac(v, c, altlar, 1, yonetici, gorulen),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _grupPaneli(Veri v, String grup, List<OrgKisi> l, bool yonetici) {
    final telefonlar = {for (final x in l) x.telefon};
    final altlar = <String, List<OrgKisi>>{};
    final kok = <OrgKisi>[];
    final tumu = {for (final x in v.organizasyon) x.telefon: x};
    for (final x in l) {
      if (x.ust.isNotEmpty && telefonlar.contains(x.ust)) {
        (altlar[x.ust] ??= []).add(x);
      } else {
        kok.add(x);
      }
    }
    for (final a in altlar.values) {
      a.sort((p, q) => _sira(v, p, q));
    }
    kok.sort((p, q) => _sira(v, p, q));
    final sayim = <String, int>{};
    for (final x in l) {
      sayim[x.kademe] = (sayim[x.kademe] ?? 0) + 1;
    }
    final gorulen = <String>{};
    return Panel(
      baslik: '$grup (${l.length} kişi)',
      padding: const EdgeInsets.fromLTRB(12, 14, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final k in v.kademeler)
                if ((sayim[k] ?? 0) > 0) Rozet('$k: ${sayim[k]}', renk: _renk(k), zemin: Renk.zemin),
            ],
          ),
          const SizedBox(height: 6),
          for (final x in kok)
            if (x.ust.isNotEmpty && !telefonlar.contains(x.ust) && (altlar[x.telefon] ?? const []).isEmpty)
              _kisi(v, x, 0, yonetici: yonetici, disAmir: '${tumu[x.ust]?.ad ?? x.ustAd} (${tumu[x.ust]?.grup ?? ''})')
            else
              ..._agac(v, x, altlar, 0, yonetici, gorulen),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Depo.ben,
      builder: (context, _) {
        final v = Depo.ben.veri!;
        final yonetici = v.kisi.yonetici;
        final gruplar = _gruplar(v.organizasyon);
        final q = _ara.toLowerCase();
        final aramada = q.isNotEmpty;
        final liste = v.organizasyon
            .where((x) => _grup == null || x.grup == _grup)
            .where((x) => !aramada ||
                '${x.ad} ${x.gorev} ${x.grup} ${x.kademe} ${x.ustAd}'.toLowerCase().contains(q))
            .toList();
        return Scaffold(
          appBar: AppBar(title: const UygulamaBasligi(baslik: 'Organizasyon Şeması')),
          body: YenilenirListe(
            children: [
              Text(
                yonetici
                    ? 'Personel çiftlik ve kademe sırasıyla listelenir. Kalem simgesiyle kişinin kademesini, bağlı olduğu '
                        'amiri, çiftliğini ve görüş kapsamını düzeltebilirsiniz.'
                    : 'Personel çiftlik ve kademe sırasıyla listelenir.',
                style: const TextStyle(color: Renk.soluk, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Ad, görev, kademe ya da çiftlik'),
                onChanged: (s) => setState(() => _ara = s.trim()),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('Tümü (${v.organizasyon.length})'),
                      selected: _grup == null,
                      onSelected: (_) => setState(() => _grup = null),
                    ),
                    for (final g in gruplar)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text('$g (${v.organizasyon.where((x) => x.grup == g).length})'),
                          selected: _grup == g,
                          onSelected: (s) => setState(() => _grup = s ? g : null),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (v.organizasyon.isEmpty)
                const Bos('Organizasyon bilgisi yok. Sunucu kodunun güncel sürümü dağıtıldıktan sonra listelenir.')
              else if (aramada)
                Panel(
                  baslik: 'Arama sonucu (${liste.length})',
                  padding: const EdgeInsets.fromLTRB(12, 14, 4, 8),
                  child: Column(
                    children: [
                      for (final x in (liste..sort((a, b) => _sira(v, a, b))))
                        _kisi(v, x, 0,
                            yonetici: yonetici, disAmir: x.ustAd.isEmpty ? null : '${x.ustAd} · ${x.grup}'),
                    ],
                  ),
                )
              else
                for (final g in gruplar)
                  if (_grup == null || _grup == g)
                    _grupPaneli(v, g, v.organizasyon.where((x) => x.grup == g).toList(), yonetici),
            ],
          ),
        );
      },
    );
  }
}

/// Yönetici: kademe, bağlı olduğu amir, çiftlik ve görüş kapsamı düzeltmesi.
class _DuzenleFormu extends StatefulWidget {
  const _DuzenleFormu({required this.v, required this.x});
  final Veri v;
  final OrgKisi x;

  @override
  State<_DuzenleFormu> createState() => _DuzenleFormuState();
}

class _DuzenleFormuState extends State<_DuzenleFormu> {
  late String _kademe = widget.x.kademe;
  late String _ust = widget.x.ust;
  late String _ciftlik = widget.x.ciftlik;
  late Set<String> _kapsam = widget.x.kapsamOzel ? widget.x.kapsam.toSet() : <String>{};

  List<String> get _ciftlikler => widget.v.ciftlikler
      .where((c) => !c.toUpperCase().contains('DİREKTÖRLÜĞÜ') && !c.toUpperCase().contains('MÜDÜRLÜĞÜ'))
      .toList();

  OrgKisi? _kisi(String t) {
    for (final x in widget.v.organizasyon) {
      if (x.telefon == t) return x;
    }
    return null;
  }

  Future<void> _amirSec() async {
    var ara = '';
    final secim = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          final l = widget.v.organizasyon
              .where((p) => p.telefon != widget.x.telefon)
              .where((p) => ara.isEmpty || '${p.ad} ${p.gorev} ${p.grup} ${p.kademe}'.toLowerCase().contains(ara))
              .toList()
            ..sort((a, b) {
              final k = widget.v.kademeler.indexOf(a.kademe).compareTo(widget.v.kademeler.indexOf(b.kademe));
              return k != 0 ? k : a.ad.compareTo(b.ad);
            });
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.8,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Amir ara'),
                      onChanged: (s) => ss(() => ara = s.trim().toLowerCase()),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.link_off),
                    title: const Text('Bağlı olduğu amir yok'),
                    onTap: () => Navigator.pop(ctx, ''),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final p in l)
                          ListTile(
                            leading: Icon(_ikon(p.kademe), color: _renk(p.kademe)),
                            title: Text(p.ad),
                            subtitle: Text('${p.kademe} · ${p.gorev} · ${p.grup}'),
                            onTap: () => Navigator.pop(ctx, p.telefon),
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
    if (secim != null) setState(() => _ust = secim);
  }

  Future<void> _kaydet({bool sifirla = false}) async {
    final alan = sifirla
        ? {'telefon': widget.x.telefon, 'sifirla': true}
        : {
            'telefon': widget.x.telefon,
            'kademe': _kademe,
            'ust': _ust,
            'ciftlik': _ciftlik == widget.x.ciftlik && !widget.x.kademeOzel ? '' : _ciftlik,
            'kapsam': _kapsam.toList(),
          };
    final j = await islem(context, 'orgDuzenle', alan);
    if (j == null || !mounted) return;
    final uyari = j['uyari']?.toString() ?? '';
    Navigator.pop(context, true);
    bildir(context, [j['mesaj']?.toString() ?? 'Kaydedildi.', if (uyari.isNotEmpty) uyari].join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    final x = widget.x;
    final amir = _kisi(_ust);
    final ciftlikSecenek = {..._ciftlikler, if (_ciftlik.isNotEmpty && _ciftlik != 'Tümü') _ciftlik}.toList()..sort();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Text(x.ad, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text([x.gorev, x.birim].where((s) => s.isNotEmpty).join(' · '),
                  style: const TextStyle(color: Renk.soluk)),
              if (x.guncelleme.isNotEmpty)
                Text('Son düzeltme: ${x.guncelleyen}, ${x.guncelleme}',
                    style: const TextStyle(color: Renk.soluk, fontSize: 12)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: widget.v.kademeler.contains(_kademe) ? _kademe : null,
                decoration: const InputDecoration(labelText: 'Kademe'),
                items: [for (final k in widget.v.kademeler) DropdownMenuItem(value: k, child: Text(k))],
                onChanged: (s) => setState(() => _kademe = s ?? _kademe),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Formen kademesi formen yetkisi verir; Formen ve Saha Personeli araç-makine kadrosudur.',
                    style: TextStyle(color: Renk.soluk, fontSize: 12)),
              ),
              const SizedBox(height: 14),
              const Text('Kimden sorumlu / kime bağlı', style: TextStyle(fontWeight: FontWeight.w600)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(amir == null ? Icons.link_off : _ikon(amir.kademe)),
                title: Text(amir == null ? 'Bağlı olduğu amir yok' : amir.ad),
                subtitle: Text(amir == null ? 'Seçmek için dokunun' : '${amir.kademe} · ${amir.grup}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _amirSec,
              ),
              if (amir != null && amir.kademe == 'Formen' && _kademe == 'Saha Personeli')
                const Text('Kişi bu formenin ekibine görevlendirilir; araç kayıtlarını bu formen onaylar.',
                    style: TextStyle(color: Renk.soluk, fontSize: 12)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: ciftlikSecenek.contains(_ciftlik) ? _ciftlik : null,
                decoration: const InputDecoration(labelText: 'Bağlı olduğu çiftlik'),
                items: [for (final c in ciftlikSecenek) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (s) => setState(() => _ciftlik = s ?? _ciftlik),
              ),
              const SizedBox(height: 14),
              const Text('Görüş kapsamı (nereye bakacak)', style: TextStyle(fontWeight: FontWeight.w600)),
              const Text('Seçilmezse kendi çiftliği esas alınır.', style: TextStyle(color: Renk.soluk, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  FilterChip(
                    label: const Text('Tüm çiftlikler'),
                    selected: _kapsam.contains('Tümü'),
                    onSelected: (s) => setState(() => _kapsam = s ? {'Tümü'} : <String>{}),
                  ),
                  for (final c in _ciftlikler)
                    FilterChip(
                      label: Text(c),
                      selected: _kapsam.contains(c),
                      onSelected: _kapsam.contains('Tümü')
                          ? null
                          : (s) => setState(() => s ? _kapsam.add(c) : _kapsam.remove(c)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 50)),
                onPressed: _kaydet,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Kaydet'),
              ),
              if (x.duzeltildi) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _kaydet(sifirla: true),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Otomatik değerlere dön'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
