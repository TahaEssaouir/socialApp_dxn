import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/logger.dart';
import 'auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.redirectTo});

  final String? redirectTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );

      if (!mounted) return;
      final String target = _targetLocation();
      context.go(target);
    } on SignInException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error, stack) {
      log.error('Erreur inattendue pendant la connexion', error, stack);
      if (!mounted) return;
      setState(() => _error = 'Connexion impossible. Réessayez.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _targetLocation() {
    final String? target = widget.redirectTo;
    if (target == null || target.isEmpty || target == '/login') return '/';
    return target;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Icon(Icons.lock_outline, size: 44),
                      const SizedBox(height: 16),
                      const Text(
                        'Espace administrateur',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Connectez-vous pour publier un poster. '
                        'Les visiteurs n’ont pas besoin de compte.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const <String>[AutofillHints.email],
                        autocorrect: false,
                        enabled: !_submitting,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (String? value) {
                          final String email = value?.trim() ?? '';
                          if (email.isEmpty) return 'Saisissez votre email.';
                          if (!email.contains('@') || !email.contains('.')) {
                            return 'Email invalide.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const <String>[AutofillHints.password],
                        enabled: !_submitting,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.key_outlined),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Afficher le mot de passe'
                                : 'Masquer le mot de passe',
                            onPressed: _submitting
                                ? null
                                : () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (String? value) {
                          if (value == null || value.isEmpty) {
                            return 'Saisissez votre mot de passe.';
                          }
                          if (value.length < 6) {
                            return 'Le mot de passe doit contenir au moins 6 caractères.';
                          }
                          return null;
                        },
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3A1212),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF7A2020)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Icon(
                                Icons.error_outline,
                                size: 18,
                                color: Color(0xFFFFB4AB),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFFFB4AB),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Se connecter'),
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => context.go('/'),
                        child: const Text('Retour au profil'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
