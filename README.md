# viveiro_plus

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

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
