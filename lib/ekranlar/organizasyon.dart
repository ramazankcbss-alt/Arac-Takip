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

String _bas(String ad) {
  final p = ad.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
}

class _OrganizasyonEkraniState extends State<OrganizasyonEkrani> {
  String _ara = '';
  String? _grup;
  final Set<String> _acik = {};
  bool _hazir = false;

  int _sira(Veri v, OrgKisi a, OrgKisi b) {
    final k = v.kademeler.indexOf(a.kademe).compareTo(v.kademeler.indexOf(b.kademe));
    return k != 0 ? k : a.ad.compareTo(b.ad);
  }

  List<String> _gruplar(List<OrgKisi> l) => l.map((x) => x.grup).toSet().toList()
    ..sort((a, b) {
      if (a == _merkez) return -1;
      if (b == _merkez) return 1;
      return a.compareTo(b);
    });

  /// Kişi → bağlı olanlar; [kapsam] verilirse yalnız o kişiler arasında kurulur.
  Map<String, List<OrgKisi>> _altlar(Veri v, Iterable<OrgKisi> l) {
    final tel = {for (final x in l) x.telefon};
    final m = <String, List<OrgKisi>>{};
    for (final x in l) {
      if (x.ust.isNotEmpty && tel.contains(x.ust)) (m[x.ust] ??= []).add(x);
    }
    for (final a in m.values) {
      a.sort((p, q) => _sira(v, p, q));
    }
    return m;
  }

  void _ilkAcilis(Veri v) {
    if (_hazir || v.organizasyon.isEmpty) return;
    _hazir = true;
    final altlar = _altlar(v, v.organizasyon);
    // Üst kademeler açık, formen ekipleri kapalı başlar.
    for (final x in v.organizasyon) {
      if ((altlar[x.telefon] ?? const []).isNotEmpty && x.kademe != 'Formen') _acik.add(x.telefon);
    }
  }

  Future<void> _detay(Veri v, OrgKisi x, int bagli) async {
    final amir = v.organizasyon.where((p) => p.telefon == x.ust).firstOrNull;
    final duzenle = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Avatar(x),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(x.ad, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(x.gorev, style: const TextStyle(color: Renk.soluk)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              BilgiSatiri('Kademe', x.kademe),
              BilgiSatiri('Çiftlik', x.grup),
              BilgiSatiri('Bağlı olduğu amir', amir == null ? 'Belirlenmemiş' : '${amir.ad} (${amir.gorev})'),
              BilgiSatiri('Bağlı personel', bagli == 0 ? 'Yok' : '$bagli kişi'),
              BilgiSatiri('Görüş kapsamı', x.kapsamMetni),
              if (x.guncelleme.isNotEmpty) BilgiSatiri('Son düzeltme', '${x.guncelleyen}, ${x.guncelleme}'),
              if (v.kisi.yonetici) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Düzenle'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (duzenle == true && mounted) {
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _DuzenleFormu(v: v, x: x),
      );
      if (mounted) setState(() {});
    }
  }

  /// Ağacı düz satır listesine çevirir (girinti çizgileriyle).
  void _satirlar(Veri v, OrgKisi x, Map<String, List<OrgKisi>> altlar, int seviye, List<Widget> out,
      Set<String> gorulen, {bool ciftlikGoster = false}) {
    if (!gorulen.add(x.telefon)) return;
    final cocuk = altlar[x.telefon] ?? const <OrgKisi>[];
    final acik = _acik.contains(x.telefon);
    out.add(_Satir(
      x: x,
      seviye: seviye,
      bagli: cocuk.length,
      acik: acik,
      ciftlik: ciftlikGoster,
      onAc: cocuk.isEmpty ? null : () => setState(() => acik ? _acik.remove(x.telefon) : _acik.add(x.telefon)),
      onDetay: () => _detay(v, x, cocuk.length),
    ));
    if (acik) {
      for (final c in cocuk) {
        _satirlar(v, c, altlar, seviye + 1, out, gorulen, ciftlikGoster: ciftlikGoster && c.grup != x.grup);
      }
    }
  }

  List<Widget> _agacListesi(Veri v, List<OrgKisi> l, {required bool ciftlikGoster}) {
    final altlar = _altlar(v, l);
    final tel = {for (final x in l) x.telefon};
    final kok = l.where((x) => x.ust.isEmpty || !tel.contains(x.ust)).toList()..sort((a, b) => _sira(v, a, b));
    final out = <Widget>[];
    final gorulen = <String>{};
    for (final x in kok) {
      _satirlar(v, x, altlar, 0, out, gorulen, ciftlikGoster: ciftlikGoster);
    }
    return out;
  }

  Widget _bolum(String baslik, List<Widget> satirlar, {String? not}) => Panel(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 6),
              child: Text(baslik, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (not != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Text(not, style: const TextStyle(color: Renk.soluk, fontSize: 12)),
              ),
            ...satirlar,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Depo.ben,
      builder: (context, _) {
        final v = Depo.ben.veri!;
        _ilkAcilis(v);
        final gruplar = _gruplar(v.organizasyon);
        final q = _ara.toLowerCase();
        final govde = <Widget>[];
        if (v.organizasyon.isEmpty) {
          govde.add(const Bos('Organizasyon bilgisi yok. Sunucu kodunun güncel sürümü dağıtıldıktan sonra listelenir.'));
        } else if (q.isNotEmpty) {
          final l = v.organizasyon
              .where((x) => '${x.ad} ${x.gorev} ${x.grup} ${x.kademe}'.toLowerCase().contains(q))
              .toList()
            ..sort((a, b) => _sira(v, a, b));
          govde.add(_bolum('Arama sonucu (${l.length})', [
            for (final x in l)
              _Satir(x: x, seviye: 0, bagli: 0, acik: false, ciftlik: true, onDetay: () => _detay(v, x, 0)),
          ]));
        } else if (_grup == null) {
          // Hiyerarşi: bağlantısı olan herkes tek ağaçta; amiri belirlenmemiş olanlar ayrı bölümde.
          final altlar = _altlar(v, v.organizasyon);
          final bagliMi = (OrgKisi x) =>
              x.ust.isNotEmpty || (altlar[x.telefon] ?? const []).isNotEmpty || x.kademe == _merkez;
          final zincir = v.organizasyon.where(bagliMi).toList();
          final bos = v.organizasyon.where((x) => !bagliMi(x)).toList()..sort((a, b) => _sira(v, a, b));
          govde.add(_bolum('Kurumsal hiyerarşi', _agacListesi(v, zincir, ciftlikGoster: true)));
          if (bos.isNotEmpty) {
            final satir = <Widget>[];
            for (final g in _gruplar(bos)) {
              satir.add(Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 2),
                child: Text(g, style: const TextStyle(fontWeight: FontWeight.w700, color: Renk.anaKoyu)),
              ));
              for (final x in bos.where((x) => x.grup == g)) {
                satir.add(_Satir(x: x, seviye: 0, bagli: 0, acik: false, onDetay: () => _detay(v, x, 0)));
              }
            }
            govde.add(_bolum('Amiri belirlenmemiş (${bos.length})', satir,
                not: v.kisi.yonetici ? 'Kişiye dokunup Düzenle ile bağlı olduğu amiri seçin.' : null));
          }
        } else {
          final l = v.organizasyon.where((x) => x.grup == _grup).toList();
          govde.add(_bolum('$_grup (${l.length} kişi)', _agacListesi(v, l, ciftlikGoster: false)));
        }

        return Scaffold(
          appBar: AppBar(title: const UygulamaBasligi(baslik: 'Organizasyon Şeması')),
          body: YenilenirListe(
            children: [
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
                    ChoiceChip(
                      label: const Text('Hiyerarşi'),
                      selected: _grup == null,
                      onSelected: (_) => setState(() => _grup = null),
                    ),
                    for (final g in gruplar)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text(g),
                          selected: _grup == g,
                          onSelected: (s) => setState(() => _grup = s ? g : null),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...govde,
            ],
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.x, {this.kucuk = false});
  final OrgKisi x;
  final bool kucuk;

  @override
  Widget build(BuildContext context) {
    final r = _renk(x.kademe);
    final d = kucuk ? 34.0 : 44.0;
    return Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: r.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Text(_bas(x.ad),
          style: TextStyle(color: r, fontWeight: FontWeight.w700, fontSize: kucuk ? 13 : 16)),
    );
  }
}

/// Tek satır: girinti çizgileri, aç/kapa, baş harf, ad ve unvan, bağlı kişi sayısı.
class _Satir extends StatelessWidget {
  const _Satir({
    required this.x,
    required this.seviye,
    required this.bagli,
    required this.acik,
    required this.onDetay,
    this.onAc,
    this.ciftlik = false,
  });
  final OrgKisi x;
  final int seviye, bagli;
  final bool acik, ciftlik;
  final VoidCallback onDetay;
  final VoidCallback? onAc;

  @override
  Widget build(BuildContext context) {
    final alt = ciftlik ? '${x.gorev} · ${x.grup}' : x.gorev;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onDetay,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            for (var i = 0; i < seviye; i++)
              Container(
                width: 16,
                alignment: Alignment.center,
                child: Container(width: 1.5, height: 56, color: Renk.cizgi),
              ),
            SizedBox(
              width: 32,
              child: onAc == null
                  ? null
                  : IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      iconSize: 22,
                      onPressed: onAc,
                      icon: Icon(acik ? Icons.expand_more : Icons.chevron_right, color: Renk.soluk),
                    ),
            ),
            _Avatar(x, kucuk: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(x.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(alt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Renk.soluk, fontSize: 12.5)),
                ],
              ),
            ),
            if (bagli > 0)
              Container(
                margin: const EdgeInsets.only(left: 6, right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Renk.anaAcik, borderRadius: BorderRadius.circular(10)),
                child: Text('$bagli', style: const TextStyle(color: Renk.anaKoyu, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
          ],
        ),
      ),
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

  // Direktörlük ve müdürlükler çiftlik değildir; "Tüm çiftlikler" seçeneği onları karşılar.
  // (Dart'ta 'i' büyük harfe 'I' olur; bu yüzden i/İ içermeyen parçayla aranır.)
  static final _merkezBirim = RegExp('rektörlü|üdürlü', caseSensitive: false);
  List<String> get _ciftlikler => widget.v.ciftlikler.where((c) => !_merkezBirim.hasMatch(c)).toList();

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
