import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../servis/api.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesen.dart';

/// Arıza bildirimi: araç, kısa açıklama, isteğe bağlı fotoğraf. Formene ve
/// bakım-onarım personeline bildirim gider.
class ArizaBildirEkrani extends StatefulWidget {
  const ArizaBildirEkrani({super.key, this.onSecili, this.birlikte = const []});
  final String? onSecili;
  /// Devam eden işte araca bağlı makine-ekipman (arıza yeri seçimi için).
  final List<String> birlikte;

  @override
  State<ArizaBildirEkrani> createState() => _ArizaBildirEkraniState();
}

class _ArizaBildirEkraniState extends State<ArizaBildirEkrani> {
  late String? _arac = widget.onSecili;
  final _aciklama = TextEditingController();
  Uint8List? _foto;

  static const _hazir = [
    'Hidrolik kaçak',
    'Yağ kaçağı',
    'Motor hararet yapıyor',
    'Çalışmıyor / marş basmıyor',
    'Lastik patlak',
    'Fren sorunu',
    'Elektrik / ışık arızası',
    'Ekipman bağlantı sorunu',
  ];

  @override
  void dispose() {
    _aciklama.dispose();
    super.dispose();
  }

  Future<void> _fotoCek() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 60,
      );
      if (x == null) return;
      final b = await x.readAsBytes();
      if (mounted) setState(() => _foto = b);
    } catch (_) {
      if (mounted) bildir(context, 'Kamera açılamadı.');
    }
  }

  Future<void> _gonder() async {
    if (_arac == null) {
      bildir(context, 'Arızanın araçta mı makine-ekipmanda mı olduğunu seçin.');
      return;
    }
    if (_aciklama.text.trim().isEmpty && _foto == null) {
      bildir(context, 'Kısa bir açıklama yazın ya da fotoğraf çekin.');
      return;
    }
    final grup = [if (widget.onSecili != null) widget.onSecili!, ...widget.birlikte];
    final j = await islem(context, 'ariza', {
      'arac': _arac,
      'birlikte': grup.where((x) => x != _arac).join(', '),
      'aciklama': _aciklama.text.trim(),
      if (_foto != null) 'foto': base64Encode(_foto!),
    }, basari: 'Arıza bildirildi. Formen ve bakım-onarım personeline iletildi.');
    if (j != null && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final v = Depo.ben.veri!;
    final araclar = [...v.secimListesi(), ...v.secimListesi(ekipman: true)];
    final grup = [if (widget.onSecili != null) widget.onSecili!, ...widget.birlikte]
        .map(v.arac)
        .whereType<Arac>()
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Arıza Bildirimi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (grup.length > 1) ...[
            const Text('Arıza nerede?', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final a in grup)
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: a.no,
                groupValue: _arac,
                onChanged: (s) => setState(() => _arac = s),
                secondary: Icon(a.ekipman ? Icons.construction_outlined : Icons.agriculture_outlined),
                title: Text(a.ekipman ? 'Makine-ekipmanda: ${a.baslik}' : 'Araçta: ${a.baslik}'),
              ),
            const SizedBox(height: 8),
          ] else
            DropdownButtonFormField<String>(
              initialValue: araclar.any((a) => a.no == _arac) ? _arac : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Arızalı araç ya da makine-ekipman'),
              items: [
                for (final a in araclar)
                  DropdownMenuItem(
                      value: a.no,
                      child: Text('${a.ekipman ? 'Makine-ekipman' : 'Araç'}: ${a.baslik} – ${a.ciftlik}',
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (s) => setState(() => _arac = s),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final h in _hazir)
                ActionChip(
                  label: Text(h),
                  onPressed: () {
                    final t = _aciklama.text.trim();
                    _aciklama.text = t.isEmpty ? h : '$t, $h';
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _aciklama,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Açıklama'),
          ),
          const SizedBox(height: 12),
          if (_foto != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(_foto!, height: 200, fit: BoxFit.cover),
            ),
          OutlinedButton.icon(
            onPressed: _fotoCek,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(_foto == null ? 'Fotoğraf çek' : 'Fotoğrafı yenile'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 56), backgroundColor: Renk.kirmizi),
            onPressed: _gonder,
            icon: const Icon(Icons.send),
            label: const Text('Bildir', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
  }
}
