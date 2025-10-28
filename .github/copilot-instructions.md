# Instruções para o GitHub Copilot - Viveiro+

## Visão Geral do Projeto

O **Viveiro+** é um sistema de gestão para aquicultura (criação de camarões) desenvolvido em Flutter com Firebase. O sistema permite monitoramento de viveiros, berçários, análises de água, controle de ração, gestão de funcionários com diferentes níveis de acesso, e controle completo de ciclos produtivos incluindo biomassa, despesca e transferências.

### Tecnologias Principais
- **Flutter 3.8+**: Framework multiplataforma (Web, Mobile)
- **Firebase**: Backend completo (Auth, Firestore, Hosting)
- **Cloud Firestore**: Banco de dados NoSQL em tempo real
- **Firebase Hosting**: Deploy web em `viveiroplusweb.web.app`
- **Provider**: Gerenciamento de estado global (usuário logado)
- **Material Design 3**: Interface moderna e responsiva
- **fl_chart**: Gráficos e visualizações de dados

## Estrutura do Projeto

### Arquitetura de Pastas
```
lib/
├── main.dart                    # App principal com configuração Firebase e roteamento
├── firebase_options.dart        # Configurações Firebase auto-geradas
├── helpers/                     # Utilitários e helpers
│   ├── auth_helper.dart        # Autenticação e controle de usuário
│   ├── audit_helper.dart       # Logs de auditoria e segurança
│   ├── security_helper.dart    # Validações de segurança e hierarquia
│   └── confirmation_helper.dart # Diálogos de confirmação padronizados
├── screens/                     # Telas da aplicação
│   ├── menu_principal.dart     # Dashboard principal com sistema de permissões
│   ├── tela_login.dart        # Login com Firebase Auth
│   ├── tela_*_dashboard.dart  # Dashboards de controle (despesca, etc)
│   ├── tela_*_listagem.dart   # Telas de listagem com filtros
│   ├── tela_detalhes_*.dart   # Telas de detalhes com StreamBuilder
│   └── tela_gerenciar_usuarios.dart # Gestão completa de usuários e permissões
└── widgets/                     # Componentes reutilizáveis
    ├── analise_agua_form.dart  # **COMPONENTE CENTRAL** para análises
    ├── app_scaffold.dart       # Scaffold padronizado com FloatingActionButton
    └── degrade_fundo.dart      # Background com gradiente
```

### Banco de Dados (Firestore)

#### Coleções Principais
- **`usuarios`**: Dados dos funcionários (nome, função, permissões)
- **`viveiros`**: Tanques de engorda (código, nome, área, status)
- **`bercarios`**: Tanques de pós-larvas (código, nome, capacidade)
- **`registros_diarios`**: Análises de água (parâmetros físicos/químicos)
- **`racao`**: Controle de alimentação e consumo
- **`insumos`**: Estoque e consumo de materiais
- **`ciclos`**: Ciclos produtivos por viveiro/berçário
- **`despescas`**: Controle de colheita com estrutura multi-dias
- **`biomassa`**: Cálculos de peso e sobrevivência
- **`povoamentos`**: Registro de estocagem de pós-larvas
- **`transferencias`**: Movimentação entre viveiros

#### Estrutura de Documentos Críticos
```typescript
// ciclos (gestão produtiva)
{
  codigo: string,              // Código do viveiro/berçário
  nome: string,               // Nome do local
  dataInicio: Timestamp,      // Início do ciclo
  encerrado: boolean,         // Status do ciclo
  quantidadeEstocada: number, // Quantidade inicial
  pesoInicial: number,        // Peso médio inicial
  previsaoEncerramento?: Timestamp
}

// despescas (estrutura multi-dias)
{
  codigo: string,
  nome: string,
  statusDespesca: "planejada" | "em_andamento" | "finalizada",
  dias: [                     // Array de dias de despesca
    {
      data: "yyyy-MM-dd",
      basquetas: [
        { numero: number, peso: number, responsavel: string }
      ],
      pesoTotal: number,
      totalBasquetas: number
    }
  ],
  pesoTotal: number,          // Peso total de todos os dias
  basquetasTotal: number,     // Total de basquetas
  dataCriacao: Timestamp,     // Campo usado para ordenação
  criadoPor: string
}
```

## Sistema de Permissões e Hierarquia

### Funções de Usuário (hierárquicas)
```dart
// Ordem hierárquica crescente
'registrador' -> 'arraçoador' -> 'supervisor' -> 'gerente' -> 'admin'
```

### Padrão de Verificação de Permissões
```dart
// No menu principal
bool temPermissao(String chave) {
  if (_permissoes.isNotEmpty) {
    return _permissoes.contains(chave);  // Usa permissões específicas
  } else if (_funcaoUsuario != null) {
    final permissoesFuncao = permissoesPorFuncao[_funcaoUsuario!] ?? [];
    return permissoesFuncao.contains(chave) || _funcaoUsuario == 'admin';
  }
  return false;
}
```

### Validações de Segurança
```dart
// Verificar hierarquia antes de operações sensíveis
final podePorHierarquia = SecurityHelper.funcaoSuperior(currentUserFuncao, targetUserFuncao);
if (!podePorHierarquia) {
  await AuditHelper.registrarAcessoNegado(/*...*/);
  return;
}
```

## Padrões Arquiteturais Críticos

### 1. Navegação e Roteamento
```dart
// main.dart - Rotas com fade transition
Route<dynamic> _onGenerateRouteWithFade(RouteSettings settings) {
  switch (settings.name) {
    case '/menu':
      return _buildFadeRoute(FutureBuilder(
        future: _carregarFuncaoUsuario(),
        builder: (context, snapshot) => MenuPrincipal(resumoExpandido: expandirResumo),
      ));
  }
}
```

### 2. Padrão de Telas de Listagem
```dart
// Estrutura comum: Filtros + StreamBuilder + FloatingActionButton
AppScaffold(
  title: 'Nome da Tela',
  floatingActionButton: FloatingActionButton.extended(
    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TelaNovo())),
    icon: const Icon(Icons.add),
    label: const Text('Novo Registro'),
  ),
  body: Column(
    children: [
      // Seção de filtros sempre no topo
      _buildFiltros(),
      // StreamBuilder para dados em tempo real
      StreamBuilder<QuerySnapshot>(/*...*/),
    ],
  ),
)
```

### 3. Operações Firebase com Fallback
```dart
// Padrão para consultas complexas com fallback
Query _montarConsultaComFallback() {
  Query query = FirebaseFirestore.instance.collection('collection');
  
  try {
    if (filtro != null) {
      query = query.where('campo', isEqualTo: filtro);
    }
    return query.orderBy('timestamp', descending: true);
  } catch (e) {
    // Fallback sem orderBy se houver erro de índice
    return FirebaseFirestore.instance.collection('collection');
  }
}
```

### 4. Validação de Timestamp Segura
```dart
// Sempre proteger casts de Timestamp
final dataCriacao = despesca['dataCriacao'] as Timestamp?;
final dataFinal = dataCriacao?.toDate() ?? DateTime.now();
```

## Funcionalidades Específicas

### 1. Sistema de Despesca Multi-Dias
- **Workflow**: TelaSelecaoViveiroDespesca → TelaDespesca → TelaDespescaDashboard
- **Dados**: Estrutura em array `dias` com cálculos automáticos de totais
- **Busca**: Por número de basqueta com filtro em tempo real

### 2. Gestão de Ciclos Produtivos
- **Validação**: Um ciclo ativo por viveiro/berçário
- **Relacionamentos**: Ciclos → Povoamentos → Transferências → Biomassa
- **Status**: `encerrado: false` para ciclos ativos

### 3. Sistema de Auditoria
```dart
// Sempre registrar ações sensíveis
await AuditHelper.registrarAcao(
  acao: 'CRIAR_USUARIO',
  modulo: 'GERENCIAMENTO_USUARIOS',
  detalhes: {'funcao_criada': novaFuncao},
);
```

## Comandos de Desenvolvimento

### Build e Deploy
```bash
# Web local
flutter run -d chrome --web-port 3000

# APK produção
flutter build apk

# Deploy Firebase
firebase deploy --only hosting
```

### Correções Comuns
```bash
# Limpar build cache
flutter clean && flutter pub get

# Hot reload manual
r (no terminal do flutter run)

# Atualizar dependências
flutter pub upgrade --major-versions
```

## Debugging e Troubleshooting

### 1. Erros Comuns de Timestamp
- **Problema**: `type 'Null' is not a subtype of type 'Timestamp'`
- **Solução**: Usar cast seguro `as Timestamp?` e null-coalescing

### 2. Problemas de Índice Firestore
- **Problema**: Consultas falhando por falta de índice composto
- **Solução**: Implementar fallback ou criar índices via console

### 3. Estado Perdido em Formulários
- **Problema**: Dados perdidos ao navegar
- **Solução**: Usar TextEditingController persistente ou salvar imediatamente

## Convenções de Código

### 1. Nomenclatura de Arquivos
- `tela_*.dart`: Telas principais
- `*_dashboard.dart`: Telas de controle/overview
- `*_listagem.dart`: Telas de listagem com filtros
- `detalhes_*.dart`: Telas de visualização detalhada

### 2. Padrão de Debug
```dart
print('DEBUG [MODULO]: Mensagem informativa');
debugPrint('Estado atual: $_dados');
```

### 3. Tratamento de Erros
```dart
try {
  // Operação Firebase
} catch (e) {
  print('Erro ao [ação]: $e');
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Erro: ${e.toString()}')),
    );
  }
}
```

---

**Nota**: Este sistema é específico para aquicultura com foco em ciclos produtivos completos. Sempre considere o fluxo: Povoamento → Análises → Alimentação → Biomassa → Despesca → Encerramento.
