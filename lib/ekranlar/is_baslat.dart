import 'package:flutter/material.dart';

import '../servis/api.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesen.dart';

/// Araç seçimi: sık kullanılan araçlar başta. Seçince sayaç ve iş türü sorulur.
class IsBaslatEkrani extends StatefulWidget {
  const IsBaslatEkrani({super.key});

  @override
  State<IsBaslatEkrani> createState() => _IsBaslatEkraniState();
}

class _IsBaslatEkraniState extends State<IsBaslatEkrani> {
  String _ara = '';

  @override
  Widget build(BuildContext context) {
    final v = Depo.ben.veri!;
    final q = _ara.toLowerCase();
    final liste = v
        .secimListesi()
        .where((a) => q.isEmpty || '${a.no} ${a.tur} ${a.model} ${a.plaka}'.toLowerCase().contains(q))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Araç seçin')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Araç no, tür, plaka'),
              onChanged: (s) => setState(() => _ara = s),
            ),
          ),
          Expanded(
            child: liste.isEmpty
                ? const Bos('Kayıtlı araç bulunamadı. Araçları Makine-Ekipman Sorumlusu ekler.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: liste.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final a = liste[i];
                      return Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Renk.cizgi)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: Icon(Icons.agriculture,
                              color: a.arizali ? Renk.kirmizi : Renk.ana, size: 32),
                          title: Text(a.baslik, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(a.alt),
                          trailing: a.arizali
                              ? Rozet.durum('Arızalı')
                              : (a.kullanim > 0 ? const Icon(Icons.star_rounded, color: Renk.amber) : null),
                          onTap: () => _sec(a),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _sec(Arac a) async {
    final sonuc = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BaslatFormu(arac: a),
    );
    if (sonuc == true && mounted) Navigator.pop(context);
  }
}

/// İş başlatma formunu açar (iş emrinden gelindiğinde ekipman ve iş hazır seçili).
Future<void> isBaslatFormuAc(BuildContext context, Arac arac,
    {List<String> ekipman = const [], String? isTuru, String? emirNo}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BaslatFormu(arac: arac, ekipman: ekipman, isTuru: isTuru, emirNo: emirNo),
  );
}

class _BaslatFormu extends StatefulWidget {
  const _BaslatFormu({required this.arac, this.ekipman = const [], this.isTuru, this.emirNo});
  final Arac arac;
  final List<String> ekipman;
  final String? isTuru;
  final String? emirNo;

  @override
  State<_BaslatFormu> createState() => _BaslatFormuState();
}

class _BaslatFormuState extends State<_BaslatFormu> {
  late final _sayac = TextEditingController(text: widget.arac.sayac == null ? '' : sayiYaz(widget.arac.sayac));
  late String? _is = widget.isTuru;
  late final _ekipman = <String>{...widget.ekipman};
  bool _tumEkipman = false;

  @override
  void dispose() {
    _sayac.dispose();
    super.dispose();
  }

  Future<void> _baslat({bool arizaliOnay = false}) async {
    final s = sayiOku(_sayac.text);
    if (_sayac.text.trim().isNotEmpty && s == null) {
      bildir(context, 'Motor saatini sayı olarak yazın.');
      return;
    }
    try {
      final j = await Depo.ben.gonder('isBaslat', {
        'arac': widget.arac.no,
        'sayac': s,
        'is': _is ?? '',
        'ekipman': _ekipman.toList(),
        if (widget.emirNo != null) 'emirNo': widget.emirNo,
        'arizaliOnay': arizaliOnay,
      });
      await Depo.ben.yenile();
      if (!mounted) return;
      final uyari = j['uyari']?.toString() ?? '';
      bildir(context, uyari.isNotEmpty ? 'İş başlatıldı. $uyari' : 'İş başlatıldı.');
      Navigator.pop(context, true);
    } on ApiHatasi catch (e) {
      if (!mounted) return;
      if (e.arizali) {
        final devam = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded, color: Renk.kirmizi),
            title: const Text('Arızalı kayıt'),
            content: Text('${e.mesaj}\n\nFormeninizin talimatıyla yine de başlatmak istiyor musunuz?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Talimatla başlat')),
            ],
          ),
        );
        if (devam == true) await _baslat(arizaliOnay: true);
      } else {
        bildir(context, e.mesaj);
      }
    }
  }

  /// Araca bağlanan makine-ekipman: sık kullanılanlar ve aynı çiftliktekiler önde.
  List<Widget> _ekipmanSecimi() {
    final v = Depo.ben.veri!;
    final tum = v.secimListesi(ekipman: true);
    if (tum.isEmpty) return const [];
    final gosterilen = _tumEkipman ? tum : tum.take(8).toList();
    for (final n in _ekipman) {
      if (!gosterilen.any((a) => a.no == n)) gosterilen.add(tum.firstWhere((a) => a.no == n));
    }
    return [
      const Text('Bağlı makine-ekipman (varsa seçin)', style: TextStyle(color: Renk.soluk)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final a in gosterilen)
            FilterChip(
              avatar: Icon(Icons.construction_outlined, size: 18, color: a.arizali ? Renk.kirmizi : null),
              label: Text(a.tur.isEmpty ? a.no : '${a.no} · ${a.tur}'),
              selected: _ekipman.contains(a.no),
              onSelected: (s) => setState(() => s ? _ekipman.add(a.no) : _ekipman.remove(a.no)),
            ),
          if (!_tumEkipman && tum.length > 8)
            ActionChip(
              label: Text('Tümü (${tum.length})'),
              onPressed: () => setState(() => _tumEkipman = true),
            ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
       child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.arac.baslik, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(widget.arac.alt, style: const TextStyle(color: Renk.soluk)),
          const SizedBox(height: 16),
          SayiAlani(kontrol: _sayac, etiket: 'Motor saati (sayaç)', ipucu: 'Göstergedeki değeri yazın'),
          const SizedBox(height: 12),
          ..._ekipmanSecimi(),
          const SizedBox(height: 12),
          const Text('Yapılacak iş (isteğe bağlı)', style: TextStyle(color: Renk.soluk)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in {...isTurleri, if (_is != null) _is!})
                ChoiceChip(
                  label: Text(t),
                  selected: _is == t,
                  onSelected: (s) => setState(() => _is = s ? t : null),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
            onPressed: _baslat,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('İşi Başlat', style: TextStyle(fontSize: 17)),
          ),
        ],
       ),
      ),
    );
  }
}
