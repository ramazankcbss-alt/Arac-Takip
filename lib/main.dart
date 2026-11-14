import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ekranlar/ana.dart';
import 'ekranlar/giris.dart';
import 'servis/api.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Depo.ben.baslat();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const AracTakipApp());
}

class AracTakipApp extends StatelessWidget {
  const AracTakipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Araç Takip',
      debugShowCheckedModeBanner: false,
      theme: temaOlustur(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Kapi(),
    );
  }
}

/// Oturum durumuna göre giriş, onay bekleme ya da ana ekranı gösterir.
class Kapi extends StatelessWidget {
  const Kapi({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Depo.ben,
      builder: (context, _) {
        final d = Depo.ben;
        if (!d.girisYapildi) return const GirisEkrani();
        if (!d.onayli) return const OnayBekleniyorEkrani();
        return const AnaEkran();
      },
    );
  }
}
