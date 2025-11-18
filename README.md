# Viveiro+

Sistema de gestão para aquicultura (camarões) em Flutter + Firebase. Inclui monitoramento de viveiros/berçários, análises de água, controle de ração com FEFO e rastreabilidade de lotes, ciclos produtivos, despesca multi-dias e relatórios.

Principais tecnologias: Flutter 3.x, Firebase (Auth, Firestore, Hosting), Provider, Material 3, fl_chart.

URL de produção (web): https://viveiroplusweb.web.app

---

## Mudanças recentes

- UI: Removido o selo “LEGADO” de registros de ração (a compatibilidade com registros antigos sem vínculo de lote permanece nos helpers e fluxos de backfill, apenas não é mais exibido visualmente).
- Ração: Validade do lote e distribuição por ponto de entrega são obrigatórias em entradas e lançamentos (FEFO/estorno aplicados automaticamente).
- Ciclos: Tela revisada para padrão visual da análise, com leituras seguras de campos legados e filtros melhorados.
- Entrada de Insumo (UX): Para o insumo do tipo Ração o campo “Local/Armazenamento” foi ocultado, evitando redundância com a "Distribuição por ponto de entrega" (que passa a definir o armazenamento). Para outros insumos, o campo permanece disponível.
 - Análise de Água: Parametrização de alertas (min/máx) por parâmetro disponível diretamente na tela. Os limites são persistidos em Firestore (`parametros_analise_agua`) e usados tanto no formulário quanto na listagem e detalhamento.

---

## Padrão visual (base: Análise de Água)

As novas telas seguem um padrão consistente para manter legibilidade, responsividade e minimizar erros:

- Estrutura: `AppScaffold` + `DegradeFundo` + conteúdo em `ListView`/`Column`.
- Telas de listagem: Filtros no topo + `StreamBuilder` para dados em tempo real + `FloatingActionButton` para “Novo”.
- Firestore resiliente: consultas com fallback (tente `orderBy`/filtros e, em caso de erro de índice, recupere sem ordenação/índice) e casts seguros de `Timestamp` (`as Timestamp?` + `?.toDate()` + valor padrão).
- Auditoria: Ações sensíveis registradas via `AuditHelper` (criação/edição/remoção, alterações de permissões etc.).
- Ração/Estoque (FEFO): Lotes ordenados por validade; distribuição por ponto presente nos fluxos; preferências por ponto integradas ao consumo quando aplicável.

### Parametrização de Análise de Água

- Onde editar: na tela “Análise da Água”, botão “Parametrizar alertas”.
- Como funciona: edite os limites mínimo e máximo de cada parâmetro; os valores são salvos em `parametros_analise_agua` (um doc por parâmetro) e aplicados em todas as telas (formulário, listagem e diálogo de detalhes).
- Fallback: se não houver configuração, os valores padrão são usados.

Observações específicas:

- Entrada de Insumo (Ração):
	- Campo “Local/Armazenamento” oculto e substituído por nota explicativa.
	- A distribuição por ponto de entrega é obrigatória e deve somar 100% da quantidade.
	- O armazenamento final é derivado dos pontos selecionados.
- Demais insumos: “Local/Armazenamento” permanece como campo opcional.

## Proteções e regras de segurança

- Permissões: Exclusão de registros de ração é restrita a perfis administrativos (verificação via `SecurityHelper.temFuncaoAdministrativa()`). Cada exclusão registra auditoria (`AuditHelper`).
- Integridade de Estoque: Em exclusões/edições, o estoque é estornado/reaplicado automaticamente (FEFO) incluindo aditivos vinculados.
- Legados: Registros antigos sem lote continuam funcionais (consulta/estorno), porém sem destaque visual.
- Preferências de Deploy: Ative proteção de branch no GitHub para o branch `viveiroplus` (recomendado):
	- Exigir PRs com ao menos 1 review;
	- Bloquear push direto;
	- Checagens de CI (build/lint) obrigatórias quando configuradas;
	- Impedir merge com histórico fora de data.

## Índices do Firestore

Para que as consultas de ração e estoque funcionem sem erros de índice, este projeto inclui um arquivo `firestore.indexes.json` com os índices compostos necessários. Ele já está referenciado em `firebase.json`.

Como publicar/atualizar os índices (Windows PowerShell):

1. Faça login no Firebase CLI e selecione o projeto correto.
2. Publique apenas os índices do Firestore.

Comandos (opcional):

```
# Login (se necessário)
firebase login

# Verificar projeto atual
firebase use

# Publicar apenas os índices do Firestore
firebase deploy --only firestore:indexes
```

Observação: se você alterar consultas que combinem múltiplos filtros com ordenação/intervalo, pode ser necessário adicionar novos índices. Atualize o `firestore.indexes.json` e execute o deploy acima.

---

## Build e Deploy Web (resumo)

1) Build web otimizado (release): `flutter build web --release`
2) Deploy via Firebase Hosting (CLI) ou upload do ZIP via Console.
3) Headers de cache estão definidos em `firebase.json` (anti-cache para `index.html` e service worker; cache longo para assets imutáveis).

Se o login da CLI falhar no PowerShell, use os binários `.cmd` (ex.: `firebase.cmd login`) ou realize o upload via Console do Firebase.
