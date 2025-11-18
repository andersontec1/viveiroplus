import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _lembrarMe = true;

  @override
  void initState() {
    super.initState();
    _carregarVersaoApp();
    _inicializarPrefsEAutofill();
  }

  Future<void> _carregarVersaoApp() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _versaoApp = 'Versão ${info.version}';
    });
  }

  Future<void> _inicializarPrefsEAutofill() async {
    // Persistência Web: permite que o navegador salve a sessão (e o Chrome ofereça lembrar senha)
    if (kIsWeb) {
      try {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      } catch (_) {}
    }

    // Carregar usuário lembrado
    final prefs = await SharedPreferences.getInstance();
    final lembrado = prefs.getBool('lembrar_me') ?? true;
    final usuario = prefs.getString('login_usuario') ?? '';
    if (!mounted) return;
    setState(() {
      _lembrarMe = lembrado;
      if (lembrado && usuario.isNotEmpty) {
        _usernameController.text = usuario;
      }
    });
  }

  Future<void> _fazerLogin() async {
    final nomeUsuario = _usernameController.text.trim();
    final senha = _senhaController.text.trim();

    if (nomeUsuario.isEmpty || senha.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, preencha todos os campos.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (mounted) setState(() => _carregando = true);

    try {
      // Salvar preferências de lembrar-me
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('lembrar_me', _lembrarMe);

      // Tenta localizar por 'nomeUsuario' (camelCase) e faz fallback para 'nomeusuario' (snake/minúsculo)
      QuerySnapshot<Map<String, dynamic>> query = await FirebaseFirestore
          .instance
          .collection('usuarios')
          .where('nomeUsuario', isEqualTo: nomeUsuario)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        query = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('nomeusuario', isEqualTo: nomeUsuario)
            .limit(1)
            .get();
      }

      if (query.docs.isEmpty) {
        throw Exception('Nome de usuário não encontrado.');
      }

      final docRef = query.docs.first.reference;
      final email = query.docs.first['email'];

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );

      // Atualiza o carimbo de último login no documento do usuário usando o UID
      try {
        final uid = cred.user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          print('DEBUG: Tentando atualizar ultimoLogin para UID: $uid');
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(uid)
              .update({'ultimoLogin': FieldValue.serverTimestamp()});
          print('DEBUG: ultimoLogin atualizado com sucesso para UID');
        }
        // Fallback: se o doc por UID não existir (dados antigos), atualiza o documento encontrado pela busca
        print(
          'DEBUG: Tentando atualizar ultimoLogin no documento encontrado pela busca',
        );
        await docRef.update({'ultimoLogin': FieldValue.serverTimestamp()});
        print('DEBUG: ultimoLogin atualizado com sucesso via docRef');
      } catch (e) {
        // Ignora erro de atualização de auditoria para não bloquear o login
        print('DEBUG: Erro ao atualizar ultimoLogin: $e');
      }

      // Se marcado, mantém o nome de usuário; senão, limpa
      if (_lembrarMe) {
        await prefs.setString('login_usuario', nomeUsuario);
      } else {
        await prefs.remove('login_usuario');
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/menu');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: DegradeFundo(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth;
              final isWide = maxW > 640;
              final content = AutofillGroup(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 24),
                    Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: isWide ? 200 : 140,
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _usernameController,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.emailAddress,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: const InputDecoration(
                        labelText: 'Nome de usuário',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _senhaController,
                      autofillHints: const [AutofillHints.password],
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _fazerLogin(),
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: const InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _lembrarMe,
                              onChanged: (v) =>
                                  setState(() => _lembrarMe = v ?? true),
                            ),
                            const Text('Lembrar-me'),
                          ],
                        ),
                        TextButton(
                          onPressed: () async {
                            final email = await _resolverEmailPorNomeUsuario(
                              _usernameController.text.trim(),
                            );
                            if (!context.mounted)
                              return; // evita usar context após await
                            if (email == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Informe o nome de usuário para recuperar a senha.',
                                  ),
                                ),
                              );
                              return;
                            }
                            try {
                              await FirebaseAuth.instance
                                  .sendPasswordResetEmail(email: email);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Link de redefinição enviado para o e-mail.',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erro ao enviar e-mail: $e'),
                                ),
                              );
                            }
                          },
                          child: const Text('Esqueci minha senha'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _carregando
                        ? const Center(child: CircularProgressIndicator())
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _fazerLogin,
                              icon: const Icon(Icons.login),
                              label: Text(
                                'Entrar',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                          ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        _versaoApp,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );

              if (isWide) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: content,
                    ),
                  ),
                );
              }
              return content;
            },
          ),
        ),
      ),
    );
  }

  Future<String?> _resolverEmailPorNomeUsuario(String nomeUsuario) async {
    if (nomeUsuario.isEmpty) return null;
    try {
      QuerySnapshot<Map<String, dynamic>> q = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('nomeUsuario', isEqualTo: nomeUsuario)
          .limit(1)
          .get();
      if (q.docs.isEmpty) {
        q = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('nomeusuario', isEqualTo: nomeUsuario)
            .limit(1)
            .get();
      }
      if (q.docs.isEmpty) return null;
      return q.docs.first['email'] as String?;
    } catch (_) {
      return null;
    }
  }
}
