import 'package:flutter/material.dart';

class ConfirmationHelper {
  /// Exibe um diálogo de confirmação dupla padrão do sistema
  /// 
  /// [context] - Contexto do widget
  /// [title] - Título da primeira confirmação (ex: "Excluir registro?")
  /// [content] - Conteúdo da primeira confirmação
  /// [secondTitle] - Título da segunda confirmação (padrão: "Confirma exclusão?")
  /// [secondContent] - Conteúdo da segunda confirmação (padrão: "Esta ação é irreversível...")
  /// [actionLabel] - Label do botão de ação (padrão: "Excluir")
  /// [actionColor] - Cor do botão de ação (padrão: Colors.red)
  /// [showId] - Se deve mostrar o ID nos dialogs para debug (padrão: false)
  /// [id] - ID do item para debug
  /// 
  /// Retorna [true] se o usuário confirmou, [false] caso contrário
  static Future<bool> showDoubleConfirmation({
    required BuildContext context,
    required String title,
    required String content,
    String? secondTitle,
    String? secondContent,
    String? actionLabel,
    Color? actionColor,
    bool showId = false,
    String? id,
  }) async {
    // Primeiro diálogo de confirmação
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE0B2),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange, size: 38),
                    const SizedBox(height: 6),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: Column(
                  children: [
                    Text(content, style: const TextStyle(fontSize: 16)),
                    if (showId && id != null) ...[
                      const SizedBox(height: 8),
                      Text('ID: $id', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Continuar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
  if (confirm1 != true) return false;

  // Evita usar o BuildContext se o widget original foi desmontado
  if (!context.mounted) return false;

    // Segundo diálogo de confirmação
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE0B2),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  children: [
                    Icon(Icons.delete_forever, color: actionColor ?? Colors.red, size: 38),
                    const SizedBox(height: 6),
                    Text(secondTitle ?? 'Confirma exclusão?', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: Column(
                  children: [
                    Text(secondContent ?? 'Esta ação é irreversível. Deseja realmente excluir?', style: const TextStyle(fontSize: 16)),
                    if (showId && id != null) ...[
                      const SizedBox(height: 8),
                      Text('ID: $id', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Não', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: actionColor ?? Colors.red),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(actionLabel ?? 'Excluir', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return confirm2 == true;
  }

  /// Exibe um diálogo de sucesso padrão após uma ação
  /// 
  /// [context] - Contexto do widget
  /// [title] - Título do sucesso (padrão: "Sucesso!")
  /// [content] - Conteúdo da mensagem (padrão: "Operação realizada com sucesso.")
  /// [icon] - Ícone a ser exibido (padrão: Icons.check_circle)
  /// [iconColor] - Cor do ícone (padrão: Colors.teal)
  /// [backgroundColor] - Cor de fundo do cabeçalho (padrão: Color(0xFFB2DFDB))
  static Future<void> showSuccess({
    required BuildContext context,
    String? title,
    String? content,
    IconData? icon,
    Color? iconColor,
    Color? backgroundColor,
  }) async {
    return showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: backgroundColor ?? const Color(0xFFB2DFDB),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  children: [
                    Icon(icon ?? Icons.check_circle, color: iconColor ?? Colors.teal, size: 38),
                    const SizedBox(height: 6),
                    Text(title ?? 'Sucesso!', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: Column(
                  children: [
                    Text(content ?? 'Operação realizada com sucesso.', style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Exibe um diálogo de erro padrão
  /// 
  /// [context] - Contexto do widget
  /// [title] - Título do erro (padrão: "Erro")
  /// [content] - Conteúdo da mensagem de erro
  /// [error] - Erro detalhado (opcional)
  /// [icon] - Ícone a ser exibido (padrão: Icons.error)
  /// [iconColor] - Cor do ícone (padrão: Colors.red)
  /// [backgroundColor] - Cor de fundo do cabeçalho (padrão: Color(0xFFFFCDD2))
  static Future<void> showError({
    required BuildContext context,
    required String content,
    String? title,
    String? error,
    IconData? icon,
    Color? iconColor,
    Color? backgroundColor,
  }) async {
    return showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: backgroundColor ?? const Color(0xFFFFCDD2),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  children: [
                    Icon(icon ?? Icons.error, color: iconColor ?? Colors.red, size: 38),
                    const SizedBox(height: 6),
                    Text(title ?? 'Erro', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: Column(
                  children: [
                    Text(content, style: const TextStyle(fontSize: 16)),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text('Detalhes: $error', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Fechar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Exibe um loading padrão durante operações
  /// 
  /// [context] - Contexto do widget
  /// [message] - Mensagem a ser exibida (padrão: "Processando...")
  static void showLoading({
    required BuildContext context,
    String? message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(message ?? 'Processando...'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
