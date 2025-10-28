import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
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
  final _formKey = GlobalKey<FormState>();
  bool _senhaVisivel = false;
  String _versao = '';

  @override
  void initState() {
    super.initState();
    _carregarVersao();
    _carregarCredenciaisSalvas();
    // No Web, garantir persistência LOCAL para o navegador lembrar a sessão/senha
    Future.microtask(() async {
      if (kIsWeb) {
        try {
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        } catch (_) {}
      }
    });

    // Limpa erros quando o usuário começa a digitar
    _userCtl.addListener(_limparErro);
    _passCtl.addListener(_limparErro);
  }

  void _limparErro() {
    final model = context.read<LoginModel>();
    if (model.error != null) {
      model.limparErro();
    }
  }

  // Método mais limpo para carregar credenciais
  Future<void> _carregarCredenciaisSalvas() async {
    // Aguarda um pouco para o LoginModel inicializar
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      final model = context.read<LoginModel>();
      _userCtl.text = model.usuarioSalvo;
      _passCtl.text = model.senhaSalva;
    }
  }

  Future<void> _carregarVersao() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _versao = 'Versão ${info.version}+${info.buildNumber}';
    });
  }

  void _realizarLogin(LoginModel model) {
    if (_formKey.currentState!.validate()) {
      model.login(_userCtl.text.trim(), _passCtl.text, context);
    }
  }

  @override
  void dispose() {
    _userCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LoginModel>(
      builder: (context, model, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: DegradeFundo(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo com efeito de sombra
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(100),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 160,
                                  height: 160,
                                  errorBuilder: (c, e, s) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Título com gradiente
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFF045D3A), Color(0xFF049F56)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: Text(
                                'Viveiro+',
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 48,
                                      letterSpacing: 1.2,
                                    ),
                              ),
                            ),

                            const SizedBox(height: 8),
                            Text(
                              'Sistema de Gestão Aquícola',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: const Color(
                                      0xFF045D3A,
                                    ).withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                            ),

                            const SizedBox(height: 40),

                            // Card principal com glassmorphism
                            AutofillGroup(
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Campo usuário
                                    TextFormField(
                                      controller: _userCtl,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                      autofillHints: const [
                                        AutofillHints.username,
                                      ],
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      textCapitalization:
                                          TextCapitalization.none,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Por favor, digite o usuário';
                                        }
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Usuário',
                                        labelStyle: TextStyle(
                                          color: const Color(
                                            0xFF045D3A,
                                          ).withValues(alpha: 0.8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          child: const Icon(
                                            Icons.person_outline,
                                            color: Color(0xFF049F56),
                                            size: 22,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                            width: 1.5,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                            width: 1.5,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF049F56),
                                            width: 2,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.red.shade400,
                                            width: 1.5,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 18,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Campo senha
                                    TextFormField(
                                      controller: _passCtl,
                                      obscureText: !_senhaVisivel,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                      autofillHints: const [
                                        AutofillHints.password,
                                      ],
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Por favor, digite a senha';
                                        }
                                        if (value.length < 4) {
                                          return 'Senha deve ter pelo menos 4 dígitos';
                                        }
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Senha',
                                        hintText: 'Digite apenas números',
                                        labelStyle: TextStyle(
                                          color: const Color(
                                            0xFF045D3A,
                                          ).withValues(alpha: 0.8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 14,
                                        ),
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          child: const Icon(
                                            Icons.lock_outline,
                                            color: Color(0xFF049F56),
                                            size: 22,
                                          ),
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _senhaVisivel
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: const Color(0xFF049F56),
                                            size: 22,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _senhaVisivel = !_senhaVisivel;
                                            });
                                          },
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                            width: 1.5,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                            width: 1.5,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF049F56),
                                            width: 2,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.red.shade400,
                                            width: 1.5,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 18,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Checkbox "Lembrar usuário"
                                    Row(
                                      children: [
                                        Transform.scale(
                                          scale: 1.1,
                                          child: Checkbox(
                                            value: model.rememberMe,
                                            onChanged: (v) => model
                                                .toggleRemember(v ?? false),
                                            activeColor: const Color(
                                              0xFF049F56,
                                            ),
                                            checkColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Lembrar usuário',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: const Color(
                                                  0xFF045D3A,
                                                ).withValues(alpha: 0.8),
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),

                                    // Botão de login
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: model.isLoading
                                            ? null
                                            : () => _realizarLogin(model),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF049F56,
                                          ),
                                          foregroundColor: Colors.white,
                                          elevation: 8,
                                          shadowColor: const Color(
                                            0xFF049F56,
                                          ).withValues(alpha: 0.4),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                        ),
                                        child: model.isLoading
                                            ? const SizedBox(
                                                height: 24,
                                                width: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.5,
                                                    ),
                                              )
                                            : Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.login_rounded,
                                                    size: 22,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Entrar',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 18,
                                                          letterSpacing: 0.5,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Container de erro modernizado
                            ...(model.error != null && model.error!.isNotEmpty
                                ? [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.red.shade50,
                                            Colors.red.shade100.withValues(
                                              alpha: 0.8,
                                            ),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(
                                          color: Colors.red.shade300,
                                          width: 1.5,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withValues(
                                              alpha: 0.1,
                                            ),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Icon(
                                              Icons.error_outline_rounded,
                                              color: Colors.red.shade600,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Ops! Algo deu errado',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        color:
                                                            Colors.red.shade700,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  model.error!,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color:
                                                            Colors.red.shade600,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        height: 1.4,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ]
                                : []),

                            // Versão do app
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: const Color(
                                      0xFF045D3A,
                                    ).withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _versao,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: const Color(
                                            0xFF045D3A,
                                          ).withValues(alpha: 0.7),
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ), // Column
                      ), // Form
                    ), // ConstrainedBox
                  ), // Center (inner)
                ), // SingleChildScrollView
              ), // Center (outer)
            ), // SafeArea
          ), // DegradeFundo
        );
      },
    );
  }
}
