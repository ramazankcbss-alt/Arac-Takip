import 'package:flutter/material.dart';

import '../servis/api.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesen.dart';

/// Formenin akşam onay ekranı: günün kullanım kayıtları ve cihaz talepleri.
class OnaySayfasi extends StatefulWidget {
  const OnaySayfasi({super.key});

  @override
  State<OnaySayfasi> createState() => _OnaySayfasiState();
}

class _OnaySayfasiState extends State<OnaySayfasi> {
  final _secili = <String>{};

  @override
  Widget build(BuildContext context) {
    final v = Depo.ben.veri!;
    final tamam = v.onayBekleyen.where((x) => x.durum == 'Tamamlandı').toList();
    final devam = v.onayBekleyen.where((x) => x.durum == 'Devam ediyor').toList();
    _secili.removeWhere((n) => !tamam.any((x) => x.no == n));
    return Stack(
      children: [
        YenilenirListe(
          children: [
            if (v.cihazBekleyen.isNotEmpty)
              Panel(
                baslik: 'Cihaz onayı ve PIN sıfırlama (${v.cihazBekleyen.length})',
                child: Column(
                  children: [
                    for (final c in v.cihazBekleyen)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.ad),
                        subtitle: Text(c.kilitli
                            ? '${c.telefon} · Hatalı PIN denemeleri nedeniyle kilitli'
                            : '${c.telefon} · ${c.ciftlik} · ${c.talep}'),
                        trailing: c.kilitli
                            ? TextButton.icon(
                                icon: const Icon(Icons.lock_reset),
                                label: const Text('PIN Sıfırla'),
                                onPressed: () => islem(context, 'cihazOnay',
                                    {'telefon': c.telefon, 'onay': false, 'sifirla': true},
                                    basari: 'PIN sıfırlandı. Personel yeni PIN ile giriş yaptıktan sonra cihazını onaylayın.'),
                              )
                            : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Reddet',
                              icon: const Icon(Icons.close, color: Renk.kirmizi),
                              onPressed: () => islem(context, 'cihazOnay', {'telefon': c.telefon, 'onay': false},
                                  basari: 'Talep reddedildi.'),
                            ),
                            IconButton(
                              tooltip: 'Onayla',
                              icon: const Icon(Icons.check_circle, color: Renk.yesil),
                              onPressed: () => islem(context, 'cihazOnay', {'telefon': c.telefon, 'onay': true},
                                  basari: '${c.ad} onaylandı.'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            Panel(
              baslik: 'Onay bekleyen kayıtlar (${tamam.length})',
              eylem: tamam.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => setState(() {
                        if (_secili.length == tamam.length) {
                          _secili.clear();
                        } else {
                          _secili
                            ..clear()
                            ..addAll(tamam.map((x) => x.no));
                        }
                      }),
                      child: Text(_secili.length == tamam.length ? 'Seçimi kaldır' : 'Tümünü seç'),
                    ),
              child: tamam.isEmpty
                  ? const Bos('Onay bekleyen kayıt yok.', ikon: Icons.task_alt)
                  : Column(
                      children: [
                        for (final x in tamam)
                          _KayitKarti(
                            x: x,
                            secili: _secili.contains(x.no),
                            onSec: (b) => setState(() => b ? _secili.add(x.no) : _secili.remove(x.no)),
                            onDuzelt: () => _duzelt(x),
                          ),
                      ],
                    ),
            ),
            if (devam.isNotEmpty)
              Panel(
                baslik: 'Devam eden işler (${devam.length})',
                child: Column(
                  children: [
                    for (final x in devam)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${x.arac} · ${x.personel}'),
                        subtitle: Text('Başlangıç ${x.baslangic} · Sayaç ${sayiYaz(x.sayac1)}'),
                        trailing: TextButton(onPressed: () => _duzelt(x), child: const Text('Kapat')),
                      ),
                  ],
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => _duzelt(null),
              icon: const Icon(Icons.post_add),
              label: const Text('Personel yerine kayıt ekle'),
            ),
          ],
        ),
        if (_secili.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
              onPressed: () async {
                final j = await islem(context, 'onayla', {'nolar': _secili.toList()});
                if (j != null && mounted) {
                  bildir(context, '${j['sayi']} kayıt onaylandı.');
                  setState(_secili.clear);
                }
              },
              icon: const Icon(Icons.done_all),
              label: Text('Seçilenleri Onayla (${_secili.length})'),
            ),
          ),
      ],
    );
  }

  Future<void> _duzelt(Kullanim? x) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => KayitDuzeltEkrani(kayit: x)));
  }
}

class _KayitKarti extends StatelessWidget {
  const _KayitKarti({required this.x, required this.secili, required this.onSec, required this.onDuzelt});
  final Kullanim x;
  final bool secili;
  final ValueChanged<bool> onSec;
  final VoidCallback onDuzelt;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: secili ? Renk.ana : Renk.cizgi),
        borderRadius: BorderRadius.circular(10),
      ),
      child: CheckboxListTile(
        value: secili,
        onChanged: (b) => onSec(b ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text('${x.arac} · ${x.personel}', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${x.baslangic} → ${x.bitis.split(' ').last} · ${sayiYaz(x.saat)} saat'
                '${x.is_.isEmpty ? '' : ' · ${x.is_}'}'),
            if (!x.bakimTam)
              Text('Bakım uygunsuzluğu: ${x.eksikKontroller.join(', ')}',
                  style: const TextStyle(color: Renk.kirmizi)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onDuzelt, child: const Text('Düzelt')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formen düzeltmesi ya da personel yerine yeni kayıt.
class KayitDuzeltEkrani extends StatefulWidget {
  const KayitDuzeltEkrani({super.key, this.kayit});
  final Kullanim? kayit;

  @override
  State<KayitDuzeltEkrani> createState() => _KayitDuzeltEkraniState();
}

class _KayitDuzeltEkraniState extends State<KayitDuzeltEkrani> {
  late final _tel = TextEditingController(text: widget.kayit?.telefon ?? '');
  late String? _arac = widget.kayit?.arac;
  late final _s1 = TextEditingController(text: widget.kayit?.sayac1 == null ? '' : sayiYaz(widget.kayit!.sayac1));
  late final _s2 = TextEditingController(text: widget.kayit?.sayac2 == null ? '' : sayiYaz(widget.kayit!.sayac2));
  final _not = TextEditingController();
  late final _k = <String, bool>{
    'gresleme': widget.kayit?.kontrol('gresleme') ?? false,
    'hava': widget.kayit?.kontrol('hava') ?? false,
    'yag': widget.kayit?.kontrol('yag') ?? false,
    'radyator': widget.kayit?.kontrol('radyator') ?? false,
  };

  @override
  void dispose() {
    _tel.dispose();
    _s1.dispose();
    _s2.dispose();
    _not.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    final yeni = widget.kayit == null;
    final t = telefonDuzelt(_tel.text);
    if (yeni && t == null) {
      bildir(context, 'Personelin telefon numarasını yazın.');
      return;
    }
    if (yeni && _arac == null) {
      bildir(context, 'Aracı seçin.');
      return;
    }
    final j = await islem(context, 'kayitDuzelt', {
      'kayit': {
        if (!yeni) 'no': widget.kayit!.no,
        if (t != null && t != widget.kayit?.telefon) 'telefon': t,
        if (_arac != null && _arac != widget.kayit?.arac) 'arac': _arac,
        'sayac1': sayiOku(_s1.text),
        'sayac2': sayiOku(_s2.text),
        if (widget.kayit?.durum == 'Devam ediyor') 'bitis': 'Formen kapattı',
        ..._k,
        'not': _not.text.trim(),
      },
    }, basari: yeni ? 'Kayıt eklendi ve onaylandı.' : 'Kayıt düzeltildi ve onaylandı.');
    if (j != null && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final v = Depo.ben.veri!;
    return Scaffold(
      appBar: AppBar(title: Text(widget.kayit == null ? 'Personel yerine kayıt' : 'Kaydı düzelt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.kayit != null)
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BilgiSatiri('Kayıt', widget.kayit!.no),
                  BilgiSatiri('Personel', widget.kayit!.personel),
                  BilgiSatiri('Başlangıç', widget.kayit!.baslangic),
                  BilgiSatiri('Bitiş', widget.kayit!.bitis),
                ],
              ),
            ),
          TextField(
            controller: _tel,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Personel telefonu',
              helperText: widget.kayit == null ? null : 'Yalnız personel yanlışsa değiştirin',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: v.araclar.any((a) => a.no == _arac) ? _arac : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Araç'),
            items: [
              for (final a in v.secimListesi())
                DropdownMenuItem(value: a.no, child: Text(a.baslik, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (s) => setState(() => _arac = s),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: SayiAlani(kontrol: _s1, etiket: 'Başlangıç sayacı')),
              const SizedBox(width: 12),
              Expanded(child: SayiAlani(kontrol: _s2, etiket: 'Bitiş sayacı')),
            ],
          ),
          const SizedBox(height: 8),
          for (final e in const {
            'gresleme': 'Gresleme',
            'hava': 'Hava filtresi temizliği',
            'yag': 'Motor yağı kontrolü',
            'radyator': 'Radyatör ve petek temizliği',
          }.entries)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _k[e.key],
              onChanged: (b) => setState(() => _k[e.key] = b ?? false),
              title: Text(e.value),
            ),
          TextField(
            controller: _not,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Düzeltme açıklaması'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _kaydet,
            icon: const Icon(Icons.save),
            label: const Text('Kaydet ve onayla'),
          ),
        ],
      ),
    );
  }
}
