//auth_helper.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UsuarioLogado {
  static String? uid;
  static String? username;
  static String? nivel;
}

Future<void> carregarDadosUsuarioLogado() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();

  if (doc.exists) {
    UsuarioLogado.uid = user.uid;
    UsuarioLogado.username = doc.data()?['username'];
    UsuarioLogado.nivel = doc.data()?['nivel']; // ✅ CAMPO PADRÃO
  }
}
