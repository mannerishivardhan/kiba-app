import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiba_app/core/router/app_router.dart';
import 'package:kiba_app/core/theme/app_theme.dart';
import 'package:kiba_app/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firestore disk cache (100 MB).
  // Repeat reads of the same doc come from disk — zero network reads billed.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(
    const ProviderScope(
      child: KibaApp(),
    ),
  );
}

class KibaApp extends ConsumerWidget {
  const KibaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Kiba',
      debugShowCheckedModeBanner: false,
      theme: KibaTheme.light,
      darkTheme: KibaTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
