import 'package:flutter/material.dart';

import '../servis/api.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesen.dart';
import 'is_baslat.dart';

/// İş emri (makam silsilesi): beyaz yaka formene, formen ekibindeki personele verir.
/// Nerede, hangi iş, hangi araç ve makine-ekipmanla yapılacağı bildirilir.
class IsEmriFormu extends StatefulWidget {
  const IsEmriFormu({super.key, this.personel});
  final String? personel;

  @override
  State<IsEmriFormu> createState() => _IsEmriFormuState();
}

class _IsEmriFormuState extends State<IsEmriFormu> {
  late final Set<String> _personel = {if (widget.personel != null) widget.personel!};
  bool _yarin = false;
  String _yerTuru = 'Tarla';
  final _yer = TextEditingController();
  final _aciklama = TextEditingController();
  String? _is;
  String? _arac;
  final _ekipman = <String>{};

  @override
  void dispose() {
    _yer.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  String _tarih() {
    final d = DateTime.now().add(Duration(days: _yarin ? 1 : 0));
    String iki(int x) => x.toString().padLeft(2, '0');
    return '${iki(d.day)}.${iki(d.month)}.${d.year}';
  }

  Future<void> _gonder() async {
    final j = await islem(context, 'isEmriVer', {
      'emir': {
        'personel': _personel.toList(),
        'tarih': _tarih(),
        'yerTuru': _yerTuru,
        'yer': _yer.text.trim(),
        'is': _is ?? '',
        'arac': _arac ?? '',
        'ekipman': _ekipman.toList(),
        'aciklama': _aciklama.text.trim(),
      },
    }, basari: '${_personel.length} ${_beyaz ? 'formene' : 'personele'} iş emri gönderildi.');
    if (j != null && mounted) Navigator.pop(context);
  }

  bool get _beyaz {
    final k = Depo.ben.veri!.kisi;
    return !k.roller.contains(rolFormen) && (k.yonetici || k.ustYonetim || k.izleyici || k.roller.contains(rolIzleyici));
  }

  @override
  Widget build(BuildContext context) {
    final v = Depo.ben.veri!;
    final beyaz = _beyaz;
    // Beyaz yaka yalnız formenlere, formen yalnız kendi ekibine iş emri verir.
    final kisiler = beyaz
        ? [
            for (final f in v.formenler)
              if (v.kisi.ciftlik == 'Tümü' || v.kisi.yonetici || f.ciftlik == v.kisi.ciftlik)
                EkipUyesi({'telefon': f.telefon, 'ad': f.ad, 'gorev': 'Formen', 'ciftlik': f.ciftlik})
          ]
        : v.ekibim;
    final araclar = v.secimListesi();
    final ekipmanlar = v.secimListesi(ekipman: true);
    final oneriler = v.yerler.where((y) => y.yerTuru == _yerTuru).take(12).toList();
    final (makineli, beden) = islerGrupFor(_yerTuru);
    const ara = SizedBox(height: 16);
    Text etiket(String t) => Text(t, style: const TextStyle(fontWeight: FontWeight.w700));
    return Scaffold(
      appBar: AppBar(title: const Text('İş Emri Ver')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          etiket(beyaz ? 'Formen' : 'Personel'),
          if (beyaz)
            const Text('İş emri formene gider; formen ekibindeki personele dağıtır.',
                style: TextStyle(color: Renk.soluk, fontSize: 12)),
          const SizedBox(height: 6),
          if (kisiler.isEmpty)
            Text(beyaz ? 'Kapsamınızda formen yok.' : 'Ekibinizde personel yok. Önce Ekibim sekmesinden personeli ekibinize alın.',
                style: const TextStyle(color: Renk.soluk))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final k in kisiler)
                  FilterChip(
                    label: Text(beyaz ? '${k.ad} · ${k.ciftlik}' : k.ad),
                    selected: _personel.contains(k.telefon),
                    onSelected: (s) => setState(() => s ? _personel.add(k.telefon) : _personel.remove(k.telefon)),
                  ),
              ],
            ),
          ara,
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Bugün')),
              ButtonSegment(value: true, label: Text('Yarın')),
            ],
            selected: {_yarin},
            onSelectionChanged: (x) => setState(() => _yarin = x.first),
          ),
          ara,
          etiket('Çalışma yeri'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in yerTurleri)
                ChoiceChip(
                  label: Text(t),
                  selected: _yerTuru == t,
                  onSelected: (_) => setState(() {
                    _yerTuru = t;
                    if (_is != null && !islerFor(t).contains(_is)) _is = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _yer,
            decoration: InputDecoration(
              labelText: _yerTuru == 'Tarla'
                  ? 'Tarla / parsel adı'
                  : (_yerTuru == 'Ahır' ? 'Ahır / bölme' : 'Yer'),
              hintText: _yerTuru == 'Tarla' ? 'Örnek: Hotamış 12 nolu parsel' : 'Örnek: 3 nolu ahır, besi bölmesi',
            ),
          ),
          if (oneriler.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final y in oneriler)
                  ActionChip(label: Text(y.yer), onPressed: () => setState(() => _yer.text = y.yer)),
              ],
            ),
          ],
          ara,
          etiket('Yapılacak iş'),
          const SizedBox(height: 6),
          const Text('Makineli işler', style: TextStyle(color: Renk.soluk, fontSize: 12)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in makineli)
                ChoiceChip(label: Text(t), selected: _is == t, onSelected: (s) => setState(() => _is = s ? t : null)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Beden işçiliği', style: TextStyle(color: Renk.soluk, fontSize: 12)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in beden)
                ChoiceChip(
                  avatar: const Icon(Icons.pan_tool_outlined, size: 16),
                  label: Text(t),
                  selected: _is == t,
                  onSelected: (s) => setState(() => _is = s ? t : null),
                ),
            ],
          ),
          ara,
          DropdownButtonFormField<String>(
            initialValue: _arac,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Araç'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Araç gerekmiyor')),
              for (final a in araclar)
                DropdownMenuItem(value: a.no, child: Text('${a.baslik} – ${a.ciftlik}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (s) => setState(() => _arac = s),
          ),
          if (ekipmanlar.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Makine-ekipman', style: TextStyle(color: Renk.soluk)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in ekipmanlar)
                  FilterChip(
                    avatar: Icon(Icons.construction_outlined, size: 18, color: a.arizali ? Renk.kirmizi : null),
                    label: Text(a.tur.isEmpty ? a.no : '${a.no} · ${a.tur}'),
                    selected: _ekipman.contains(a.no),
                    onSelected: (s) => setState(() => s ? _ekipman.add(a.no) : _ekipman.remove(a.no)),
                  ),
              ],
            ),
          ],
          ara,
          TextField(
            controller: _aciklama,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Açıklama / talimat (isteğe bağlı)'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
            onPressed: _personel.isEmpty ? null : _gonder,
            icon: const Icon(Icons.send),
            label: Text(_personel.length > 1 ? '${_personel.length} ${beyaz ? 'formene' : 'personele'} gönder' : 'Gönder',
                style: const TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
  }
}

/// İş emri kartı (personel ve formen görünümü).
class IsEmriKarti extends StatelessWidget {
  const IsEmriKarti({super.key, required this.e, this.formenGorunumu = false});
  final IsEmri e;
  final bool formenGorunumu;

  @override
  Widget build(BuildContext context) {
    final v = Depo.ben.veri!;
    final arac = e.arac.isEmpty ? null : v.arac(e.arac);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Renk.maviAcik,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Renk.mavi.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(e.is_, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              Rozet.durum(e.durum),
            ],
          ),
          const SizedBox(height: 4),
          Text([e.tarih, e.yerTuru, e.yer].where((x) => x.isNotEmpty).join(' · ')),
          if (formenGorunumu)
            Text(e.formeneVerilen ? 'Formen: ${e.personel}' : e.personel,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          if (formenGorunumu && e.formeneVerilen) _ilerleme(v, e),
          Text(e.aracMetni.isEmpty ? 'Araç gerekmiyor' : 'Araç / makine: ${e.aracMetni}'),
          if (e.aciklama.isNotEmpty) Text(e.aciklama, style: const TextStyle(color: Renk.soluk)),
          if (!formenGorunumu) Text('Veren: ${e.verenAd}', style: const TextStyle(color: Renk.soluk, fontSize: 12)),
          if (e.acik) ...[
            const SizedBox(height: 8),
            if (formenGorunumu)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => islem(context, 'isEmriDurum', {'no': e.no, 'durum': 'İptal'},
                      basari: 'İş emri iptal edildi.'),
                  child: const Text('İptal et', style: TextStyle(color: Renk.kirmizi)),
                ),
              )
            else if (e.formeneVerilen && e.durum == 'Verildi')
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(64, 52)),
                      onPressed: () =>
                          Navigator.push(context, MaterialPageRoute(builder: (_) => IsEmriDagitEkrani(e: e))),
                      icon: const Icon(Icons.call_split),
                      label: const Text('Personele dağıt'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => islem(context, 'isEmriDurum', {'no': e.no, 'durum': 'Tamamlandı'},
                        basari: 'Tamamlandı olarak bildirildi.'),
                    child: const Text('Tamamlandı'),
                  ),
                ],
              )
            else if (e.durum == 'Verildi' && arac != null && v.acikIs == null)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 52)),
                onPressed: () => isBaslatFormuAc(context, arac,
                    ekipman: e.ekipman, isTuru: e.is_, emirNo: e.no),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('İşe Başla'),
              )
            else if (arac == null)
              FilledButton.tonalIcon(
                onPressed: () => islem(context, 'isEmriDurum', {'no': e.no, 'durum': 'Tamamlandı'},
                    basari: 'Tamamlandı olarak bildirildi.'),
                icon: const Icon(Icons.check),
                label: const Text('Tamamlandı'),
              ),
          ],
        ],
      ),
    );
  }
}

Widget _ilerleme(Veri v, IsEmri e) {
  final alt = v.verdigimEmirler.where((x) => x.ust == e.no).toList();
  if (alt.isEmpty) {
    return Text(e.durum == 'Verildi' ? 'Formen henüz dağıtmadı' : '',
        style: const TextStyle(color: Renk.soluk, fontSize: 12));
  }
  final biten = alt.where((x) => x.durum == 'Tamamlandı').length;
  return Text('Dağıtıldı: ${alt.length} personel · $biten tamamlandı (${alt.map((x) => x.personel).join(', ')})',
      style: const TextStyle(color: Renk.soluk, fontSize: 12));
}

/// Formen: kendisine verilen iş emrini ekibine dağıtır; yer, iş ve talimat aynen aktarılır.
class IsEmriDagitEkrani extends StatefulWidget {
  const IsEmriDagitEkrani({super.key, required this.e});
  final IsEmri e;

  @override
  State<IsEmriDagitEkrani> createState() => _IsEmriDagitEkraniState();
}

class _IsEmriDagitEkraniState extends State<IsEmriDagitEkrani> {
  final _personel = <String>{};
  late String? _arac = widget.e.arac.isEmpty ? null : widget.e.arac;
  late final _ekipman = <String>{...widget.e.ekipman};
  final _ek = TextEditingController();

  @override
  void dispose() {
    _ek.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    final j = await islem(context, 'isEmriDagit', {
      'no': widget.e.no,
      'personel': _personel.toList(),
      'arac': _arac ?? '',
      'ekipman': _ekipman.toList(),
      'aciklama': _ek.text.trim(),
    }, basari: 'İş emri ${_personel.length} personele dağıtıldı.');
    if (j != null && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final v = Depo.ben.veri!;
    final e = widget.e;
    final ekipmanlar = v.secimListesi(ekipman: true);
    return Scaffold(
      appBar: AppBar(title: const Text('Personele dağıt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(e.is_, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text([e.tarih, e.yerTuru, e.yer].where((x) => x.isNotEmpty).join(' · ')),
                if (e.aciklama.isNotEmpty) Text(e.aciklama, style: const TextStyle(color: Renk.soluk)),
                Text('Veren: ${e.verenAd}', style: const TextStyle(color: Renk.soluk, fontSize: 12)),
              ],
            ),
          ),
          const Text('Personel', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (v.ekibim.isEmpty)
            const Text('Ekibinizde personel yok.', style: TextStyle(color: Renk.soluk))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final k in v.ekibim)
                  FilterChip(
                    label: Text(k.ad),
                    selected: _personel.contains(k.telefon),
                    onSelected: (s) => setState(() => s ? _personel.add(k.telefon) : _personel.remove(k.telefon)),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: v.araclar.any((a) => a.no == _arac) ? _arac : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Araç'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Araç gerekmiyor')),
              for (final a in v.secimListesi())
                DropdownMenuItem(value: a.no, child: Text('${a.baslik} – ${a.ciftlik}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (s) => setState(() => _arac = s),
          ),
          if (ekipmanlar.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in ekipmanlar)
                  FilterChip(
                    avatar: const Icon(Icons.construction_outlined, size: 18),
                    label: Text(a.tur.isEmpty ? a.no : '${a.no} · ${a.tur}'),
                    selected: _ekipman.contains(a.no),
                    onSelected: (s) => setState(() => s ? _ekipman.add(a.no) : _ekipman.remove(a.no)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _ek,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Ek talimat (isteğe bağlı)'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
            onPressed: _personel.isEmpty ? null : _gonder,
            icon: const Icon(Icons.send),
            label: Text(_personel.isEmpty ? 'Personel seçin' : '${_personel.length} personele dağıt'),
          ),
        ],
      ),
    );
  }
}
