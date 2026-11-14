import 'package:flutter/material.dart';

import '../servis/api.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesen.dart';

/// İş bitişi: motor saati ve Günlük Bakım Kontrolü.
class IsBitirEkrani extends StatefulWidget {
  const IsBitirEkrani({super.key, required this.is_});
  final Kullanim is_;

  @override
  State<IsBitirEkrani> createState() => _IsBitirEkraniState();
}

class _IsBitirEkraniState extends State<IsBitirEkrani> {
  final _sayac = TextEditingController();
  final _not = TextEditingController();
  final _k = <String, bool>{'gresleme': false, 'hava': false, 'yag': false, 'radyator': false};

  static const _etiket = {
    'gresleme': ('Gresleme yapıldı', 'Gres noktaları yağlandı'),
    'hava': ('Hava filtresi temizlendi', 'Basınçlı hava ile'),
    'yag': ('Motor yağı seviyesi kontrol edildi', 'Eksikse tamamlandı'),
    'radyator': ('Radyatör ve petek temizlendi', 'Toz, saman, sap temizliği'),
  };

  @override
  void dispose() {
    _sayac.dispose();
    _not.dispose();
    super.dispose();
  }

  Future<void> _bitir() async {
    final s = sayiOku(_sayac.text);
    if (s == null) {
      bildir(context, 'İş bitişindeki motor saatini yazın.');
      return;
    }
    final s1 = widget.is_.sayac1;
    if (s1 != null && s < s1) {
      bildir(context, 'Bitiş sayacı başlangıçtan (${sayiYaz(s1)}) küçük olamaz.');
      return;
    }
    final eksik = _k.values.any((x) => !x);
    if (eksik) {
      final devam = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bakım kontrolü eksik'),
          content: const Text(
              'İşaretlenmeyen kontroller "Bakım Uygunsuzluğu" olarak kaydedilecek. Devam edilsin mi?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Geri dön')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
          ],
        ),
      );
      if (devam != true || !mounted) return;
    }
    final j = await islem(context, 'isBitir', {
      'no': widget.is_.no,
      'sayac': s,
      ..._k,
      'not': _not.text.trim(),
    }, basari: 'İş tamamlandı.');
    if (j != null && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İşi Bitir')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.is_.arac, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                BilgiSatiri('Başlangıç', widget.is_.baslangic),
                BilgiSatiri('Başlangıç sayacı', sayiYaz(widget.is_.sayac1)),
                const SizedBox(height: 12),
                SayiAlani(kontrol: _sayac, etiket: 'Bitiş motor saati'),
              ],
            ),
          ),
          Panel(
            baslik: 'Günlük Bakım Kontrolü',
            child: Column(
              children: [
                for (final e in _etiket.entries)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _k[e.key],
                    onChanged: (b) => setState(() => _k[e.key] = b ?? false),
                    title: Text(e.value.$1),
                    subtitle: Text(e.value.$2),
                  ),
              ],
            ),
          ),
          TextField(
            controller: _not,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
            onPressed: _bitir,
            icon: const Icon(Icons.check),
            label: const Text('Kaydet ve bitir', style: TextStyle(fontSize: 17)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Arıza varsa ana sayfadaki "Arıza Bildirimi" düğmesini kullanın.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Renk.soluk),
          ),
        ],
      ),
    );
  }
}
