import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/utils/debug_logger.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _authService.fetchUser().catchError((_) {});
    _authService.notifier.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      await _authService.login(_emailCtrl.text, _passCtrl.text);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Connecté')));
    } on Exception catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.notifier.value;
    DebugLogger.log('User: $user', tag: 'AuthScreen');
    return Scaffold(
      appBar: AppBar(title: const Text('Compte')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            user == null
                ? Column(
                  children: [
                    TextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    TextField(
                      controller: _passCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child:
                          _loading
                              ? const CircularProgressIndicator()
                              : const Text('Se connecter'),
                    ),
                  ],
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pseudonyme: ${user['user']?['username'] ?? ''}'),
                    Text('Email: ${user['user']?['email'] ?? ''}'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        await _authService.logout();
                        if (mounted) context.go('/');
                      },
                      child: const Text('Déconnexion'),
                    ),
                  ],
                ),
      ),
    );
  }
}
