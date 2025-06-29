// cadastro_usuarios.dart atualizado com criação correta de usuário + suporte para redefinir senha
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/degrade_fundo.dart'; // adicione este import

class CadastroUsuarioScreen extends StatefulWidget {
  const CadastroUsuarioScreen({super.key, this.uid, this.nomeAtual, this.nomeUsuarioAtual, this.funcaoAtual, this.redefinicao = false});
  final String? uid;
  final String? nomeAtual;
  final String? nomeUsuarioAtual;
  final String? funcaoAtual;
  final bool redefinicao;

  @override
  State<CadastroUsuarioScreen> createState() => _CadastroUsuarioScreenState();
}

class _CadastroUsuarioScreenState extends State<CadastroUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCompletoController = TextEditingController();
  final _usernameController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  bool _mostrarSenha = false;

  final List<Map<String, String>> _funcoesComDescricao = [
    {
      'valor': 'registrador',
      'titulo': 'Registrador',
      'descricao': 'Registra pH, temperatura, oxigênio e salinidade',
    },
    {
      'valor': 'arraçoador',
      'titulo': 'Arraçoador',
      'descricao': 'Registra quantidade de ração e sobras',
    },
    {
      'valor': 'supervisor',
      'titulo': 'Supervisor',
      'descricao': 'Visualiza registros e relatórios',
    },
    {
      'valor': 'gerente',
      'titulo': 'Gerente',
      'descricao': 'Gerencia usuários e viveiros',
    },
    {
      'valor': 'admin',
      'titulo': 'Admin',
      'descricao': 'Acesso total ao sistema',
    },
  ];

  String _funcaoSelecionada = 'registrador';
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    if (widget.redefinicao && widget.nomeAtual != null && widget.nomeUsuarioAtual != null && widget.funcaoAtual != null) {
      _nomeCompletoController.text = widget.nomeAtual!;
      _usernameController.text = widget.nomeUsuarioAtual!;
      _funcaoSelecionada = widget.funcaoAtual!;
    }
  }

  Future<void> _criarUsuario() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    try {
      final nome = _nomeCompletoController.text.trim();
      final nomeusuario = _usernameController.text.trim().toLowerCase();
      final senha = _senhaController.text.trim();
      final email = '$nomeusuario@viveiroplus.com';

      if (!widget.redefinicao) {
        final resultado = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('nomeusuario', isEqualTo: nomeusuario)
            .limit(1)
            .get();

        if (resultado.docs.isNotEmpty) {
          _mostrarSnackBar('Nome de usuário já existe. Escolha outro.', erro: true);
          setState(() => _salvando = false);
          return;
        }
      }

      if (widget.redefinicao && widget.uid != null) {
        await FirebaseFirestore.instance.collection('usuarios').doc(widget.uid).delete();
      }

      final credenciais = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: senha);

      final uid = credenciais.user!.uid;

      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'uid': uid,
        'nome': nome,
        'nomeusuario': nomeusuario,
        'email': email,
        'funcao': _funcaoSelecionada,
        'criadoEm': FieldValue.serverTimestamp(),
      });

      _mostrarSnackBar(widget.redefinicao ? 'Senha redefinida com sucesso' : 'Usuário criado com sucesso', sucesso: true);
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _mostrarSnackBar('Erro: ${e.message}', erro: true);
    } finally {
      setState(() => _salvando = false);
    }
  }

  void _mostrarSnackBar(String msg, {bool erro = false, bool sucesso = false}) {
    final cor = erro
        ? Colors.red
        : sucesso
            ? Colors.green
            : Colors.grey;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: cor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.redefinicao ? 'Redefinir Senha' : 'Novo Usuário')),
      body: DegradeFundo(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _nomeCompletoController,
                  enabled: !widget.redefinicao,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome completo' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  enabled: !widget.redefinicao,
                  decoration: const InputDecoration(
                    labelText: 'Nome de usuário',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final valor = v?.trim().toLowerCase() ?? '';
                    if (valor.isEmpty) return 'Informe o nome de usuário';
                    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(valor)) {
                      return 'Use apenas letras minúsculas, números e "_"';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _senhaController,
                  obscureText: !_mostrarSenha,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_mostrarSenha ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
                    ),
                  ),
                  validator: (v) => v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmarSenhaController,
                  obscureText: !_mostrarSenha,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar senha',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v != _senhaController.text ? 'Senhas não conferem' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _funcaoSelecionada,
                  decoration: const InputDecoration(
                    labelText: 'Função',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: _funcoesComDescricao.map((item) {
                    return DropdownMenuItem<String>(
                      value: item['valor'],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['titulo']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(item['descricao']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    );
                  }).toList(),
                  selectedItemBuilder: (context) {
                    return _funcoesComDescricao.map((item) {
                      return Text(item['titulo']!, style: const TextStyle(fontWeight: FontWeight.bold));
                    }).toList();
                  },
                  onChanged: (v) => setState(() => _funcaoSelecionada = v!),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(widget.redefinicao ? 'Redefinir Senha' : 'Cadastrar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _salvando ? null : _criarUsuario,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
