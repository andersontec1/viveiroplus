import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:viveiro_plus/screens/tela_login.dart';
import 'package:viveiro_plus/screens/menu_principal.dart';
import 'package:viveiro_plus/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:viveiro_plus/screens/login_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null); // ESSENCIAL para evitar o erro
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => LoginModel(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Viveiro+',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins',
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: Colors.black,
          displayColor: Colors.black,
        ).copyWith(
          displayLarge: ThemeData.light().textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold),
          displayMedium: ThemeData.light().textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
          displaySmall: ThemeData.light().textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
          headlineLarge: ThemeData.light().textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
          headlineMedium: ThemeData.light().textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          headlineSmall: ThemeData.light().textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          titleLarge: ThemeData.light().textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          titleMedium: ThemeData.light().textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          titleSmall: ThemeData.light().textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          bodyLarge: ThemeData.light().textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          bodyMedium: ThemeData.light().textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          bodySmall: ThemeData.light().textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          labelLarge: ThemeData.light().textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          labelMedium: ThemeData.light().textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
          labelSmall: ThemeData.light().textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      home: const TelaLogin(),
      onGenerateRoute: _onGenerateRouteWithFade,
    );
  }
Route<dynamic> _onGenerateRouteWithFade(RouteSettings settings) {
  switch (settings.name) {
      case '/menu':
      case '/verificacao':
        return _buildFadeRoute(FutureBuilder(
          future: _carregarFuncaoUsuario(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final funcao = snapshot.data ?? '';
            final expandirResumo = ['admin', 'gerente', 'supervisor'].contains(funcao);
            return MenuPrincipal(resumoExpandido: expandirResumo);
          },
        ));
      case '/login':
      default:
        return _buildFadeRoute(const TelaLogin());
    }
  }

  PageRouteBuilder _buildFadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  Future<String> _carregarFuncaoUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      return doc.data()?['funcao'] ?? '';
    }
    return '';
  }
}
