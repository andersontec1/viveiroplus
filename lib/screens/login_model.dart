import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginModel extends ChangeNotifier {
  LoginModel() {
    _inicializar();
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool isLoading = false;
  String? error;
  bool rememberMe = false;
  String usuarioSalvo = '';
  String senhaSalva = '';

  Future<void> _inicializar() async {
    final u = await _secureStorage.read(key: 'usuario');
    final s = await _secureStorage.read(key: 'senha');
    if (u != null && s != null) {
      usuarioSalvo = u;
      senhaSalva = s;
      rememberMe = true;
    }
    notifyListeners();
  }

  void toggleRemember(bool v) {
    rememberMe = v;
    notifyListeners();
  }

  Future<void> login(String nomeUsuario, String senha, BuildContext ctx) async {
    error = null;
    isLoading = true;
    notifyListeners();

    final conn = await _connectivity.checkConnectivity();
    if (conn == ConnectivityResult.none) {
      error = 'Sem conexão. Verifique sua internet.';
      isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final nomeUsuarioNormalizado = nomeUsuario.trim().toLowerCase();

      final snapshot = await _firestore
          .collection('usuarios')
          .where('nomeusuario', isEqualTo: nomeUsuarioNormalizado)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw FirebaseAuthException(code: 'user-not-found');
      }

      final dados = snapshot.docs.first.data();
      final email = dados['email'];
      final cred = await _auth
          .signInWithEmailAndPassword(email: email, password: senha)
          .timeout(const Duration(seconds: 10));

      final user = cred.user;
      if (user == null) throw FirebaseAuthException(code: 'unknown');

      final doc = await _firestore.collection('usuarios').doc(user.uid).get();
      final funcao = (doc.data()?['funcao'] ?? '').toString().toLowerCase();

      // Salva credenciais localmente se ativado
      if (rememberMe) {
        await _secureStorage.write(key: 'usuario', value: nomeUsuarioNormalizado);
        await _secureStorage.write(key: 'senha', value: senha);
      } else {
        await _secureStorage.delete(key: 'usuario');
        await _secureStorage.delete(key: 'senha');
      }

      isLoading = false;
      notifyListeners();

      if (!ctx.mounted) return;

      // Redirecionamento baseado na função
      const funcoesPermitidas = [
        'admin',
        'gerente',
        'supervisor',
        'arraçoador',
        'registrador',
      ];

      if (funcoesPermitidas.contains(funcao)) {
        Navigator.of(ctx).pushReplacementNamed('/menu');
      } else {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Você não tem permissão para acessar o sistema.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on TimeoutException {
      error = 'Servidor demorou para responder.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        error = 'Usuário não encontrado';
      } else if (e.code == 'wrong-password') {
        error = 'Senha incorreta';
      } else {
        error = 'Erro no login (${e.code}).';
      }
    } catch (e) {
      error = 'Erro inesperado: ${e.toString()}';
    }

    isLoading = false;
    notifyListeners();
  }
}
