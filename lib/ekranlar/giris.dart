import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../servis/api.dart';
import '../tema.dart';

/// İlk giriş: telefon numarası + 4 haneli PIN. Sonraki açılışlarda giriş
/// kendiliğinden yapılır.
class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final _tel = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  bool _bekle = false;
  String? _hata;

  @override
  void dispose() {
    _tel.dispose();
    _pin.dispose();
    _pin2.dispose();
    super.dispose();
  }

  Future<void> _gir() async {
    final t = telefonDuzelt(_tel.text);
    setState(() => _hata = null);
    if (t == null) {
      setState(() => _hata = 'Telefon numarasını 05xx xxx xx xx biçiminde yazın.');
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(_pin.text)) {
      setState(() => _hata = 'PIN 4 haneli olmalı.');
      return;
    }
    if (_pin2.text.isNotEmpty && _pin2.text != _pin.text) {
      setState(() => _hata = 'PIN tekrarı uyuşmuyor.');
      return;
    }
    setState(() => _bekle = true);
    try {
      await Depo.ben.giris(telefon: t, pin: _pin.text, cihazAdi: 'Android');
      if (Depo.ben.onayli) await Depo.ben.yenile();
    } on ApiHatasi catch (e) {
      if (mounted) setState(() => _hata = e.mesaj);
    } finally {
      if (mounted) setState(() => _bekle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Araç Takip')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.agriculture, size: 64, color: Renk.ana),
          const SizedBox(height: 8),
          const Text('Araç ve Makine Kullanım Takibi',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Personel listesinde kayıtlı telefon numaranızla giriş yapın. '
            'İlk girişte kendinize 4 haneli bir PIN belirleyin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Renk.soluk),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _tel,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefon numarası', hintText: '05xx xxx xx xx'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'PIN (4 hane)', counterText: ''),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin2,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
                labelText: 'PIN tekrarı (yalnız ilk girişte)', counterText: ''),
          ),
          if (_hata != null) ...[
            const SizedBox(height: 12),
            Text(_hata!, style: const TextStyle(color: Renk.kirmizi)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _bekle ? null : _gir,
            icon: _bekle
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.login),
            label: const Text('Giriş yap'),
          ),
          if (!Depo.ben.sunucuTanimli) ...[
            const SizedBox(height: 16),
            const Text('Uyarı: bu derlemede sunucu adresi tanımlı değil.',
                textAlign: TextAlign.center, style: TextStyle(color: Renk.amber)),
          ],
        ],
      ),
    );
  }
}

/// Cihaz onayı bekleniyor (formen ya da Makine-Ekipman Sorumlusu onaylar).
class OnayBekleniyorEkrani extends StatefulWidget {
  const OnayBekleniyorEkrani({super.key});

  @override
  State<OnayBekleniyorEkrani> createState() => _OnayBekleniyorEkraniState();
}

class _OnayBekleniyorEkraniState extends State<OnayBekleniyorEkrani> {
  @override
  Widget build(BuildContext context) {
    final d = Depo.ben;
    final reddedildi = d.cihazDurum == 'Reddedildi';
    return Scaffold(
      appBar: AppBar(title: const Text('Araç Takip')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(reddedildi ? Icons.block : Icons.hourglass_top,
              size: 64, color: reddedildi ? Renk.kirmizi : Renk.amber),
          const SizedBox(height: 12),
          Text(
            reddedildi ? 'Cihaz onayı reddedildi' : 'Cihaz onayı bekleniyor',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            reddedildi
                ? 'Formeninizle görüşün.'
                : 'Sayın ${d.kisi?.ad ?? ''}, telefonunuzun formeniniz ya da Makine-Ekipman '
                    'Sorumlusu tarafından onaylanması gerekiyor. Onaylandıktan sonra '
                    'aşağıdaki düğmeye basın.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Renk.soluk),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: d.yukleniyor
                ? null
                : () async {
                    await d.yenile();
                    if (mounted && d.hata != null) bildir(context, d.hata!);
                  },
            icon: const Icon(Icons.refresh),
            label: const Text('Onay durumunu kontrol et'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: d.cikis, child: const Text('Farklı numarayla giriş')),
        ],
      ),
    );
  }
}
