import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../servis/api.dart';
import '../tema.dart';
import 'bilesen.dart';

/// Arıza bildirimi: araç, kısa açıklama, isteğe bağlı fotoğraf. Formene ve
/// bakım-onarım personeline bildirim gider.
class ArizaBildirEkrani extends StatefulWidget {
  const ArizaBildirEkrani({super.key, this.onSecili});
  final String? onSecili;

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
      bildir(context, 'Aracı seçin.');
      return;
    }
    if (_aciklama.text.trim().isEmpty && _foto == null) {
      bildir(context, 'Kısa bir açıklama yazın ya da fotoğraf çekin.');
      return;
    }
    final j = await islem(context, 'ariza', {
      'arac': _arac,
      'aciklama': _aciklama.text.trim(),
      if (_foto != null) 'foto': base64Encode(_foto!),
    }, basari: 'Arıza bildirildi. Formen ve bakım-onarım personeline iletildi.');
    if (j != null && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final v = Depo.ben.veri!;
    final araclar = v.secimListesi();
    return Scaffold(
      appBar: AppBar(title: const Text('Arıza Bildirimi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: araclar.any((a) => a.no == _arac) ? _arac : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Araç'),
            items: [
              for (final a in araclar)
                DropdownMenuItem(value: a.no, child: Text('${a.baslik} – ${a.ciftlik}', overflow: TextOverflow.ellipsis)),
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
