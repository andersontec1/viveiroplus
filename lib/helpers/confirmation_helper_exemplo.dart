/*
 * EXEMPLO DE USO DO ConfirmationHelper
 * 
 * Este arquivo mostra como usar o helper padrão de confirmação
 * em diferentes cenários do sistema.
 */

import 'package:flutter/material.dart';
import '../helpers/confirmation_helper.dart';

class ExemploConfirmationHelper {
  
  // ==========================================
  // EXEMPLO 1: Confirmação de exclusão básica
  // ==========================================
  static Future<void> exemploExclusaoBasica(BuildContext context, String id) async {
    final confirmado = await ConfirmationHelper.showDoubleConfirmation(
      context: context,
      title: 'Excluir item?',
      content: 'Você tem certeza que deseja excluir este item?',
    );

    if (confirmado) {
      // Executar exclusão aqui
      print('Item $id excluído');
    }
  }

  // ==========================================
  // EXEMPLO 2: Confirmação personalizada
  // ==========================================
  static Future<void> exemploPersonalizado(BuildContext context) async {
    final confirmado = await ConfirmationHelper.showDoubleConfirmation(
      context: context,
      title: 'Arquivar projeto?',
      content: 'O projeto será movido para a área de arquivos.',
      secondTitle: 'Confirma arquivamento?',
      secondContent: 'Esta ação pode ser revertida posteriormente.',
      actionLabel: 'Arquivar',
      actionColor: Colors.orange,
    );

    if (confirmado) {
      // Executar arquivamento
    }
  }

  // ==========================================
  // EXEMPLO 3: Exclusão com loading e feedback
  // ==========================================
  static Future<void> exemploComLoading(BuildContext context, String id) async {
    final confirmado = await ConfirmationHelper.showDoubleConfirmation(
      context: context,
      title: 'Excluir usuário?',
      content: 'O usuário será removido permanentemente do sistema.',
      // showId: true, // Opcional: apenas para debug se necessário
      // id: id,
    );

    if (!confirmado) return;

    try {
      // Mostra loading
      ConfirmationHelper.showLoading(
        context: context,
        message: 'Removendo usuário...',
      );

      // Simula operação (substitua pela sua lógica)
      await Future.delayed(const Duration(seconds: 2));
      
      // Remove o loading
      Navigator.pop(context);
      
      // Mostra sucesso
      await ConfirmationHelper.showSuccess(
        context: context,
        title: 'Usuário removido!',
        content: 'O usuário foi removido com sucesso do sistema.',
      );
    } catch (e) {
      // Remove o loading
      Navigator.pop(context);
      
      // Mostra erro
      await ConfirmationHelper.showError(
        context: context,
        title: 'Erro ao remover usuário',
        content: 'Não foi possível remover o usuário.',
        error: e.toString(),
      );
    }
  }

  // ==========================================
  // EXEMPLO 4: Diferentes tipos de dialogs
  // ==========================================
  static Future<void> exemploDialogs(BuildContext context) async {
    // Dialog de sucesso
    await ConfirmationHelper.showSuccess(
      context: context,
      title: 'Operação concluída!',
      content: 'Os dados foram salvos com sucesso.',
    );

    // Dialog de erro
    await ConfirmationHelper.showError(
      context: context,
      title: 'Falha na conexão',
      content: 'Não foi possível conectar ao servidor.',
      error: 'Timeout de 30 segundos excedido',
    );

    // Loading
    ConfirmationHelper.showLoading(
      context: context,
      message: 'Sincronizando dados...',
    );
    
    // Simula operação
    await Future.delayed(const Duration(seconds: 3));
    
    // Remove o loading
    Navigator.pop(context);
  }

  // ==========================================
  // EXEMPLO 5: Integração com operações do Firebase
  // ==========================================
  static Future<void> exemploFirebase(BuildContext context, String docId) async {
    final confirmado = await ConfirmationHelper.showDoubleConfirmation(
      context: context,
      title: 'Excluir registro?',
      content: 'Este registro será removido permanentemente.',
      // showId: true, // Opcional: apenas para debug
      // id: docId,
    );

    if (!confirmado) return;

    try {
      ConfirmationHelper.showLoading(
        context: context,
        message: 'Excluindo registro...',
      );

      // Sua operação Firebase aqui
      // await FirebaseFirestore.instance.collection('sua_colecao').doc(docId).delete();
      
      Navigator.pop(context); // Remove loading
      
      await ConfirmationHelper.showSuccess(
        context: context,
        title: 'Registro excluído!',
        content: 'O registro foi removido com sucesso.',
      );
    } catch (e) {
      Navigator.pop(context); // Remove loading
      
      await ConfirmationHelper.showError(
        context: context,
        title: 'Erro na exclusão',
        content: 'Não foi possível excluir o registro.',
        error: e.toString(),
      );
    }
  }
}

/*
 * VANTAGENS DO ConfirmationHelper:
 * 
 * ✅ Padrão visual consistente em todo o app
 * ✅ Dupla confirmação para segurança
 * ✅ Loading e feedback automáticos
 * ✅ Tratamento de erros padronizado
 * ✅ Fácil personalização
 * ✅ Debug opcional com IDs
 * ✅ Reutilizável em qualquer tela
 * ✅ Manutenção centralizada
 */
