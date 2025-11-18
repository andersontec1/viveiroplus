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

  final doc = await FirebaseFirestore.instance
      .collection('usuarios')
      .doc(user.uid)
      .get();

  if (doc.exists) {
    UsuarioLogado.uid = user.uid;
    UsuarioLogado.username = doc.data()?['username'];
    UsuarioLogado.nivel = doc.data()?['nivel'];
  }
}

// Classe helper para compatibilidade com o código que usa AuthHelper
class AuthHelper {
  // Retorna o usuário atual do Firebase Auth
  static User? obterUsuarioLogado() {
    return FirebaseAuth.instance.currentUser;
  }

  // Retorna o username do usuário logado
  static String? obterUsername() {
    return UsuarioLogado.username;
  }

  // Retorna o nível do usuário logado
  static String? obterNivel() {
    return UsuarioLogado.nivel;
  }

  // Retorna o UID do usuário logado
  static String? obterUid() {
    return UsuarioLogado.uid;
  }

  // Verifica se o usuário está logado
  static bool estaLogado() {
    return FirebaseAuth.instance.currentUser != null;
  }

  // Faz logout do usuário
  static Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    UsuarioLogado.uid = null;
    UsuarioLogado.username = null;
    UsuarioLogado.nivel = null;
  }
}
