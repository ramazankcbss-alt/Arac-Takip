import 'package:flutter/material.dart';

import '../servis/api.dart';
import '../tema.dart';
import 'bilesen.dart';

class BildirimlerSayfasi extends StatefulWidget {
  const BildirimlerSayfasi({super.key});

  @override
  State<BildirimlerSayfasi> createState() => _BildirimlerSayfasiState();
}

class _BildirimlerSayfasiState extends State<BildirimlerSayfasi> {
  @override
  void initState() {
    super.initState();
    if ((Depo.ben.veri?.okunmamis ?? 0) > 0) {
      Depo.ben.gonder('bildirimOkundu').then((_) => Depo.ben.yenile()).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Depo.ben,
      builder: (context, _) {
        final l = Depo.ben.veri?.bildirimler ?? const [];
        return Scaffold(
          appBar: AppBar(title: const Text('Bildirimler')),
          body: l.isEmpty
              ? const Bos('Bildirim yok.', ikon: Icons.notifications_none)
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: l.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final b = l[i];
                    return Panel(
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                b.tur.startsWith('Arıza') ? Icons.report_problem : Icons.info_outline,
                                color: b.tur.startsWith('Arıza') ? Renk.kirmizi : Renk.mavi,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(b.baslik,
                                    style: TextStyle(fontWeight: b.okundu ? FontWeight.w500 : FontWeight.w700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(b.metin),
                          const SizedBox(height: 4),
                          Text(b.zaman, style: const TextStyle(color: Renk.soluk, fontSize: 12)),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
