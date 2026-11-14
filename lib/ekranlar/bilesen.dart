import 'package:flutter/material.dart';

import '../servis/api.dart';
import '../tema.dart';

/// Sunucu işlemini çalıştırır: bekleme göstergesi, hata/başarı mesajı ve
/// başarılıysa verilerin yenilenmesi. Başarılıysa cevabı döndürür.
Future<Map<String, dynamic>?> islem(
  BuildContext context,
  String tur,
  Map<String, dynamic> alan, {
  String? basari,
  bool yenile = true,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
  try {
    final j = await Depo.ben.gonder(tur, alan);
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (basari != null && context.mounted) bildir(context, basari);
    if (yenile) await Depo.ben.yenile();
    return j;
  } on ApiHatasi catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('İşlem tamamlanamadı'),
          content: Text(e.mesaj),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
        ),
      );
    }
    return null;
  }
}

/// Renkli küçük durum etiketi.
class Rozet extends StatelessWidget {
  const Rozet(this.metin, {super.key, this.renk = Renk.soluk, this.zemin = Renk.cizgi});

  factory Rozet.durum(String d) {
    switch (d) {
      case 'Aktif':
      case 'Onaylandı':
      case 'Onarıldı':
      case 'Onaylı':
        return Rozet(d, renk: Renk.yesil, zemin: Renk.yesilAcik);
      case 'Devam ediyor':
      case 'Atölyede':
        return Rozet(d, renk: Renk.mavi, zemin: Renk.maviAcik);
      case 'Tamamlandı':
      case 'Parça bekleniyor':
      case 'Yaklaşıyor':
      case 'Bekliyor':
        return Rozet(d, renk: Renk.amber, zemin: Renk.amberAcik);
      case 'Arızalı':
      case 'Bildirildi':
      case 'Gecikti':
        return Rozet(d, renk: Renk.kirmizi, zemin: Renk.kirmiziAcik);
      default:
        return Rozet(d);
    }
  }

  final String metin;
  final Color renk, zemin;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: zemin, borderRadius: BorderRadius.circular(6)),
        child: Text(metin, style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

/// Boş liste mesajı.
class Bos extends StatelessWidget {
  const Bos(this.metin, {super.key, this.ikon = Icons.inbox_outlined});
  final String metin;
  final IconData ikon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            Icon(ikon, size: 40, color: Renk.soluk),
            const SizedBox(height: 8),
            Text(metin, textAlign: TextAlign.center, style: const TextStyle(color: Renk.soluk)),
          ],
        ),
      );
}

/// Yenilenebilir liste sayfası iskeleti.
class YenilenirListe extends StatelessWidget {
  const YenilenirListe({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: Depo.ben.yenile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: children,
        ),
      );
}

/// Sayısal giriş alanı (motor saati gibi).
class SayiAlani extends StatelessWidget {
  const SayiAlani({super.key, required this.kontrol, required this.etiket, this.ipucu});
  final TextEditingController kontrol;
  final String etiket;
  final String? ipucu;

  @override
  Widget build(BuildContext context) => TextField(
        controller: kontrol,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: etiket, helperText: ipucu),
      );
}

/// Kısa bilgi satırı: solda etiket, sağda değer.
class BilgiSatiri extends StatelessWidget {
  const BilgiSatiri(this.etiket, this.deger, {super.key});
  final String etiket, deger;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 130, child: Text(etiket, style: const TextStyle(color: Renk.soluk))),
            Expanded(child: Text(deger.isEmpty ? '–' : deger)),
          ],
        ),
      );
}
