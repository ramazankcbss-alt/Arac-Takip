import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../servis/api.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'araclar.dart';
import 'bilesen.dart';

/// Talebi kurumsal bir metin olarak paylaşır (Google Chat satınalma grubu, WhatsApp, e-posta).
/// Kayıt uygulamada tutulur; paylaşım bilgilendirme içindir.
String talepMetni(Talep t) {
  final a = t.arac.isEmpty ? null : Depo.ben.veri?.arac(t.arac);
  return [
    'MALZEME / PARÇA TALEBİ – ${t.no}',
    if (a != null)
      'Araç: ${a.no} · ${[a.tur, a.model].where((x) => x.isNotEmpty).join(' ')}'
          '${a.plaka.isEmpty ? '' : ' · ${a.plaka}'}',
    'Talep türü: ${t.tur}',
    if (t.malzeme.isNotEmpty) 'Parça / malzeme: ${t.malzeme}${t.miktar.isEmpty ? '' : ' (${t.miktar})'}',
    if (t.aciklama.isNotEmpty) 'Açıklama: ${t.aciklama}',
    'Çiftlik: ${t.ciftlik}',
    'Talep eden: ${t.talepEden} · ${t.tarih}',
    'Durum: ${t.durum}',
    for (var i = 0; i < t.fotolar.length; i++) 'Fotoğraf ${i + 1}: ${t.fotolar[i]}',
    'Bilgilerinize sunarım. (Araç Takip kaydı)',
  ].join('\n');
}

Future<void> talepPaylas(Talep t) => Share.share(talepMetni(t), subject: 'Malzeme / parça talebi ${t.no}');

/// Kırılan / değişecek parça, alınacak malzeme ve bakım ihtiyacı talebi.
/// Formen ve personel açar; bakım-onarım ekibine anlık bildirim gider.
class TalepFormu extends StatefulWidget {
  const TalepFormu({super.key, this.arac});
  final String? arac;

  @override
  State<TalepFormu> createState() => _TalepFormuState();
}

class _TalepFormuState extends State<TalepFormu> {
  late String? _arac = widget.arac;
  String _tur = talepTurleri.first;
  final _malzeme = TextEditingController();
  final _miktar = TextEditingController();
  final _aciklama = TextEditingController();
  final _fotolar = <Uint8List>[];

  @override
  void dispose() {
    _malzeme.dispose();
    _miktar.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    final j = await islem(context, 'talepAc', {
      'talep': {
        'arac': _arac ?? '',
        'tur': _tur,
        'malzeme': _malzeme.text.trim(),
        'miktar': _miktar.text.trim(),
        'aciklama': _aciklama.text.trim(),
        if (_fotolar.isNotEmpty) 'fotolar': _fotolar.map(base64Encode).toList(),
      },
    }, basari: 'Talep bakım-onarım ekibine iletildi.');
    if (j == null || !mounted) return;
    final no = j['no']?.toString() ?? '';
    final t = Depo.ben.veri?.talepler.where((x) => x.no == no).firstOrNull;
    if (t != null) {
      final paylas = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Talep kaydedildi'),
          content: const Text('Talebi satınalma grubuyla (Google Chat) da paylaşmak ister misiniz?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hayır')),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.share),
              label: const Text('Paylaş'),
            ),
          ],
        ),
      );
      if (paylas == true) await talepPaylas(t);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final v = Depo.ben.veri!;
    final liste = [...v.secimListesi(), ...v.secimListesi(ekipman: true)];
    return Scaffold(
      appBar: AppBar(title: const Text('Parça / Bakım Talebi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: liste.any((a) => a.no == _arac) ? _arac : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Araç / makine-ekipman (varsa)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Araca bağlı değil (genel malzeme)')),
              for (final a in liste)
                DropdownMenuItem(
                    value: a.no,
                    child: Text('${a.ekipman ? 'Makine-ekipman' : 'Araç'}: ${a.baslik}',
                        overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (s) => setState(() => _arac = s),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in talepTurleri)
                ChoiceChip(label: Text(t), selected: _tur == t, onSelected: (_) => setState(() => _tur = t)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _malzeme,
            decoration: const InputDecoration(
                labelText: 'Parça / malzeme', hintText: 'Örnek: hidrolik hortum, ön lastik, yağ filtresi'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _miktar, decoration: const InputDecoration(labelText: 'Miktar (isteğe bağlı)')),
          const SizedBox(height: 12),
          TextField(
            controller: _aciklama,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Açıklama', hintText: 'Ne kırıldı, ne gerekiyor, aciliyeti'),
          ),
          const SizedBox(height: 12),
          FotoSecici(fotolar: _fotolar, degisti: () => setState(() {})),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
            onPressed: _gonder,
            icon: const Icon(Icons.send),
            label: const Text('Talebi gönder', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
  }
}

/// Talep kartı; bakım-onarım ekibi durum günceller ve bakım kaydı girer.
class TalepKarti extends StatelessWidget {
  const TalepKarti({super.key, required this.t});
  final Talep t;

  Future<void> _durum(BuildContext context) async {
    final not = TextEditingController();
    String? secim;
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Talep ${t.no} · durum', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in talepDurumlari)
                    ChoiceChip(label: Text(d), selected: secim == d, onSelected: (_) => ss(() => secim = d)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: not,
                decoration: const InputDecoration(labelText: 'Not (SAT no, tedarikçi, tahmini tarih)'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: secim == null ? null : () => Navigator.pop(ctx, true),
                child: const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
    if (r == true && secim != null && context.mounted) {
      await islem(context, 'talepDurum', {'no': t.no, 'durum': secim, 'not': not.text.trim()},
          basari: 'Talep güncellendi; talep eden ve formen bilgilendirildi.');
    }
    not.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = Depo.ben.veri!.kisi;
    final ekip = k.bakimEkibi;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Renk.cizgi),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text([t.tur, if (t.arac.isNotEmpty) t.arac].join(' · '),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Rozet.durum(t.durum),
            ],
          ),
          if (t.malzeme.isNotEmpty) Text(t.miktar.isEmpty ? t.malzeme : '${t.malzeme} (${t.miktar})'),
          if (t.aciklama.isNotEmpty) Text(t.aciklama, style: const TextStyle(color: Renk.soluk)),
          Text('${t.tarih} · ${t.talepEden} · ${t.ciftlik}', style: const TextStyle(color: Renk.soluk, fontSize: 12)),
          if (t.not.isNotEmpty) Text('Not: ${t.not}', style: const TextStyle(fontSize: 12)),
          if (t.fotolar.isNotEmpty)
            Wrap(
              spacing: 4,
              children: [
                for (var i = 0; i < t.fotolar.length; i++)
                  TextButton.icon(
                    onPressed: () => launchUrl(Uri.parse(t.fotolar[i]), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.photo_outlined, size: 18),
                    label: Text('Fotoğraf ${i + 1}'),
                  ),
              ],
            ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 6,
            children: [
              TextButton.icon(
                onPressed: () => talepPaylas(t),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Paylaş'),
              ),
              if (ekip && !t.kapali) ...[
                if (t.arac.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => BakimFormu(arac: t.arac, talepNo: t.no))),
                    icon: const Icon(Icons.build_outlined, size: 18),
                    label: const Text('Bakım kaydı gir'),
                  ),
                FilledButton.tonal(onPressed: () => _durum(context), child: const Text('Durum güncelle')),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
