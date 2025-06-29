import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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
        ),
      ),
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
