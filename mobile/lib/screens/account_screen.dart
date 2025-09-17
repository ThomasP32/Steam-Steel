import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/widgets/chat_widget.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initialTab});

  final String? initialTab;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  bool _loading = false;
  bool _showRegister = false;
  late VoidCallback _authListener;

  @override
  void initState() {
    super.initState();
    _showRegister = (widget.initialTab?.toLowerCase() == 'register');
    _authListener = () {
      if (mounted) setState(() {});
    };
    _authService.notifier.addListener(_authListener);

    _authService.fetchUser().catchError((err) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final msg =
            err is Exception
                ? err.toString().replaceFirst('Exception: ', '')
                : err.toString();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      });
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _usernameCtrl.dispose();
    _authService.notifier.removeListener(_authListener);
    super.dispose();
  }

  Future<void> _register() async {
    if (mounted) setState(() => _loading = true);
    try {
      await _authService.register(
        _emailCtrl.text,
        _passCtrl.text,
        _usernameCtrl.text,
        'avatar1',
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Inscription réussie')));
      }
      await _authService.login(_emailCtrl.text, _passCtrl.text);
    } on Exception catch (e) {
      final raw = e.toString();
      final msg =
          raw.startsWith('Exception: ')
              ? raw.substring('Exception: '.length)
              : raw;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    if (mounted) setState(() => _loading = true);
    try {
      await _authService.login(_emailCtrl.text, _passCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Connecté')));
      }
    } on Exception catch (e) {
      final raw = e.toString();
      final msg =
          raw.startsWith('Exception: ')
              ? raw.substring('Exception: '.length)
              : raw;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.notifier.value;

    Widget pageContent;
    if (user == null) {
      if (_showRegister) {
        pageContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
            ),
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(labelText: 'Pseudonyme'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _register,
              child:
                  _loading
                      ? const CircularProgressIndicator()
                      : const Text('Inscription'),
            ),
            TextButton(
              onPressed: () => setState(() => _showRegister = false),
              child: const Text('Déjà inscrit ? Se connecter'),
            ),
          ],
        );
      } else {
        pageContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
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
            TextButton(
              onPressed: () => setState(() => _showRegister = true),
              child: const Text('Pas encore inscrit ? Inscription'),
            ),
          ],
        );
      }
    } else {
      pageContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pseudonyme: ${user.username}'),
          Text('Email: ${user.email}'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              if (mounted) context.go('/');
            },
            child: const Text("Retour à l'accueil"),
          ),
          ElevatedButton(
            onPressed: () async {
              await _authService.logout();
              if (mounted) context.go('/');
            },
            child: const Text('Déconnexion'),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Compte')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Main content scrolls if needed
            Expanded(child: SingleChildScrollView(child: pageContent)),
            // Chat widget placed below the form. Use Flexible with a max height
            // so it can shrink on small screens and avoid RenderFlex overflow.
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // max 60% of available height, min 160 to keep usable
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                  minHeight: 160,
                ),
                child: const ChatWidget(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
