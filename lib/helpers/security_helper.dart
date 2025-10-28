// security_helper.dart - Validações de segurança
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'permissions_helper.dart';

class SecurityHelper {
  /// Verifica se o usuário atual tem permissão para uma ação específica
  static Future<bool> temPermissao(String acao) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (!doc.exists) return false;

      final data = doc.data()!;
      final funcao = data['funcao'] as String?;
      final permissoesRaw = data['permissoes'];
      final canonical = PermissionsHelper.normalize(permissoesRaw);

      // Fallback para presets da função quando não há lista explícita
      final effective = canonical.isNotEmpty
          ? canonical
          : PermissionsHelper.forRole(funcao);

      return PermissionsHelper.contains(effective, acao) || (funcao == 'admin');
    } catch (e) {
      return false;
    }
  }

  /// Verifica se o usuário pode gerenciar outros usuários
  static Future<bool> podeGerenciarUsuarios() async {
    return await temPermissao('gerenciar_usuarios') ||
        await temFuncaoAdministrativa();
  }

  /// Verifica se o usuário tem função administrativa
  static Future<bool> temFuncaoAdministrativa() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (!doc.exists) return false;

      final funcao = doc.data()!['funcao'] as String?;
      return ['admin', 'gerente'].contains(funcao);
    } catch (e) {
      return false;
    }
  }

  /// Verifica se o usuário pode excluir outros usuários
  static Future<bool> podeExcluirUsuarios() async {
    return await temFuncaoAdministrativa();
  }

  /// Verifica se o usuário pode editar outros usuários
  static Future<bool> podeEditarUsuarios() async {
    return await podeGerenciarUsuarios();
  }

  /// Verifica se o usuário pode alterar funções
  static Future<bool> podeAlterarFuncoes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (!doc.exists) return false;

      final funcao = doc.data()!['funcao'] as String?;
      return funcao == 'admin'; // Apenas admin pode alterar funções
    } catch (e) {
      return false;
    }
  }

  /// Valida se uma função é superior à outra
  static bool funcaoSuperior(String funcaoAtual, String funcaoTarget) {
    const hierarquia = {
      'admin': 5,
      'gerente': 4,
      'supervisor': 3,
      'arraçoador': 2,
      'registrador': 1,
    };

    final nivelAtual = hierarquia[funcaoAtual] ?? 0;
    final nivelTarget = hierarquia[funcaoTarget] ?? 0;

    return nivelAtual > nivelTarget;
  }

  /// Verifica se o usuário pode alterar outro usuário baseado na hierarquia
  static Future<bool> podeAlterarUsuario(String uidTarget) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Admin pode alterar qualquer um
    if (await _isAdmin()) return true;

    try {
      // Buscar dados dos dois usuários
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      final targetUserDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uidTarget)
          .get();

      if (!currentUserDoc.exists || !targetUserDoc.exists) return false;

      final currentFuncao = currentUserDoc.data()!['funcao'] as String?;
      final targetFuncao = targetUserDoc.data()!['funcao'] as String?;

      // Gerente pode alterar usuários de função inferior
      if (currentFuncao == 'gerente') {
        return funcaoSuperior(currentFuncao!, targetFuncao ?? '');
      }

      // Outros só podem alterar a si mesmos
      return user.uid == uidTarget;
    } catch (e) {
      return false;
    }
  }

  /// Valida senha forte
  static bool senhaForte(String senha) {
    if (senha.length < 8) return false;

    final temLetraMaiuscula = senha.contains(RegExp(r'[A-Z]'));
    final temLetraMinuscula = senha.contains(RegExp(r'[a-z]'));
    final temNumero = senha.contains(RegExp(r'[0-9]'));
    final temCaractereEspecial = senha.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
    );

    return temLetraMaiuscula &&
        temLetraMinuscula &&
        temNumero &&
        temCaractereEspecial;
  }

  /// Valida nome de usuário
  static bool nomeUsuarioValido(String nomeUsuario) {
    if (nomeUsuario.length < 3) return false;

    // Apenas letras, números e underscore
    final regex = RegExp(r'^[a-zA-Z0-9_]+$');
    return regex.hasMatch(nomeUsuario);
  }

  /// Verifica se nome de usuário já existe
  static Future<bool> nomeUsuarioExiste(
    String nomeUsuario, {
    String? uidIgnorar,
  }) async {
    try {
      final query = FirebaseFirestore.instance
          .collection('usuarios')
          .where('nomeusuario', isEqualTo: nomeUsuario.toLowerCase());

      final docs = await query.get();

      if (uidIgnorar != null) {
        return docs.docs.any((doc) => doc.id != uidIgnorar);
      }

      return docs.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Removido _validarPermissao: lógica centralizada em PermissionsHelper

  /// Verifica se é admin
  static Future<bool> _isAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      return doc.exists && doc.data()!['funcao'] == 'admin';
    } catch (e) {
      return false;
    }
  }

  /// Rate limiting simples (armazenar localmente)
  static final Map<String, List<DateTime>> _rateLimitMap = {};

  /// Verifica rate limiting para ações sensíveis
  static bool verificarRateLimit(
    String acao, {
    int limite = 5,
    Duration janela = const Duration(minutes: 1),
  }) {
    final agora = DateTime.now();
    final chave = '${FirebaseAuth.instance.currentUser?.uid}_$acao';

    _rateLimitMap[chave] ??= [];
    final tentativas = _rateLimitMap[chave]!;

    // Remove tentativas antigas
    tentativas.removeWhere((data) => agora.difference(data) > janela);

    if (tentativas.length >= limite) {
      return false; // Rate limit excedido
    }

    tentativas.add(agora);
    return true;
  }
}
