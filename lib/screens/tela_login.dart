import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:viveiro_plus/screens/login_model.dart';
import 'package:viveiro_plus/widgets/degrade_fundo.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _userCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _senhaVisivel = false;
  String _versao = '';

  @override
  void initState() {
    super.initState();
    _carregarVersao();

    // Dá tempo do LoginModel carregar antes de acessar os dados salvos
    Future.delayed(const Duration(milliseconds: 200), () {
      final model = context.read<LoginModel>();
      if (mounted) {
        _userCtl.text = model.usuarioSalvo;
        _passCtl.text = model.senhaSalva;
      }
    });
  }

  Future<void> _carregarVersao() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _versao = 'Versão ${info.version}+${info.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LoginModel>(
      builder: (context, model, _) {
        return Scaffold(
          backgroundColor: Colors.transparent, // Remove cor fixa
          body: DegradeFundo(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/app_icon.png',
                      width: 200,
                      height: 200,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Viveiro+',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF045D3A),
                            fontSize: 50,
                          ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _userCtl,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Usuário',
                        labelStyle: Theme.of(context).textTheme.bodyLarge,
                        prefixIcon: const Icon(Icons.person),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passCtl,
                      obscureText: !_senhaVisivel,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Senha (números)',
                        labelStyle: Theme.of(context).textTheme.bodyLarge,
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _senhaVisivel ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _senhaVisivel = !_senhaVisivel;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: model.rememberMe,
                          onChanged: (v) => model.toggleRemember(v ?? false),
                        ),
                        Text('Lembrar Usuário', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: model.isLoading
                            ? null
                            : () => model.login(
                                  _userCtl.text.trim(),
                                  _passCtl.text,
                                  context,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF049F56),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: model.isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Entrar',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                              ),
                      ),
                    ),
                    if (model.error != null && model.error!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        model.error!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 32),
                    Text(
                      _versao,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
