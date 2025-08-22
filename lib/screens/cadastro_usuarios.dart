// cadastro_usuarios.dart atualizado com criação correta de usuário + suporte para redefinir senha
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/degrade_fundo.dart';

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

  // Permissões disponíveis (baseadas nas telas do menu principal)
  final List<Map<String, String>> _todasPermissoes = [
    {'chave': 'analise_agua', 'label': 'Análise da Água'},
    {'chave': 'registros_analise', 'label': 'Registros de Análise'},
    {'chave': 'registro_racao', 'label': 'Registro de Ração'},
    {'chave': 'historico_racao', 'label': 'Histórico de Ração'},
    {'chave': 'relatorios', 'label': 'Relatórios'},
    {'chave': 'listar_viveiros', 'label': 'Listar Viveiros'},
    {'chave': 'listar_bercarios', 'label': 'Listar Berçários'},
    {'chave': 'cadastro_viveiro', 'label': 'Cadastrar Viveiro'},
    {'chave': 'editar_viveiro', 'label': 'Editar Viveiro'},
    {'chave': 'usuarios', 'label': 'Cadastrar Usuário'},
    {'chave': 'gerenciar_usuarios', 'label': 'Gerenciar Usuários'},
    {'chave': 'painel_web', 'label': 'Painel Web'},
    {'chave': 'biomassa', 'label': 'Cálculo de Biomassa'},
    {'chave': 'insumos', 'label': 'Cadastro de Insumos'},
    {'chave': 'estoque_insumos', 'label': 'Estoque de Insumos'},
    {'chave': 'ciclos_viveiro', 'label': 'Ciclos por Viveiro'},
    {'chave': 'pendencias', 'label': 'Pendências'},
    {'chave': 'notificacoes', 'label': 'Notificações'},
    {'chave': 'resumo_detalhado', 'label': 'Resumo Diário'},
  ];
  final List<String> _permissoesSelecionadas = [];

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
    // TODO: Se for edição, carregar permissões do usuário e preencher _permissoesSelecionadas
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

      // Obter usuário logado (criador)
      final criador = FirebaseAuth.instance.currentUser;
      String? nomeCriador;
      if (criador != null) {
        final snap = await FirebaseFirestore.instance.collection('usuarios').doc(criador.uid).get();
        nomeCriador = snap.data()?['nome'] ?? criador.uid;
      }
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'uid': uid,
        'nome': nome,
        'nomeusuario': nomeusuario,
        'email': email,
        'funcao': _funcaoSelecionada,
        'permissoes': _permissoesSelecionadas,
        'criadoEm': FieldValue.serverTimestamp(),
        'criadoPor': nomeCriador ?? 'desconhecido',
      });

      _mostrarSnackBar(widget.redefinicao ? 'Senha redefinida com sucesso!' : 'Usuário criado com sucesso!', sucesso: true);
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String mensagem = 'Erro: ${e.message}';
      if (e.code == 'email-already-in-use') {
        mensagem = 'Este email já está sendo usado por outro usuário';
      } else if (e.code == 'weak-password') {
        mensagem = 'A senha é muito fraca. Use pelo menos 6 caracteres';
      }
      _mostrarSnackBar(mensagem, erro: true);
    } catch (e) {
      _mostrarSnackBar('Erro inesperado: ${e.toString()}', erro: true);
    } finally {
      setState(() => _salvando = false);
    }
  }

  void _mostrarSnackBar(String msg, {bool erro = false, bool sucesso = false}) {
    final cor = erro
        ? Colors.red
        : sucesso
            ? const Color(0xFF049F56)
            : Colors.grey;

    final icone = erro
        ? Icons.error
        : sucesso
            ? Icons.check_circle
            : Icons.info;

    final emoji = erro
        ? '❌'
        : sucesso
            ? '✅'
            : 'ℹ️';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icone, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$emoji $msg'),
            ),
          ],
        ),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.redefinicao ? '🔄 Redefinir Senha' : '👤 Novo Usuário',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: DegradeFundo(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const SizedBox(height: 20),
                  // Header modernizado
                  _buildHeader(),
                  const SizedBox(height: 32),
                  // Formulário principal
                  _buildFormularioPrincipal(),
                  const SizedBox(height: 24),
                  // Seção de permissões
                  _buildSecaoPermissoes(),
                  const SizedBox(height: 32),
                  // Botão de ação
                  _buildBotaoAcao(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF045D3A), Color(0xFF049F56)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF045D3A).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              widget.redefinicao ? Icons.key : Icons.person_add_alt_1,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.redefinicao ? '🔄 Redefinir Senha' : '👤 Cadastro de Usuário',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF045D3A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.redefinicao
                ? 'Altere a senha de um usuário já cadastrado'
                : 'Preencha os dados para criar um novo usuário',
            style: TextStyle(
              fontSize: 16,
              color: const Color(0xFF045D3A).withOpacity(0.7),
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFormularioPrincipal() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF045D3A), Color(0xFF049F56)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                '📝 Dados do Usuário',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF045D3A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Nome completo
          TextFormField(
            controller: _nomeCompletoController,
            enabled: !widget.redefinicao,
            style: const TextStyle(color: Color(0xFF045D3A)),
            decoration: InputDecoration(
              labelText: 'Nome completo',
              labelStyle: TextStyle(color: const Color(0xFF045D3A).withOpacity(0.7)),
              prefixIcon: const Icon(Icons.person, color: Color(0xFF049F56)),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFF049F56), width: 2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome completo' : null,
          ),
          const SizedBox(height: 16),
          
          // Nome de usuário
          TextFormField(
            controller: _usernameController,
            enabled: !widget.redefinicao,
            style: const TextStyle(color: Color(0xFF045D3A)),
            decoration: InputDecoration(
              labelText: 'Nome de usuário',
              labelStyle: TextStyle(color: const Color(0xFF045D3A).withOpacity(0.7)),
              prefixIcon: const Icon(Icons.account_circle, color: Color(0xFF049F56)),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFF049F56), width: 2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
            ),
            validator: (v) {
              final valor = v?.trim().toLowerCase() ?? '';
              if (valor.isEmpty) return 'Informe o nome de usuário';
              if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(valor)) {
                return 'Use apenas letras minúsculas, números, "." e "-"';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Senha
          TextFormField(
            controller: _senhaController,
            obscureText: !_mostrarSenha,
            style: const TextStyle(color: Color(0xFF045D3A)),
            decoration: InputDecoration(
              labelText: 'Senha',
              labelStyle: TextStyle(color: const Color(0xFF045D3A).withOpacity(0.7)),
              prefixIcon: const Icon(Icons.lock, color: Color(0xFF049F56)),
              suffixIcon: IconButton(
                icon: Icon(
                  _mostrarSenha ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF049F56),
                ),
                onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFF049F56), width: 2),
              ),
            ),
            validator: (v) => v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
          ),
          const SizedBox(height: 16),
          
          // Confirmar senha
          TextFormField(
            controller: _confirmarSenhaController,
            obscureText: !_mostrarSenha,
            style: const TextStyle(color: Color(0xFF045D3A)),
            decoration: InputDecoration(
              labelText: 'Confirmar senha',
              labelStyle: TextStyle(color: const Color(0xFF045D3A).withOpacity(0.7)),
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF049F56)),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFF049F56), width: 2),
              ),
            ),
            validator: (v) => v != _senhaController.text ? 'Senhas não conferem' : null,
          ),
          const SizedBox(height: 16),
          
          // Função
          DropdownButtonFormField<String>(
            value: _funcaoSelecionada,
            style: const TextStyle(color: Color(0xFF045D3A)),
            decoration: InputDecoration(
              labelText: 'Função',
              labelStyle: TextStyle(color: const Color(0xFF045D3A).withOpacity(0.7)),
              prefixIcon: const Icon(Icons.work, color: Color(0xFF049F56)),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFF049F56), width: 2),
              ),
            ),
            dropdownColor: Colors.white,
            isExpanded: true,
            items: _funcoesComDescricao.map((item) {
              return DropdownMenuItem<String>(
                value: item['valor'],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['titulo']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF045D3A),
                      ),
                    ),
                    Text(
                      item['descricao']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF045D3A).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            selectedItemBuilder: (context) {
              return _funcoesComDescricao.map((item) {
                return Text(
                  item['titulo']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList();
            },
            onChanged: (v) => setState(() => _funcaoSelecionada = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoPermissoes() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF045D3A), Color(0xFF049F56)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.security, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                '🔐 Permissões do Sistema',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF045D3A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Selecione as funcionalidades que este usuário poderá acessar:',
            style: TextStyle(
              color: const Color(0xFF045D3A).withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _todasPermissoes.map((perm) {
              final isSelected = _permissoesSelecionadas.contains(perm['chave']);
              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _permissoesSelecionadas.remove(perm['chave']!);
                    } else {
                      _permissoesSelecionadas.add(perm['chave']!);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF045D3A), Color(0xFF049F56)],
                          )
                        : null,
                    color: isSelected ? null : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF049F56)
                          : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    perm['label']!,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF045D3A),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoAcao() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF045D3A), Color(0xFF049F56)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF045D3A).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        icon: _salvando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                widget.redefinicao ? Icons.key : Icons.person_add,
                color: Colors.white,
              ),
        label: Text(
          _salvando
              ? 'Processando...'
              : widget.redefinicao
                  ? '🔄 Redefinir Senha'
                  : '👤 Cadastrar Usuário',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onPressed: _salvando ? null : _criarUsuario,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
