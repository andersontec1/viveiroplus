import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:viveiro_plus/helpers/parametros_analise_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/degrade_fundo.dart';
import '../widgets/responsive_center.dart';
import 'tela_analise_agua.dart' as analise;
import '../helpers/confirmation_helper.dart';
import 'tela_editar_registro_analise.dart';

class TelaListagemRegistros extends StatefulWidget {
  const TelaListagemRegistros({super.key});

  @override
  State<TelaListagemRegistros> createState() => _TelaListagemRegistrosState();
}

class _TelaListagemRegistrosState extends State<TelaListagemRegistros> {
  String? _tipoSelecionado;
  String? _codigoSelecionado;
  DateTime? _dataInicio;
  DateTime? _dataFim;
  Map<String, String> _viveiros = {};
  Map<String, String> _bercarios = {};
  String _funcaoUsuario = '';
  bool _carregado = false;
  Map<String, Map<String, double>> _faixas =
      ParametrosAnaliseHelper.getDefaultsAsDouble();

  @override
  void initState() {
    super.initState();
    _carregarTudo();
  }

  Future<void> _carregarTudo() async {
    await _carregarDestinos();
    await _carregarFuncaoUsuario();
    await _carregarParametros();
    setState(() => _carregado = true);
  }

  Future<void> _carregarParametros() async {
    final map = await ParametrosAnaliseHelper.carregarTodos();
    if (!mounted) return;
    setState(() => _faixas = map);
  }

  Future<void> _carregarFuncaoUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      setState(() {
        _funcaoUsuario = snap.data()?['funcao'] ?? '';
      });
    }
  }

  Future<void> _carregarDestinos() async {
    try {
      // Carregar viveiros
      final snapshotViveiros = await FirebaseFirestore.instance
          .collection('viveiros')
          .get();
      final viveiros = <String, String>{};
      for (final doc in snapshotViveiros.docs) {
        final data = doc.data();
        final codigo = data['codigo']?.toString() ?? '';
        final nome = data['nome']?.toString() ?? '';
        if (codigo.isNotEmpty && nome.isNotEmpty) {
          viveiros[codigo] = nome;
        }
      }

      // Carregar berçários
      final snapshotBercarios = await FirebaseFirestore.instance
          .collection('bercarios')
          .get();
      final bercarios = <String, String>{};
      for (final doc in snapshotBercarios.docs) {
        final data = doc.data();
        final codigo = data['codigo']?.toString() ?? '';
        final nome = data['nome']?.toString() ?? '';
        if (codigo.isNotEmpty && nome.isNotEmpty) {
          bercarios[codigo] = nome;
        }
      }

      setState(() {
        _viveiros = viveiros;
        _bercarios = bercarios;
      });

      print('DEBUG LISTAGEM: Viveiros carregados: $_viveiros');
      print('DEBUG LISTAGEM: Berçários carregados: $_bercarios');
    } catch (e) {
      print('DEBUG LISTAGEM: Erro ao carregar destinos: $e');
    }
  }

  Future<void> _selecionarData({required bool inicio}) async {
    final selecionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (selecionada != null) {
      setState(() {
        if (inicio) {
          _dataInicio = selecionada;
        } else {
          _dataFim = selecionada.add(const Duration(hours: 23, minutes: 59));
        }
      });
    }
  }

  Future<void> _confirmarExclusao(String id) async {
    // Usa o helper padrão de confirmação
    final confirmado = await ConfirmationHelper.showDoubleConfirmation(
      context: context,
      title: 'Excluir registro?',
      content: 'Você tem certeza que deseja excluir este registro de análise?',
      secondTitle: 'Confirma exclusão?',
      secondContent: 'Esta ação é irreversível. Deseja realmente excluir?',
      actionLabel: 'Excluir',
      actionColor: Colors.red,
    );

    if (!confirmado) return;

    try {
      // Mostra loading
      if (!mounted) return;
      ConfirmationHelper.showLoading(
        context: context,
        message: 'Excluindo registro...',
      );

      // Executa a exclusão
      await FirebaseFirestore.instance
          .collection('registros_diarios')
          .doc(id)
          .delete();

      if (!mounted) return;
      Navigator.pop(context); // Remove o loading

      // Mostra sucesso
      await ConfirmationHelper.showSuccess(
        context: context,
        title: 'Excluído com sucesso!',
        content: 'O registro de análise foi removido permanentemente.',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Remove o loading se ainda estiver ativo

      // Mostra erro
      await ConfirmationHelper.showError(
        context: context,
        title: 'Erro na exclusão',
        content: 'Não foi possível excluir o registro.',
        error: e.toString(),
      );
    }
  }

  void _mostrarDetalhes(Map<String, dynamic> data) {
    final dt = (data['dataHora'] as Timestamp).toDate();

    // Lista de parâmetros com suas configurações
    final parametrosConfig = [
      {
        'label': 'pH da Água',
        'campo': 'ph',
        'unidade': '',
        'ideal': _faixaIdealTexto('ph'),
      },
      {
        'label': 'Oxigênio Dissolvido',
        'campo': 'oxigenio',
        'unidade': 'mg/L',
        'ideal': _faixaIdealTexto('oxigenio'),
      },
      {
        'label': 'Temperatura (°C)',
        'campo': 'temperatura',
        'unidade': '°C',
        'ideal': _faixaIdealTexto('temperatura'),
      },
      {
        'label': 'Turbidez (NTU)',
        'campo': 'turbidez',
        'unidade': 'NTU',
        'ideal': _faixaIdealTexto('turbidez'),
      },
      {
        'label': 'Porcentagem de Saturação (%)',
        'campo': 'saturacao_percentual',
        'unidade': '%',
        'ideal': _faixaIdealTexto('saturacao_percentual'),
      },
      {
        'label': 'Salinidade (ppt)',
        'campo': 'salinidade',
        'unidade': 'ppt',
        'ideal': _faixaIdealTexto('salinidade'),
      },
      {
        'label': 'Cálcio (mg/L)',
        'campo': 'calcio',
        'unidade': 'mg/L',
        'ideal': _faixaIdealTexto('calcio'),
      },
      {
        'label': 'Nitrito (mg/L)',
        'campo': 'nitrito',
        'unidade': 'mg/L',
        'ideal': _faixaIdealTexto('nitrito'),
      },
      {
        'label': 'Amônia (mg/L)',
        'campo': 'amonia',
        'unidade': 'mg/L',
        'ideal': _faixaIdealTexto('amonia'),
      },
    ];

    Widget paramDetalhe(
      String label,
      String campo,
      String unidade, {
      String? ideal,
    }) {
      final valor = data[campo];
      final fora = _foraDoIdeal(campo, valor);
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: fora ? Colors.red.shade50 : Colors.teal.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (fora)
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 18,
              ),
            if (!fora)
              const Icon(Icons.check_circle, color: Colors.teal, size: 18),
            const SizedBox(width: 6),
            Text(
              '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: Text(
                valor.toString(),
                style: TextStyle(
                  color: fora ? Colors.red : Colors.teal.shade900,
                  fontWeight: fora ? FontWeight.bold : FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unidade.isNotEmpty) Text(' $unidade'),
            if (fora && ideal != null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  '(Ideal: $ideal)',
                  style: const TextStyle(color: Colors.teal, fontSize: 12),
                ),
              ),
          ],
        ),
      );
    }

    // Filtra apenas os parâmetros que foram preenchidos (não nulos e não vazios)
    final parametrosPreenchidos = parametrosConfig.where((param) {
      final valor = data[param['campo']];
      return valor != null &&
          valor.toString().isNotEmpty &&
          valor.toString() != '0' &&
          valor.toString() != '0.0';
    }).toList();

    final editadoPor = data['editadoPor'];
    final editadoEm = data['editadoEm'];
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: const EdgeInsets.all(0),
          constraints: const BoxConstraints(
            maxHeight: 600,
          ), // Limita a altura máxima
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFB2DFDB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: const Column(
                  children: [
                    Icon(Icons.analytics, color: Colors.teal, size: 38),
                    SizedBox(height: 6),
                    Text(
                      'Detalhes do Registro',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                // Permite que o conteúdo expand e seja scrollable
                child: SingleChildScrollView(
                  // Adiciona scroll quando necessário
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Destino: ${data['nome'] ?? '—'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Código: ${data['codigo'] ?? '—'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),

                      // Mostrar apenas os parâmetros que foram preenchidos
                      if (parametrosPreenchidos.isNotEmpty)
                        ...parametrosPreenchidos.map(
                          (param) => paramDetalhe(
                            param['label'] as String,
                            param['campo'] as String,
                            param['unidade'] as String,
                            ideal: param['ideal'],
                          ),
                        )
                      else
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.grey,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Nenhum parâmetro foi registrado nesta análise.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 6),
                      const Text(
                        'Observações:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        data['observacoes'] ?? '—',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.teal,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Data/Hora: ${DateFormat('dd/MM/yyyy HH:mm').format(dt)}',
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.teal,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Registrado por: ${data['registradoPor'] ?? '—'}',
                          ),
                        ],
                      ),
                      if (editadoPor != null &&
                          editadoPor.toString().isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.deepOrange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Editado por: $editadoPor',
                              style: const TextStyle(color: Colors.deepOrange),
                            ),
                            if (editadoEm != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  'em: '
                                  '${editadoEm is Timestamp ? DateFormat('dd/MM/yyyy HH:mm').format(editadoEm.toDate()) : editadoEm.toString()}',
                                  style: const TextStyle(
                                    color: Colors.deepOrange,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Fechar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editarRegistro(String docId, Map<String, dynamic> data) {
    if (!['admin', 'gerente', 'supervisor'].contains(_funcaoUsuario)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você não tem permissão para editar este registro.'),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaEditarRegistroAnalise(
          docId: docId,
          data: data,
          onSalvo: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registro atualizado com sucesso!')),
            );
          },
        ),
      ),
    );
  }

  bool _foraDoIdeal(String campo, dynamic valor) {
    if (valor == null) return false;
    final val = double.tryParse(valor.toString());
    if (val == null) return false;
    final faixa =
        _faixas[campo] ?? ParametrosAnaliseHelper.getDefaultsAsDouble()[campo];
    if (faixa == null) return false;
    return val < (faixa['min'] ?? double.negativeInfinity) ||
        val > (faixa['max'] ?? double.infinity);
  }

  String _faixaIdealTexto(String campo) {
    final faixa =
        _faixas[campo] ?? ParametrosAnaliseHelper.getDefaultsAsDouble()[campo];
    if (faixa == null) return '—';
    return '${faixa['min']} – ${faixa['max']}';
  }

  String _rotuloData(DateTime data) {
    final hoje = DateTime.now();
    final ontem = hoje.subtract(const Duration(days: 1));
    final dataBase = DateTime(data.year, data.month, data.day);
    final hojeBase = DateTime(hoje.year, hoje.month, hoje.day);
    final ontemBase = DateTime(ontem.year, ontem.month, ontem.day);

    if (dataBase == hojeBase) return 'Hoje';
    if (dataBase == ontemBase) return 'Ontem';
    return DateFormat("EEEE, d 'de' MMMM 'de' y", 'pt_BR').format(data);
  }

  @override
  Widget build(BuildContext context) {
    if (!_carregado) {
      return Scaffold(
        appBar: AppBar(title: const Text('Registros de Análise')),
        body: const DegradeFundo(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    Query registrosRef = FirebaseFirestore.instance.collection(
      'registros_diarios',
    );

    if (_tipoSelecionado != null) {
      registrosRef = registrosRef.where(
        'tipoDestino',
        isEqualTo: _tipoSelecionado,
      );
    }
    if (_codigoSelecionado != null) {
      registrosRef = registrosRef.where(
        'codigo',
        isEqualTo: _codigoSelecionado,
      );
    }
    if (_dataInicio != null) {
      registrosRef = registrosRef.where(
        'dataHora',
        isGreaterThanOrEqualTo: Timestamp.fromDate(_dataInicio!),
      );
    }
    if (_dataFim != null) {
      registrosRef = registrosRef.where(
        'dataHora',
        isLessThanOrEqualTo: Timestamp.fromDate(_dataFim!),
      );
    }

    registrosRef = registrosRef.orderBy('dataHora', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Análises de Água')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const analise.TelaAnaliseAgua()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova Análise'),
        backgroundColor: Colors.teal,
      ),
      body: DegradeFundo(
        child: StreamBuilder<QuerySnapshot>(
          stream: registrosRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return ResponsiveCenter(
                padding: EdgeInsets.zero,
                alignment: Alignment.topCenter,
                child: ListView(
                  children: [
                    // Cabeçalho sempre presente
                    const Padding(
                      padding: EdgeInsets.only(
                        top: 24,
                        left: 24,
                        right: 24,
                        bottom: 8,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics, size: 48, color: Colors.teal),
                          SizedBox(height: 8),
                          Text(
                            'Registros de Análise de Água',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Visualize e gerencie todos os registros de análise de água.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.teal,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // Legenda sempre presente
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Legenda do Sistema',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Explicação dos cards de análise
                          Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.blue.shade300,
                                  ),
                                ),
                                child: Icon(
                                  Icons.water_drop,
                                  size: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Cards azuis: Todos os parâmetros dentro da faixa ideal',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.orange,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.water_drop,
                                  size: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Cards laranja: Parâmetros fora da faixa ideal (atenção necessária)',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Explicação dos chips de parâmetros
                          const Text(
                            'Chips de Parâmetros:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),

                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildChipLegenda('pH: 7.2', false),
                              _buildChipLegenda('O₂: 4.1mg/L', true),
                              _buildChipLegenda('T°: 28.5°C', false),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                child: const Text(
                                  '...',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              _buildChipLegenda('Normal', false),
                              const SizedBox(width: 8),
                              const Text(
                                '=',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Dentro da faixa ideal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          Row(
                            children: [
                              _buildChipLegenda('Alerta', true),
                              const SizedBox(width: 8),
                              const Text(
                                '=',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Fora da faixa ideal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Filtros sempre visíveis
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _tipoSelecionado,
                            decoration: const InputDecoration(
                              labelText: 'Tipo de Destino',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.category),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: null,
                                child: Text('Todos'),
                              ),
                              DropdownMenuItem(
                                value: 'viveiro',
                                child: Text('Viveiro'),
                              ),
                              DropdownMenuItem(
                                value: 'bercario',
                                child: Text('Berçário'),
                              ),
                            ],
                            onChanged: (valor) => setState(() {
                              _tipoSelecionado = valor;
                              // Limpa o código selecionado quando muda o tipo
                              _codigoSelecionado = null;
                            }),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _codigoSelecionado,
                            decoration: InputDecoration(
                              labelText: 'Código do Local',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.location_on),
                              // Muda a aparência quando desabilitado
                              fillColor: _tipoSelecionado == null
                                  ? Colors.grey.shade100
                                  : null,
                              filled: _tipoSelecionado == null,
                            ),
                            // Só permite seleção se um tipo estiver escolhido
                            onChanged: _tipoSelecionado == null
                                ? null
                                : (valor) => setState(
                                    () => _codigoSelecionado = valor,
                                  ),
                            items: _tipoSelecionado == null
                                ? [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('Selecione primeiro o tipo'),
                                    ),
                                  ]
                                : [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('Todos'),
                                    ),
                                    // Mostra apenas os itens do tipo selecionado
                                    if (_tipoSelecionado == 'viveiro')
                                      ..._viveiros.entries.map(
                                        (e) => DropdownMenuItem(
                                          value: e.key,
                                          child: Text('${e.value} (${e.key})'),
                                        ),
                                      ),
                                    if (_tipoSelecionado == 'bercario')
                                      ..._bercarios.entries.map(
                                        (e) => DropdownMenuItem(
                                          value: e.key,
                                          child: Text('${e.value} (${e.key})'),
                                        ),
                                      ),
                                  ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final data = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          _dataInicio ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (data != null)
                                      setState(() => _dataInicio = data);
                                  },
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(
                                    _dataInicio == null
                                        ? 'Data Início'
                                        : DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(_dataInicio!),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final data = await showDatePicker(
                                      context: context,
                                      initialDate: _dataFim ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (data != null)
                                      setState(() => _dataFim = data);
                                  },
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(
                                    _dataFim == null
                                        ? 'Data Fim'
                                        : DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(_dataFim!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => setState(() {
                              _tipoSelecionado = null;
                              _codigoSelecionado = null;
                              _dataInicio = null;
                              _dataFim = null;
                            }),
                            icon: const Icon(Icons.clear),
                            label: const Text('Limpar Filtros'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Mensagem de nenhum resultado
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Nenhum registro encontrado',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tente ajustar os filtros acima ou adicionar novos registros',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Agrupa por data usando o rotulo bonito
            final registrosPorData = <String, List<QueryDocumentSnapshot>>{};
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final dt = (data['dataHora'] as Timestamp).toDate();
              final chave = _rotuloData(dt);
              registrosPorData.putIfAbsent(chave, () => []).add(doc);
            }

            return ResponsiveCenter(
              padding: EdgeInsets.zero,
              alignment: Alignment.topCenter,
              child: ListView(
                children: [
                  // Cabeçalho e filtros que vão subir junto com a lista
                  const Padding(
                    padding: EdgeInsets.only(
                      top: 24,
                      left: 24,
                      right: 24,
                      bottom: 8,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.analytics, size: 48, color: Colors.teal),
                        SizedBox(height: 8),
                        Text(
                          'Registros de Análise de Água',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Visualize e gerencie todos os registros de análise de água.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.teal,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Legenda do sistema de cores e alertas
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Legenda do Sistema',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Explicação dos cards de análise
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.shade300),
                              ),
                              child: Icon(
                                Icons.water_drop,
                                size: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Cards azuis: Todos os parâmetros dentro da faixa ideal',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.orange,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.water_drop,
                                size: 12,
                                color: Colors.orange.shade700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Cards laranja: Parâmetros fora da faixa ideal (atenção necessária)',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Explicação dos chips de parâmetros
                        const Text(
                          'Chips de Parâmetros:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),

                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildChipLegenda('pH: 7.2', false),
                            _buildChipLegenda('O₂: 4.1mg/L', true),
                            _buildChipLegenda('T°: 28.5°C', false),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: const Text(
                                '...',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        Row(
                          children: [
                            _buildChipLegenda('Normal', false),
                            const SizedBox(width: 8),
                            const Text(
                              '=',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Dentro da faixa ideal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        Row(
                          children: [
                            _buildChipLegenda('Alerta', true),
                            const SizedBox(width: 8),
                            const Text(
                              '=',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Fora da faixa ideal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Filtros
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _tipoSelecionado,
                          decoration: const InputDecoration(
                            labelText: 'Tipo',
                            prefixIcon: Icon(Icons.category),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Todos')),
                            DropdownMenuItem(
                              value: 'viveiro',
                              child: Text('Viveiro'),
                            ),
                            DropdownMenuItem(
                              value: 'bercario',
                              child: Text('Berçário'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _tipoSelecionado = value;
                              _codigoSelecionado = null;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _codigoSelecionado,
                          decoration: InputDecoration(
                            labelText: 'Filtrar por Código',
                            prefixIcon: const Icon(Icons.search),
                            border: const OutlineInputBorder(),
                            // Muda a aparência quando desabilitado
                            fillColor: _tipoSelecionado == null
                                ? Colors.grey.shade100
                                : null,
                            filled: _tipoSelecionado == null,
                          ),
                          // Só permite seleção se um tipo estiver escolhido
                          onChanged: _tipoSelecionado == null
                              ? null
                              : (value) =>
                                    setState(() => _codigoSelecionado = value),
                          items: _tipoSelecionado == null
                              ? [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Selecione primeiro o tipo'),
                                  ),
                                ]
                              : (() {
                                  List<DropdownMenuItem<String>> items = [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('Todos'),
                                    ),
                                  ];

                                  if (_tipoSelecionado == 'viveiro') {
                                    // Mostrar apenas viveiros
                                    final viveirosSorted =
                                        _viveiros.entries.toList()..sort(
                                          (a, b) => a.key.compareTo(b.key),
                                        );

                                    items.addAll(
                                      viveirosSorted
                                          .map(
                                            (e) => DropdownMenuItem<String>(
                                              value: e.key,
                                              child: Text(
                                                '${e.value} (${e.key})',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    );
                                  } else if (_tipoSelecionado == 'bercario') {
                                    // Mostrar apenas berçários
                                    final bercariosSorted =
                                        _bercarios.entries.toList()..sort(
                                          (a, b) => a.key.compareTo(b.key),
                                        );

                                    items.addAll(
                                      bercariosSorted
                                          .map(
                                            (e) => DropdownMenuItem<String>(
                                              value: e.key,
                                              child: Text(
                                                '${e.value} (${e.key})',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    );
                                  }

                                  return items;
                                })(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.date_range),
                                label: Text(
                                  _dataInicio == null
                                      ? 'Data início'
                                      : DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(_dataInicio!),
                                ),
                                onPressed: () => _selecionarData(inicio: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.event),
                                label: Text(
                                  _dataFim == null
                                      ? 'Data fim'
                                      : DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(_dataFim!),
                                ),
                                onPressed: () => _selecionarData(inicio: false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.filter_alt_off),
                          label: const Text('Limpar Filtros'),
                          onPressed: () {
                            setState(() {
                              _tipoSelecionado = null;
                              _codigoSelecionado = null;
                              _dataInicio = null;
                              _dataFim = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  // Lista de registros
                  ...registrosPorData.entries.expand((entry) {
                    return [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...entry.value.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final dt = (data['dataHora'] as Timestamp).toDate();
                        final destino = data['nome'] ?? data['codigo'] ?? '—';
                        final por = data['registradoPor'] ?? '—';

                        // Gerar abreviações dos parâmetros registrados
                        List<String> parametrosRegistrados = [];

                        if (data['ph'] != null &&
                            data['ph'].toString().isNotEmpty) {
                          parametrosRegistrados.add('pH: ${data['ph']}');
                        }
                        if (data['oxigenio'] != null &&
                            data['oxigenio'].toString().isNotEmpty) {
                          parametrosRegistrados.add(
                            'O₂: ${data['oxigenio']}mg/L',
                          );
                        }
                        if (data['temperatura'] != null &&
                            data['temperatura'].toString().isNotEmpty) {
                          parametrosRegistrados.add(
                            'T°: ${data['temperatura']}°C',
                          );
                        }
                        if (data['salinidade'] != null &&
                            data['salinidade'].toString().isNotEmpty) {
                          parametrosRegistrados.add(
                            'Sal: ${data['salinidade']}ppt',
                          );
                        }
                        if (data['turbidez'] != null &&
                            data['turbidez'].toString().isNotEmpty) {
                          parametrosRegistrados.add(
                            'Turb: ${data['turbidez']}NTU',
                          );
                        }
                        if (data['saturacao_percentual'] != null &&
                            data['saturacao_percentual']
                                .toString()
                                .isNotEmpty) {
                          parametrosRegistrados.add(
                            'Sat%: ${data['saturacao_percentual']}%',
                          );
                        }
                        if (data['calcio'] != null &&
                            data['calcio'].toString().isNotEmpty) {
                          parametrosRegistrados.add(
                            'Ca: ${data['calcio']}mg/L',
                          );
                        }
                        if (data['nitrito'] != null &&
                            data['nitrito'].toString().isNotEmpty) {
                          parametrosRegistrados.add(
                            'NO₂: ${data['nitrito']}mg/L',
                          );
                        }
                        if (data['amonia'] != null &&
                            data['amonia'].toString().isNotEmpty) {
                          parametrosRegistrados.add(
                            'NH₃: ${data['amonia']}mg/L',
                          );
                        }

                        // Verificar se há parâmetros fora do ideal
                        int parametrosForaIdeal = 0;
                        for (var param in [
                          'ph',
                          'oxigenio',
                          'temperatura',
                          'salinidade',
                          'turbidez',
                          'saturacao_percentual',
                          'calcio',
                          'nitrito',
                          'amonia',
                        ]) {
                          if (_foraDoIdeal(param, data[param])) {
                            parametrosForaIdeal++;
                          }
                        }

                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: parametrosForaIdeal > 0
                                ? const BorderSide(
                                    color: Colors.orange,
                                    width: 2,
                                  )
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _mostrarDetalhes(data),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.water_drop,
                                        color: parametrosForaIdeal > 0
                                            ? Colors.orange
                                            : Colors.blue,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              destino,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              DateFormat(
                                                'dd/MM/yyyy HH:mm',
                                              ).format(dt),
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              'Por: $por',
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (parametrosForaIdeal > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '$parametrosForaIdeal ⚠️',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'detalhes') {
                                            _mostrarDetalhes(data);
                                          } else if (value == 'excluir') {
                                            _confirmarExclusao(doc.id);
                                          } else if (value == 'editar') {
                                            _editarRegistro(doc.id, data);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'detalhes',
                                            child: ListTile(
                                              leading: Icon(Icons.info),
                                              title: Text('Detalhes'),
                                            ),
                                          ),
                                          if (_funcaoUsuario == 'admin' ||
                                              _funcaoUsuario == 'gerente')
                                            const PopupMenuItem(
                                              value: 'editar',
                                              child: ListTile(
                                                leading: Icon(Icons.edit),
                                                title: Text('Editar'),
                                              ),
                                            ),
                                          const PopupMenuItem(
                                            value: 'excluir',
                                            child: ListTile(
                                              leading: Icon(Icons.delete),
                                              title: Text('Excluir'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (parametrosRegistrados.isNotEmpty) ...[
                                    const Text(
                                      'Parâmetros registrados:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: parametrosRegistrados.take(6).map((
                                        parametro,
                                      ) {
                                        final parts = parametro.split(': ');
                                        final nome = parts[0];

                                        // Verificar se este parâmetro específico está fora do ideal
                                        String campo = '';
                                        switch (nome) {
                                          case 'pH':
                                            campo = 'ph';
                                            break;
                                          case 'O₂':
                                            campo = 'oxigenio';
                                            break;
                                          case 'T°':
                                            campo = 'temperatura';
                                            break;
                                          case 'Sal':
                                            campo = 'salinidade';
                                            break;
                                          case 'Turb':
                                            campo = 'turbidez';
                                            break;
                                          case 'Sat%':
                                            campo = 'saturacao_percentual';
                                            break;
                                          case 'Ca':
                                            campo = 'calcio';
                                            break;
                                          case 'NO₂':
                                            campo = 'nitrito';
                                            break;
                                          case 'NH₃':
                                            campo = 'amonia';
                                            break;
                                        }

                                        final foraIdeal = _foraDoIdeal(
                                          campo,
                                          data[campo],
                                        );

                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: foraIdeal
                                                ? Colors.orange.shade100
                                                : Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: foraIdeal
                                                  ? Colors.orange
                                                  : Colors.blue.shade200,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            parametro,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: foraIdeal
                                                  ? Colors.orange.shade800
                                                  : Colors.blue.shade800,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    if (parametrosRegistrados.length > 6)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '+${parametrosRegistrados.length - 6} parâmetros...',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                  ] else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Nenhum parâmetro registrado',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ];
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Método helper para criar chips de exemplo na legenda
  Widget _buildChipLegenda(String texto, bool foraIdeal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: foraIdeal ? Colors.orange.shade100 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: foraIdeal ? Colors.orange : Colors.blue.shade200,
          width: 1,
        ),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 10,
          color: foraIdeal ? Colors.orange.shade800 : Colors.blue.shade800,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
