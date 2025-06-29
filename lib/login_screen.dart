import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../widgets/degrade_fundo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _carregando = false;
  String _versaoApp = '';

  @override
  void initState() {
    super.initState();
    _carregarVersaoApp();
  }

  Future<void> _carregarVersaoApp() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _versaoApp = 'Versão ${info.version}';
    });
  }

  Future<void> _fazerLogin() async {
    final nomeUsuario = _usernameController.text.trim();
    final senha = _senhaController.text.trim();

    if (nomeUsuario.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, preencha todos os campos.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _carregando = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('nomeUsuario', isEqualTo: nomeUsuario)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception('Nome de usuário não encontrado.');
      }

      final email = query.docs.first['email'];

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );

      Navigator.pushReplacementNamed(context, '/menu');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: DegradeFundo(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _usernameController,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: const InputDecoration(labelText: 'Nome de usuário'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _senhaController,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: const InputDecoration(labelText: 'Senha'),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              _carregando
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _fazerLogin,
                      child: Text('Entrar', style: Theme.of(context).textTheme.labelLarge),
                    ),
              const Spacer(),
              Text(
                _versaoApp,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}