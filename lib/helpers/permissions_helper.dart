// permissions_helper.dart
// Centraliza chaves de permissões, rótulos e presets por função.
// Objetivo: eliminar duplicações e inconsistências entre telas.

class PermissionsHelper {
  // Funções suportadas (case-sensitive e com acentuação conforme já usado no app)
  static const List<String> roles = [
    'fornecedor',
    'registrador',
    'arraçoador',
    'supervisor',
    'gerente',
    'admin',
  ];

  // Aliases para manter compatibilidade com chaves antigas
  // key: alias antigo -> value: chave canônica
  static const Map<String, String> _aliases = {
    'visualizar_relatorios': 'relatorios',
    'registrar_racao': 'registro_racao',
    'registrar_analises': 'analise_agua',
    'visualizar_dados': 'registros_analise',
    'visualizar_estoque': 'estoque_insumos',
    'gerenciar_estoque': 'estoque_insumos',
  };

  // Rótulos amigáveis para cada permissão
  static const Map<String, String> labels = {
    'analise_agua': 'Análise da água',
    'registros_analise': 'Registros de análise',
    'parametrizacao_agua': 'Parametrização (água)',
    'registro_racao': 'Registro de ração',
    'historico_racao': 'Histórico de ração',
    'pontos_entrega': 'Pontos de entrega',
    'listar_bercarios': 'Listar berçários',
    'listar_viveiros': 'Listar viveiros',
    'relatorios': 'Relatórios (Água)',
    'editar_viveiro': 'Editar viveiro',
    'cadastro_viveiro': 'Cadastrar viveiro',
    'gerenciar_usuarios': 'Gerenciar usuários',
    'estoque_insumos': 'Estoque de insumos',
    'registrar_entrega_racao': 'Registrar entrega de ração',
    'ver_estoque_racao': 'Ver estoque de ração',
    'ciclos_viveiro': 'Ciclos por viveiro',
    'biomassa': 'Biomassa',
    'despesca': 'Despesca',
    'painel_web': 'Painel web',
    'insumos_hub': 'Insumos (hub)',
  };

  // Categorias para organizar as permissões na UI
  // A ordem das chaves abaixo define a ordem de exibição das categorias.
  static const Map<String, List<String>> categories = {
    'Análises de Água': [
      'analise_agua',
      'registros_analise',
      'parametrizacao_agua',
      'relatorios',
    ],
    'Rações': [
      'registro_racao',
      'historico_racao',
      'registrar_entrega_racao',
      'ver_estoque_racao',
      'pontos_entrega',
    ],
    'Viveiros e Berçários': [
      'listar_viveiros',
      'listar_bercarios',
      'editar_viveiro',
      'cadastro_viveiro',
    ],
    'Ciclos e Biomassa': ['ciclos_viveiro', 'biomassa'],
    'Despesca': ['despesca'],
    'Insumos/Suprimentos': ['estoque_insumos', 'insumos_hub'],
    'Relatórios/Indicadores': ['painel_web'],
    'Usuários e Segurança': ['gerenciar_usuarios'],
  };

  // Presets por função (chaves canônicas)
  static const Map<String, List<String>> roleDefaults = {
    'fornecedor': ['ver_estoque_racao', 'registrar_entrega_racao'],
    'arraçoador': [
      'registro_racao',
      'historico_racao',
      'listar_bercarios',
      'listar_viveiros',
      'pontos_entrega',
    ],
    'registrador': [
      'analise_agua',
      'registros_analise',
      'listar_bercarios',
      'listar_viveiros',
    ],
    'supervisor': [
      'analise_agua',
      'registros_analise',
      'registro_racao',
      'historico_racao',
      'listar_bercarios',
      'listar_viveiros',
      'estoque_insumos',
      'pontos_entrega',
      'ciclos_viveiro',
      'biomassa',
      'despesca',
    ],
    'gerente': [
      'analise_agua',
      'registros_analise',
      'parametrizacao_agua',
      'registro_racao',
      'historico_racao',
      'listar_bercarios',
      'listar_viveiros',
      'relatorios',
      'editar_viveiro',
      'cadastro_viveiro',
      'estoque_insumos',
      'gerenciar_usuarios', // acesso básico
      'pontos_entrega',
      'ciclos_viveiro',
      'biomassa',
      'despesca',
      'painel_web',
      'insumos_hub',
    ],
    'admin': [
      'analise_agua',
      'registros_analise',
      'parametrizacao_agua',
      'registro_racao',
      'historico_racao',
      'listar_bercarios',
      'listar_viveiros',
      'relatorios',
      'editar_viveiro',
      'cadastro_viveiro',
      'gerenciar_usuarios',
      'estoque_insumos',
      'registrar_entrega_racao',
      'ver_estoque_racao',
      'pontos_entrega',
      'ciclos_viveiro',
      'biomassa',
      'despesca',
      'painel_web',
      'insumos_hub',
    ],
  };

  // Retorna todas as permissões canônicas conhecidas
  static List<String> allKeys() {
    final set = <String>{};
    roleDefaults.values.forEach(set.addAll);
    set.addAll(labels.keys);
    return set.toList()..sort();
  }

  // Devolve as permissões agrupadas por categoria, mantendo a ordem definida em [categories].
  // Quaisquer chaves não mapeadas em categorias serão adicionadas ao final em "Outros".
  static Map<String, List<String>> categorizedKeys({List<String>? only}) {
    final known = only == null ? allKeys() : only;
    final Map<String, List<String>> result = {};

    // Preenche categorias conhecidas, filtrando por [known]
    for (final entry in categories.entries) {
      final filtered = entry.value.where((k) => known.contains(k)).toList();
      if (filtered.isNotEmpty) {
        result[entry.key] = filtered;
      }
    }

    // Quais chaves ficaram de fora?
    final categorized = categories.values.expand((e) => e).toSet();
    final outros = known.where((k) => !categorized.contains(k)).toList()
      ..sort();
    if (outros.isNotEmpty) {
      result['Outros'] = outros;
    }

    return result;
  }

  // Converte uma chave possivelmente alias para a chave canônica
  static String toCanonical(String key) => _aliases[key] ?? key;

  // Normaliza uma lista de permissões (remove nulos/duplicatas e aplica aliases)
  static List<String> normalize(dynamic rawList) {
    if (rawList is! List) return const [];
    final set = <String>{};
    for (final e in rawList) {
      if (e == null) continue;
      final k = toCanonical(e.toString());
      set.add(k);
    }
    return set.toList();
  }

  // Obtém permissões padrão pela função (sempre chaves canônicas)
  static List<String> forRole(String? role) {
    if (role == null) return const [];
    return List<String>.from(roleDefaults[role] ?? const []);
  }

  // Verifica se há permissão considerando aliases
  static bool contains(List<String> canonicalPerms, String key) {
    final k = toCanonical(key);
    if (canonicalPerms.contains(k)) return true;
    // fallback: alguns lugares podem estar consultando pelo alias antigo
    // então verificamos se o alias existe e está na lista
    if (_aliases.containsKey(key)) {
      return canonicalPerms.contains(_aliases[key]);
    }
    return false;
  }
}
