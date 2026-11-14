import 'package:flutter/material.dart';

import '../servis/api.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesen.dart';

/// Araç listesi, periyodik bakım uyarıları, aktif kullanım.
class AraclarSayfasi extends StatefulWidget {
  const AraclarSayfasi({super.key});

  @override
  State<AraclarSayfasi> createState() => _AraclarSayfasiState();
}

class _AraclarSayfasiState extends State<AraclarSayfasi> {
  String _ara = '';

  @override
  Widget build(BuildContext context) {
    final v = Depo.ben.veri!;
    final sorumlu = v.kisi.sorumlu;
    final q = _ara.toLowerCase();
    final liste = v.araclar
        .where((a) => q.isEmpty || '${a.no} ${a.tur} ${a.model} ${a.plaka} ${a.ciftlik}'.toLowerCase().contains(q))
        .toList()
      ..sort((x, y) => x.no.compareTo(y.no));
    return Scaffold(
      floatingActionButton: sorumlu
          ? FloatingActionButton.extended(
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AracFormu())),
              icon: const Icon(Icons.add),
              label: const Text('Araç Ekle'),
            )
          : null,
      body: YenilenirListe(
        children: [
          if (v.bakimUyari.isNotEmpty)
            Panel(
              baslik: 'Periyodik bakım uyarıları',
              child: Column(
                children: [
                  for (final b in v.bakimUyari)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${b.arac} · ${b.bakim}'),
                      subtitle: Text(b.gecikti
                          ? '${-b.kalan} saat gecikti (sayaç ${sayiYaz(b.sayac)})'
                          : '${b.kalan} saat kaldı (sayaç ${sayiYaz(b.sayac)})'),
                      trailing: Rozet.durum(b.gecikti ? 'Gecikti' : 'Yaklaşıyor'),
                      onTap: sorumlu
                          ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => BakimFormu(arac: b.arac, bakim: b.bakim, sayac: b.sayac)))
                          : null,
                    ),
                ],
              ),
            ),
          if (v.aktif.isNotEmpty)
            Panel(
              baslik: 'Aktif kullanım',
              child: Column(
                children: [
                  for (final x in v.aktif)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.play_circle, color: Renk.mavi),
                      title: Text('${x.arac} · ${x.personel}'),
                      subtitle: Text('${x.baslangic}${x.is_.isEmpty ? '' : ' · ${x.is_}'}'),
                    ),
                ],
              ),
            ),
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Araç ara'),
            onChanged: (s) => setState(() => _ara = s),
          ),
          const SizedBox(height: 8),
          if (liste.isEmpty)
            const Bos('Henüz araç kaydı yok. "Araç Ekle" ile başlayın.')
          else
            for (final a in liste)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Renk.cizgi)),
                child: ListTile(
                  title: Text(a.baslik, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${a.alt}\nMotor saati: ${sayiYaz(a.sayac)}'),
                  isThreeLine: true,
                  trailing: Rozet.durum(a.durum),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AracDetay(no: a.no))),
                ),
              ),
        ],
      ),
    );
  }
}

/// Araç kartı: bilgiler, bakım planı, bakım/onarım geçmişi, arızalar.
class AracDetay extends StatelessWidget {
  const AracDetay({super.key, required this.no});
  final String no;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Depo.ben,
      builder: (context, _) {
        final v = Depo.ben.veri!;
        final a = v.arac(no);
        if (a == null) return const Scaffold(body: Bos('Araç bulunamadı.'));
        final sorumlu = v.kisi.sorumlu;
        final plan = v.plan.where((p) => p.arac == no).toList();
        final kayit = v.bakimKayit.where((b) => b.arac == no).toList();
        final ariza = v.arizalar.where((x) => x.arac == no).toList();
        return Scaffold(
          appBar: AppBar(
            title: Text(a.no),
            actions: [
              if (sorumlu)
                IconButton(
                  tooltip: 'Düzenle',
                  onPressed: () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AracFormu(arac: a))),
                  icon: const Icon(Icons.edit),
                ),
            ],
          ),
          floatingActionButton: sorumlu
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => BakimFormu(arac: a.no, sayac: a.sayac))),
                  icon: const Icon(Icons.build),
                  label: const Text('Bakım / Onarım Kaydı'),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              Panel(
                eylem: Rozet.durum(a.durum),
                baslik: a.tur,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BilgiSatiri('Marka / Model', a.model),
                    BilgiSatiri('Plaka / Şase No', a.plaka),
                    BilgiSatiri('Model yılı', a.yil),
                    BilgiSatiri('Çiftlik', a.ciftlik),
                    BilgiSatiri('Motor saati', sayiYaz(a.sayac)),
                    if (a.not.isNotEmpty) BilgiSatiri('Not', a.not),
                  ],
                ),
              ),
              if (sorumlu)
                Panel(
                  baslik: 'Periyodik bakım planı',
                  eylem: TextButton(
                    onPressed: () => _planDuzenle(context, a.no, null),
                    child: const Text('Ekle'),
                  ),
                  child: plan.isEmpty
                      ? const Text('Plan yok.', style: TextStyle(color: Renk.soluk))
                      : Column(
                          children: [
                            for (final p in plan)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(p.bakim),
                                subtitle: Text('Her ${sayiYaz(p.periyot)} saatte · son: '
                                    '${sayiYaz(p.son)} saat${p.sonTarih.isEmpty ? '' : ' (${p.sonTarih})'}'),
                                trailing: const Icon(Icons.edit_outlined, size: 20),
                                onTap: () => _planDuzenle(context, a.no, p),
                              ),
                          ],
                        ),
                ),
              Panel(
                baslik: 'Arızalar',
                child: ariza.isEmpty
                    ? const Text('Kayıtlı arıza yok.', style: TextStyle(color: Renk.soluk))
                    : Column(
                        children: [
                          for (final x in ariza)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(x.aciklama, maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${x.zaman} · ${x.bildiren}'),
                              trailing: Rozet.durum(x.durum),
                            ),
                        ],
                      ),
              ),
              if (sorumlu)
                Panel(
                  baslik: 'Bakım ve onarım geçmişi',
                  child: kayit.isEmpty
                      ? const Text('Kayıt yok. Geçmiş bakımları "Bakım / Onarım Kaydı" ile girebilirsiniz.',
                          style: TextStyle(color: Renk.soluk))
                      : Column(
                          children: [
                            for (final b in kayit)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text([b.kayitTuru, b.bakim].where((x) => x.isNotEmpty).join(' · ')),
                                subtitle: Text([
                                  b.tarih,
                                  if (b.sayac != null) '${sayiYaz(b.sayac)} saat',
                                  if (b.is_.isNotEmpty) b.is_,
                                  if (b.parca.isNotEmpty) 'Parça: ${b.parca}',
                                  if (b.firma.isNotEmpty) b.firma,
                                  if (b.tutar.isNotEmpty) '${b.tutar} TL',
                                  if (b.belge.isNotEmpty) 'Belge: ${b.belge}',
                                ].join(' · ')),
                              ),
                          ],
                        ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _planDuzenle(BuildContext context, String arac, Plan? p) async {
    final ad = TextEditingController(text: p?.bakim ?? '');
    final per = TextEditingController(text: p?.periyot == null ? '' : sayiYaz(p!.periyot));
    final son = TextEditingController(text: p?.son == null ? '' : sayiYaz(p!.son));
    final sonuc = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p == null ? 'Bakım türü ekle' : 'Bakım planı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: ad, enabled: p == null, decoration: const InputDecoration(labelText: 'Bakım türü')),
            const SizedBox(height: 8),
            SayiAlani(kontrol: per, etiket: 'Periyot (motor saati)'),
            const SizedBox(height: 8),
            SayiAlani(kontrol: son, etiket: 'Son yapıldığı motor saati'),
          ],
        ),
        actions: [
          if (p != null)
            TextButton(onPressed: () => Navigator.pop(ctx, 'sil'), child: const Text('Sil', style: TextStyle(color: Renk.kirmizi))),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'kaydet'), child: const Text('Kaydet')),
        ],
      ),
    );
    if (sonuc == null || !context.mounted) return;
    await islem(context, 'planKaydet', {
      'plan': {
        'arac': arac,
        'bakim': ad.text.trim(),
        'periyot': sayiOku(per.text),
        'son': sayiOku(son.text),
        'sil': sonuc == 'sil',
      },
    }, basari: 'Bakım planı güncellendi.');
  }
}

/// Araç ekleme / düzenleme (Makine-Ekipman Sorumlusu).
class AracFormu extends StatefulWidget {
  const AracFormu({super.key, this.arac});
  final Arac? arac;

  @override
  State<AracFormu> createState() => _AracFormuState();
}

class _AracFormuState extends State<AracFormu> {
  late final _no = TextEditingController(text: widget.arac?.no ?? '');
  late final _model = TextEditingController(text: widget.arac?.model ?? '');
  late final _plaka = TextEditingController(text: widget.arac?.plaka ?? '');
  late final _yil = TextEditingController(text: widget.arac?.yil ?? '');
  late final _sayac = TextEditingController(text: widget.arac?.sayac == null ? '' : sayiYaz(widget.arac!.sayac));
  late final _not = TextEditingController(text: widget.arac?.not ?? '');
  late String? _tur = widget.arac?.tur;
  late String? _ciftlik = widget.arac?.ciftlik;
  late String _durum = widget.arac?.durum ?? 'Aktif';

  @override
  void dispose() {
    for (final c in [_no, _model, _plaka, _yil, _sayac, _not]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _kaydet() async {
    final j = await islem(context, 'aracKaydet', {
      'arac': {
        'yeni': widget.arac == null,
        'no': _no.text.trim(),
        'tur': _tur ?? '',
        'model': _model.text.trim(),
        'plaka': _plaka.text.trim(),
        'ciftlik': _ciftlik ?? '',
        'sayac': sayiOku(_sayac.text),
        'durum': _durum,
        'yil': _yil.text.trim(),
        'not': _not.text.trim(),
      },
    }, basari: widget.arac == null ? 'Araç eklendi. Varsayılan bakım planı oluşturuldu.' : 'Araç güncellendi.');
    if (j != null && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final v = Depo.ben.veri!;
    final ciftlikler = {...v.ciftlikler, if (_ciftlik != null && _ciftlik!.isNotEmpty) _ciftlik!}.toList()..sort();
    final turler = {...aracTurleri, if (_tur != null && _tur!.isNotEmpty) _tur!}.toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.arac == null ? 'Araç Ekle' : 'Araç Düzenle')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _no,
            enabled: widget.arac == null,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Araç no (kısa ad)',
              helperText: 'Örnek: TRK-07, KMY-34, MNT-02. Sonradan değiştirilemez.',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _tur,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tür'),
            items: [for (final t in turler) DropdownMenuItem(value: t, child: Text(t))],
            onChanged: (s) => setState(() => _tur = s),
          ),
          const SizedBox(height: 12),
          TextField(controller: _model, decoration: const InputDecoration(labelText: 'Marka / Model')),
          const SizedBox(height: 12),
          TextField(
            controller: _plaka,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Plaka / Şase No'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _yil,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Model yılı'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: (_ciftlik?.isEmpty ?? true) ? null : _ciftlik,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Çiftlik / Birim'),
            items: [for (final c in ciftlikler) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (s) => setState(() => _ciftlik = s),
          ),
          const SizedBox(height: 12),
          SayiAlani(kontrol: _sayac, etiket: 'Güncel motor saati'),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Aktif', label: Text('Aktif')),
              ButtonSegment(value: 'Arızalı', label: Text('Arızalı')),
              ButtonSegment(value: 'Pasif', label: Text('Pasif')),
            ],
            selected: {_durum},
            onSelectionChanged: (s) => setState(() => _durum = s.first),
          ),
          const SizedBox(height: 12),
          TextField(controller: _not, maxLines: 2, decoration: const InputDecoration(labelText: 'Not')),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: _kaydet, icon: const Icon(Icons.save), label: const Text('Kaydet')),
        ],
      ),
    );
  }
}

/// Bakım / onarım kaydı (geçmiş kayıtlar dahil).
class BakimFormu extends StatefulWidget {
  const BakimFormu({super.key, required this.arac, this.bakim, this.sayac, this.arizaNo});
  final String arac;
  final String? bakim;
  final double? sayac;
  final String? arizaNo;

  @override
  State<BakimFormu> createState() => _BakimFormuState();
}

class _BakimFormuState extends State<BakimFormu> {
  late String _tur = widget.arizaNo != null
      ? 'Onarım'
      : (widget.bakim != null ? 'Periyodik bakım' : bakimKayitTurleri.first);
  late String? _bakim = widget.bakim;
  final _tarih = TextEditingController();
  late final _sayac = TextEditingController(text: widget.sayac == null ? '' : sayiYaz(widget.sayac));
  final _is = TextEditingController();
  final _parca = TextEditingController();
  final _firma = TextEditingController();
  final _tutar = TextEditingController();
  final _belge = TextEditingController();

  @override
  void dispose() {
    for (final c in [_tarih, _sayac, _is, _parca, _firma, _tutar, _belge]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _tarihSec() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      initialDate: DateTime.now(),
    );
    if (d != null) {
      _tarih.text = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    }
  }

  Future<void> _kaydet() async {
    final j = await islem(context, 'bakimKaydet', {
      'kayit': {
        'arac': widget.arac,
        'kayitTuru': _tur,
        'bakim': _tur == 'Periyodik bakım' ? (_bakim ?? '') : '',
        'tarih': _tarih.text.trim(),
        'sayac': sayiOku(_sayac.text),
        'is': _is.text.trim(),
        'parca': _parca.text.trim(),
        'firma': _firma.text.trim(),
        'tutar': _tutar.text.trim(),
        'belge': _belge.text.trim(),
        if (widget.arizaNo != null) 'arizaNo': widget.arizaNo,
      },
    }, basari: 'Kayıt eklendi.');
    if (j != null && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final plan = Depo.ben.veri!.plan.where((p) => p.arac == widget.arac).map((p) => p.bakim).toList();
    return Scaffold(
      appBar: AppBar(title: Text('${widget.arac} · Bakım / Onarım')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _tur,
            decoration: const InputDecoration(labelText: 'Kayıt türü'),
            items: [for (final t in bakimKayitTurleri) DropdownMenuItem(value: t, child: Text(t))],
            onChanged: (s) => setState(() => _tur = s ?? _tur),
          ),
          if (_tur == 'Periyodik bakım') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: plan.contains(_bakim) ? _bakim : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Bakım türü (plandaki)'),
              items: [for (final p in plan) DropdownMenuItem(value: p, child: Text(p))],
              onChanged: (s) => setState(() => _bakim = s),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _tarih,
            readOnly: true,
            onTap: _tarihSec,
            decoration: const InputDecoration(
              labelText: 'Tarih',
              helperText: 'Boş bırakılırsa bugün. Geçmiş kayıtlar için tarihi seçin.',
              suffixIcon: Icon(Icons.calendar_month),
            ),
          ),
          const SizedBox(height: 12),
          SayiAlani(kontrol: _sayac, etiket: 'Motor saati'),
          const SizedBox(height: 12),
          TextField(controller: _is, maxLines: 2, decoration: const InputDecoration(labelText: 'Yapılan iş')),
          const SizedBox(height: 12),
          TextField(controller: _parca, decoration: const InputDecoration(labelText: 'Değişen parça')),
          const SizedBox(height: 12),
          TextField(controller: _firma, decoration: const InputDecoration(labelText: 'Firma / Atölye')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tutar,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Tutar (TL)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(controller: _belge, decoration: const InputDecoration(labelText: 'Fatura / SAT no')),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: _kaydet, icon: const Icon(Icons.save), label: const Text('Kaydet')),
        ],
      ),
    );
  }
}
