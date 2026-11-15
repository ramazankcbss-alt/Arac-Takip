import 'package:firebase_core/firebase_core.dart';

/// Firebase (anlık bildirim) ayarları — google-services.json'dan alınmıştır.
/// Bu değerler gizli değildir; her Android uygulamasının içinde bulunur ve
/// yalnız com.panagro.arac_takip paketiyle kullanılabilir. Bildirim gönderme
/// yetkisi yalnız sunucudaki (Apps Script) hizmet hesabı anahtarındadır.
const firebaseAyar = FirebaseOptions(
  apiKey: 'AIzaSyBnSy9ZmP_5sMQ70MBNlyADLu0oeIsbhSI',
  appId: '1:516464238916:android:b065e0521c7172878c7711',
  messagingSenderId: '516464238916',
  projectId: 'arac-takip-b5139',
  storageBucket: 'arac-takip-b5139.firebasestorage.app',
);
