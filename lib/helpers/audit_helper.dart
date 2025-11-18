// audit_helper.dart - Sistema de logs de auditoria
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditHelper {
  static const String _collection = 'logs_auditoria';

  /// Registra uma ação de auditoria no sistema
  static Future<void> registrarAcao({
    required String acao,
    required String modulo,
    required Map<String, dynamic> detalhes,
    String? usuarioAfetado,
    String? observacoes,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Buscar dados do usuário atual
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};

      await FirebaseFirestore.instance.collection(_collection).add({
        'timestamp': Timestamp.now(),
        'acao': acao,
        'modulo': modulo,
        'usuario_executor': {
          'uid': user.uid,
          'nome': userData['nome'] ?? 'Usuário desconhecido',
          'funcao': userData['funcao'] ?? 'indefinida',
          'email': user.email,
        },
        'usuario_afetado': usuarioAfetado,
        'detalhes': detalhes,
        'observacoes': observacoes,
        'ip_address': 'N/A', // Não disponível no client
        'user_agent': 'Flutter App',
      });
    } catch (e) {
      // Log do erro sem falhar a operação principal
      print('Erro ao registrar auditoria: $e');
    }
  }

  /// Registra criação de usuário
  static Future<void> registrarCriacaoUsuario({
    required String uidCriado,
    required String nomeCriado,
    required String funcaoCriada,
    required List<String> permissoes,
  }) async {
    await registrarAcao(
      acao: 'USUARIO_CRIADO',
      modulo: 'GERENCIAMENTO_USUARIOS',
      usuarioAfetado: uidCriado,
      detalhes: {
        'nome_usuario': nomeCriado,
        'funcao': funcaoCriada,
        'permissoes': permissoes,
      },
    );
  }

  /// Registra edição de usuário
  static Future<void> registrarEdicaoUsuario({
    required String uidEditado,
    required Map<String, dynamic> dadosAnteriores,
    required Map<String, dynamic> dadosNovos,
  }) async {
    await registrarAcao(
      acao: 'USUARIO_EDITADO',
      modulo: 'GERENCIAMENTO_USUARIOS',
      usuarioAfetado: uidEditado,
      detalhes: {
        'dados_anteriores': dadosAnteriores,
        'dados_novos': dadosNovos,
        'campos_alterados': _identificarCamposAlterados(
          dadosAnteriores,
          dadosNovos,
        ),
      },
    );
  }

  /// Registra exclusão de usuário
  static Future<void> registrarExclusaoUsuario({
    required String uidExcluido,
    required Map<String, dynamic> dadosUsuario,
  }) async {
    await registrarAcao(
      acao: 'USUARIO_EXCLUIDO',
      modulo: 'GERENCIAMENTO_USUARIOS',
      usuarioAfetado: uidExcluido,
      detalhes: {'dados_usuario_excluido': dadosUsuario},
      observacoes: 'Usuário removido do Firestore, conta Auth permanece ativa',
    );
  }

  /// Registra tentativa de acesso negado
  static Future<void> registrarAcessoNegado({
    required String acao,
    required String motivo,
    Map<String, dynamic>? detalhes,
  }) async {
    await registrarAcao(
      acao: 'ACESSO_NEGADO',
      modulo: 'SEGURANCA',
      detalhes: {'acao_tentada': acao, 'motivo': motivo, ...?detalhes},
    );
  }

  /// Identifica campos que foram alterados
  static List<String> _identificarCamposAlterados(
    Map<String, dynamic> anterior,
    Map<String, dynamic> novo,
  ) {
    final camposAlterados = <String>[];

    for (final key in novo.keys) {
      if (anterior[key] != novo[key]) {
        camposAlterados.add(key);
      }
    }

    return camposAlterados;
  }

  /// Busca logs de auditoria com filtros
  static Query<Map<String, dynamic>> buscarLogs({
    String? modulo,
    String? acao,
    String? usuarioAfetado,
    DateTime? dataInicio,
    DateTime? dataFim,
    int limite = 100,
  }) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection(_collection)
        .orderBy('timestamp', descending: true);

    if (modulo != null) {
      query = query.where('modulo', isEqualTo: modulo);
    }

    if (acao != null) {
      query = query.where('acao', isEqualTo: acao);
    }

    if (usuarioAfetado != null) {
      query = query.where('usuario_afetado', isEqualTo: usuarioAfetado);
    }

    if (dataInicio != null) {
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(dataInicio),
      );
    }

    if (dataFim != null) {
      query = query.where(
        'timestamp',
        isLessThanOrEqualTo: Timestamp.fromDate(dataFim),
      );
    }

    return query.limit(limite);
  }
}
