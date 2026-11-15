import 'package:flutter/material.dart';

import '../servis/api.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesen.dart';
import 'is_baslat.dart';

/// Formen: personele nerede, hangi işi, hangi araç ve makine-ekipmanla yapacağını bildirir.
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
    }, basari: _personel.length > 1 ? '${_personel.length} personele iş emri gönderildi.' : 'İş emri gönderildi.');
    if (j != null && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final v = Depo.ben.veri!;
    final kisiler = [...v.ekibim, if (v.kisi.yonetici || v.ekibim.isEmpty) ...v.atanabilir];
    final araclar = v.secimListesi();
    final ekipmanlar = v.secimListesi(ekipman: true);
    final oneriler = v.yerler.where((y) => y.yerTuru == _yerTuru).take(12).toList();
    final isler = islerFor(_yerTuru);
    const ara = SizedBox(height: 16);
    Text etiket(String t) => Text(t, style: const TextStyle(fontWeight: FontWeight.w700));
    return Scaffold(
      appBar: AppBar(title: const Text('İş Emri Ver')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          etiket('Personel'),
          const SizedBox(height: 6),
          if (kisiler.isEmpty)
            const Text('Ekibinizde personel yok. Önce Ekibim sekmesinden personeli ekibinize alın.',
                style: TextStyle(color: Renk.soluk))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final k in kisiler)
                  FilterChip(
                    label: Text(k.ad),
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
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in isler)
                ChoiceChip(label: Text(t), selected: _is == t, onSelected: (s) => setState(() => _is = s ? t : null)),
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
            label: Text(_personel.length > 1 ? '${_personel.length} personele gönder' : 'Gönder',
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
          if (formenGorunumu) Text(e.personel, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(e.aracMetni.isEmpty ? 'Araç gerekmiyor' : 'Araç / makine: ${e.aracMetni}'),
          if (e.aciklama.isNotEmpty) Text(e.aciklama, style: const TextStyle(color: Renk.soluk)),
          if (!formenGorunumu) Text('Veren: ${e.formenAd}', style: const TextStyle(color: Renk.soluk, fontSize: 12)),
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
