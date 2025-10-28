import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import 'detalhes_insumo_dialog.dart';

class TelaInsumos extends StatefulWidget {
  const TelaInsumos({super.key});

  @override
  State<TelaInsumos> createState() => _TelaInsumosState();
}

class _TelaInsumosState extends State<TelaInsumos> {
  final _formKey = GlobalKey<FormState>();
  bool _mostrarFormulario = false;
  final _nomeController = TextEditingController();
  final _categoriaController = TextEditingController();
  final _marcaController = TextEditingController();
  final _codigoBarrasController = TextEditingController();
  final _observacoesController = TextEditingController();
  final _unidadeController = TextEditingController();
  final _fornecedorController = TextEditingController();
  final _loteController =
      TextEditingController(); // oculto para tipos com controle por lote
  final _quantidadeInicialController = TextEditingController();
  final _nivelMinimoController = TextEditingController();
  DateTime? _validade; // usado apenas para insumos não-loteados
  final List<String> _unidades = [
    'kg',
    'g',
    'L',
    'mL',
    'saco',
    'un',
    'caixa',
    'outro',
  ];
  String _tipoSelecionado = 'Probiótico';
  String? _idEditando;
  final String _funcaoUsuario = '';

  final List<String> _tiposInsumo = [
    'Probiótico',
    'Ração',
    'Suplemento',
    'Outro',
  ];

  @override
  void initState() {
    super.initState();
    _carregarFuncaoUsuario();
  }

  Future<void> _carregarFuncaoUsuario() async {
    // Ajuste para buscar função do usuário logado
    // (pode ser adaptado conforme seu controle de autenticação)
    // Exemplo:
    // final user = FirebaseAuth.instance.currentUser;
    // if (user != null) {
    //   final snap = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
    //   setState(() {
    //     _funcaoUsuario = snap.data()?['funcao'] ?? '';
    //   });
    // }
  }

  Future<bool> _nomeDuplicado(String nome) async {
    final query = await FirebaseFirestore.instance
        .collection('insumos')
        .where('nome', isEqualTo: nome.trim())
        .get();
    if (_idEditando != null) {
      // Se está editando, ignora o próprio registro
      return query.docs.any((doc) => doc.id != _idEditando);
    }
    return query.docs.isNotEmpty;
  }

  Future<void> _salvarInsumo() async {
    if (!_formKey.currentState!.validate()) return;
    if (await _nomeDuplicado(_nomeController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Já existe um insumo com este nome!')),
      );
      return;
    }
    final bool isRacao = _tipoSelecionado == 'Ração';
    final quantidadeInicial =
        double.tryParse(
          _quantidadeInicialController.text.replaceAll(',', '.'),
        ) ??
        0;
    final dados = <String, dynamic>{
      'tipo': _tipoSelecionado,
      'nome': _nomeController.text.trim(),
      'categoria': _categoriaController.text.trim(),
      'marca': _marcaController.text.trim(),
      'codigo_barras': _codigoBarrasController.text.trim(),
      'observacoes': _observacoesController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'unidade': _unidadeController.text.trim(),
      'fornecedor': _fornecedorController.text.trim(),
      'nivel_minimo':
          double.tryParse(_nivelMinimoController.text.replaceAll(',', '.')) ??
          5,
    };
    if (isRacao) {
      // Controle de validade e lote via tela de Entrada de Insumo (lotes)
      dados['quantidade_inicial'] = 0;
      dados['estoque'] = 0;
    } else {
      dados['lote'] = _loteController.text.trim();
      dados['validade'] = _validade != null
          ? Timestamp.fromDate(_validade!)
          : null;
      dados['quantidade_inicial'] = quantidadeInicial;
      dados['estoque'] = quantidadeInicial;
    }
    final col = FirebaseFirestore.instance.collection('insumos');
    if (_idEditando == null) {
      await col.add(dados);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insumo cadastrado com sucesso!')),
      );
    } else {
      await col.doc(_idEditando).update(dados);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insumo atualizado com sucesso!')),
      );
    }
    _limparCampos();
  }

  void _limparCampos() {
    setState(() {
      _idEditando = null;
      _nomeController.clear();
      _categoriaController.clear();
      _marcaController.clear();
      _codigoBarrasController.clear();
      _observacoesController.clear();
      _tipoSelecionado = 'Probiótico';
      _unidadeController.clear();
      _fornecedorController.clear();
      _loteController.clear();
      _quantidadeInicialController.clear();
      _nivelMinimoController.clear();
      _validade = null;
      _mostrarFormulario = false;
    });
  }

  void _mostrarDetalhesInsumo(Map<String, dynamic> data, String docId) {
    showDialog(
      context: context,
      builder: (_) => DetalhesInsumoDialog(
        data: data,
        podeEditar: ['admin', 'gerente', 'supervisor'].contains(_funcaoUsuario),
        onEditar: () {
          Navigator.pop(context);
          _carregarParaEdicaoDocId(docId, data);
        },
        onExcluir: () async {
          Navigator.pop(context);
          await _excluirInsumo(docId);
        },
      ),
    );
  }

  void _carregarParaEdicaoDocId(String docId, Map<String, dynamic> data) {
    setState(() {
      _idEditando = docId;
      _tipoSelecionado = data['tipo'];
      _nomeController.text = data['nome'];
      _categoriaController.text = data['categoria'] ?? '';
      _marcaController.text = data['marca'] ?? '';
      _codigoBarrasController.text = data['codigo_barras'] ?? '';
      _observacoesController.text = data['observacoes'] ?? '';
      _unidadeController.text = data['unidade'] ?? '';
      _fornecedorController.text = data['fornecedor'] ?? '';
      _loteController.text = data['lote'] ?? '';
      _quantidadeInicialController.text =
          data['quantidade_inicial']?.toString() ?? '';
      _nivelMinimoController.text = (data['nivel_minimo']?.toString() ?? '5');
      _validade = data['validade'] != null && data['validade'] is Timestamp
          ? (data['validade'] as Timestamp).toDate()
          : null; // se era ração antiga pode existir, mas não mais exibido
      _mostrarFormulario = true;
    });
  }

  Future<void> _excluirInsumo(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Insumo'),
        content: const Text('Tem certeza que deseja excluir este insumo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('insumos').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insumo excluído com sucesso!')),
      );
    }
  }

  String _busca = '';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Cadastro de Insumos',
      body: DegradeFundo(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _idEditando == null
                            ? 'Cadastrar novo insumo'
                            : 'Editar insumo',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: Icon(_mostrarFormulario ? Icons.close : Icons.add),
                      label: Text(
                        _mostrarFormulario
                            ? 'Fechar'
                            : (_idEditando == null ? 'Novo Insumo' : 'Editar'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mostrarFormulario
                            ? Colors.red[200]
                            : Colors.teal,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_mostrarFormulario) {
                            _mostrarFormulario = false;
                            _limparCampos();
                          } else {
                            _mostrarFormulario = true;
                          }
                        });
                      },
                    ),
                  ],
                ),
                if (_mostrarFormulario)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 10),
                    child: Form(
                      key: _formKey,
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _tipoSelecionado,
                                items: _tiposInsumo
                                    .map(
                                      (tipo) => DropdownMenuItem(
                                        value: tipo,
                                        child: Text(tipo),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _tipoSelecionado = val!),
                                decoration: const InputDecoration(
                                  labelText: 'Tipo de Insumo',
                                ),
                              ),
                              TextFormField(
                                controller: _nomeController,
                                decoration: const InputDecoration(
                                  labelText: 'Nome do Insumo',
                                ),
                                validator: (val) =>
                                    val!.isEmpty ? 'Informe o nome' : null,
                              ),
                              TextFormField(
                                controller: _categoriaController,
                                decoration: const InputDecoration(
                                  labelText: 'Categoria (opcional)',
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _marcaController,
                                      decoration: const InputDecoration(
                                        labelText: 'Marca (opcional)',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _codigoBarrasController,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Código de barras / SKU (opcional)',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              TextFormField(
                                controller: _observacoesController,
                                decoration: const InputDecoration(
                                  labelText: 'Observações',
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue:
                                          _unidadeController.text.isNotEmpty
                                          ? _unidadeController.text
                                          : null,
                                      items: _unidades
                                          .map(
                                            (u) => DropdownMenuItem(
                                              value: u,
                                              child: Text(u),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (val) => setState(
                                        () =>
                                            _unidadeController.text = val ?? '',
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Unidade',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (_tipoSelecionado != 'Ração')
                                    Expanded(
                                      child: TextFormField(
                                        controller:
                                            _quantidadeInicialController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'Qtd. Inicial',
                                        ),
                                      ),
                                    )
                                  else
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.teal[50],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.teal.withOpacity(0.3),
                                          ),
                                        ),
                                        child: const Text(
                                          'Estoque inicial da ração é 0. Use "Entrada por Lote" para adicionar.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.teal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _nivelMinimoController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Nível mínimo (alerta)',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _fornecedorController,
                                      decoration: const InputDecoration(
                                        labelText: 'Fornecedor',
                                      ),
                                    ),
                                  ),
                                  if (_tipoSelecionado != 'Ração') ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _loteController,
                                        decoration: const InputDecoration(
                                          labelText: 'Lote',
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (_tipoSelecionado != 'Ração')
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final data = await showDatePicker(
                                            context: context,
                                            initialDate:
                                                _validade ?? DateTime.now(),
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2100),
                                            locale: const Locale('pt', 'BR'),
                                          );
                                          if (data != null)
                                            setState(() => _validade = data);
                                        },
                                        child: InputDecorator(
                                          decoration: const InputDecoration(
                                            labelText: 'Validade',
                                          ),
                                          child: Text(
                                            _validade == null
                                                ? 'Selecionar'
                                                : '${_validade!.day.toString().padLeft(2, '0')}/${_validade!.month.toString().padLeft(2, '0')}/${_validade!.year}',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              if (_tipoSelecionado == 'Ração') ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.teal[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Validade e códigos de lote da ração são controlados somente nas Entradas de Lote. Após cadastrar a ração, utilize o botão "Entrada por Lote" para inserir lotes com validade.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: Icon(
                                  _idEditando == null ? Icons.save : Icons.edit,
                                ),
                                label: Text(
                                  _idEditando == null ? 'Salvar' : 'Atualizar',
                                ),
                                style: _idEditando == null
                                    ? null
                                    : ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                      ),
                                onPressed: _salvarInsumo,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Insumos Cadastrados',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar insumo',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => _busca = val),
                ),
                const SizedBox(height: 8),
                // Lista integrada ao scroll principal para evitar overflow
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('insumos')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final docs = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final nome = (data['nome'] ?? '')
                          .toString()
                          .toLowerCase();
                      final categoria = (data['categoria'] ?? '')
                          .toString()
                          .toLowerCase();
                      final marca = (data['marca'] ?? '')
                          .toString()
                          .toLowerCase();
                      final cod = (data['codigo_barras'] ?? '')
                          .toString()
                          .toLowerCase();
                      final termo = _busca.toLowerCase();
                      return nome.contains(termo) ||
                          categoria.contains(termo) ||
                          marca.contains(termo) ||
                          cod.contains(termo);
                    }).toList();
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: Text('Nenhum insumo cadastrado.')),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final insumo = docs[index];
                        final data = insumo.data() as Map<String, dynamic>;
                        final estoque =
                            (data['estoque'] ?? data['quantidade_inicial'] ?? 0)
                                as num;
                        final nivelMinimo = (data['nivel_minimo'] ?? 5)
                            .toDouble();
                        final baixo = estoque < nivelMinimo;
                        DateTime? validade;
                        if ((data['tipo'] ?? '') == 'Ração') {
                          validade = data['proxima_validade'] is Timestamp
                              ? (data['proxima_validade'] as Timestamp).toDate()
                              : null;
                        } else {
                          validade = data['validade'] is Timestamp
                              ? (data['validade'] as Timestamp).toDate()
                              : null;
                        }
                        final vencido =
                            validade != null &&
                            validade.isBefore(DateTime.now());
                        final pertoVencer =
                            validade != null &&
                            !vencido &&
                            validade.difference(DateTime.now()).inDays <= 7;
                        List<Widget> chips = [];
                        if (baixo) {
                          chips.add(
                            const Chip(
                              label: Text('Estoque baixo'),
                              backgroundColor: Colors.redAccent,
                              labelStyle: TextStyle(color: Colors.white),
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        }
                        if (vencido) {
                          chips.add(
                            const Chip(
                              label: Text('Vencido'),
                              backgroundColor: Colors.black54,
                              labelStyle: TextStyle(color: Colors.white),
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        } else if (pertoVencer) {
                          chips.add(
                            const Chip(
                              label: Text('Vence em breve'),
                              backgroundColor: Colors.orange,
                              labelStyle: TextStyle(color: Colors.white),
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        }
                        return Card(
                          elevation: 6,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          color: baixo ? Colors.red[50] : Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: baixo
                                        ? Colors.red[100]
                                        : Colors.teal[50],
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(
                                    Icons.inventory_2_rounded,
                                    color: baixo ? Colors.red : Colors.teal,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              data['nome'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (chips.isNotEmpty)
                                            Row(
                                              children: chips
                                                  .map(
                                                    (c) => Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            left: 4,
                                                          ),
                                                      child: c,
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                        ],
                                      ),
                                      if ((data['marca'] ?? '')
                                          .toString()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Marca: ${data['marca']}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        '${data['tipo']} • ${data['categoria'] ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.straighten_rounded,
                                            size: 16,
                                            color: Colors.teal[300],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Unidade: ${data['unidade'] ?? '-'}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (validade != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 16,
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.event_rounded,
                                                    size: 16,
                                                    color: vencido
                                                        ? Colors.red
                                                        : (pertoVencer
                                                              ? Colors.orange
                                                              : Colors.teal),
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    'Validade: ${validade.day.toString().padLeft(2, '0')}/${validade.month.toString().padLeft(2, '0')}/${validade.year}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: vencido
                                                          ? Colors.red
                                                          : (pertoVencer
                                                                ? Colors.orange
                                                                : Colors.teal),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.local_shipping_rounded,
                                            size: 16,
                                            color: Colors.teal[300],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Fornecedor: ${data['fornecedor'] ?? '-'}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                          if ((data['lote'] ?? '')
                                                  .toString()
                                                  .isNotEmpty &&
                                              (data['tipo'] ?? '') != 'Ração')
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 16,
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .confirmation_number_rounded,
                                                    size: 16,
                                                    color: Colors.teal[300],
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    'Lote: ${data['lote']}',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    PopupMenuButton(
                                      onSelected: (value) {
                                        if (value == 'detalhes') {
                                          _mostrarDetalhesInsumo(
                                            data,
                                            insumo.id,
                                          );
                                        } else if (value == 'editar') {
                                          _carregarParaEdicaoDocId(
                                            insumo.id,
                                            data,
                                          );
                                        } else if (value == 'excluir') {
                                          _excluirInsumo(insumo.id);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'detalhes',
                                          child: ListTile(
                                            leading: Icon(Icons.info_rounded),
                                            title: Text('Detalhes'),
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'editar',
                                          child: ListTile(
                                            leading: Icon(
                                              Icons.edit_rounded,
                                              color: Colors.teal,
                                            ),
                                            title: Text(
                                              'Editar',
                                              style: TextStyle(
                                                color: Colors.teal,
                                              ),
                                            ),
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'excluir',
                                          child: ListTile(
                                            leading: Icon(
                                              Icons.delete_forever_rounded,
                                              color: Colors.red,
                                            ),
                                            title: Text('Excluir'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
