import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:mobile/widgets/register/avatar_picker.dart';

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
  Avatar _selectedAvatar = Avatar.avatar1;
  String? _customAvatarPreview; // data URL or file path
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
        _selectedAvatar,
        _customAvatarPreview,
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
      DebugLogger.log('Login error: $msg', tag: 'AuthScreen');
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
              obscureText: true,
            ),
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(labelText: 'Pseudonyme'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Choisissez un avatar :',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            AvatarPicker(
              selected: _selectedAvatar,
              customPreview: _customAvatarPreview,
              onAvatarChanged: (a) => setState(() => _selectedAvatar = a),
              onCustomPreviewChanged:
                  (p) => setState(() => _customAvatarPreview = p),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _register,
              child:
                  _loading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text("S'inscrire"),
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
      Widget avatarWidget;
      final custom = user.avatarCustom;
      if (custom != null && custom.isNotEmpty) {
        if (custom.startsWith('data:')) {
          try {
            final parts = custom.split(',');
            final payload = parts.length > 1 ? parts.last : parts.first;
            final bytes = base64Decode(payload);
            avatarWidget = Image.memory(
              bytes,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            );
          } on Object catch (_) {
            avatarWidget = const SizedBox(width: 80, height: 80);
          }
        } else if (custom.startsWith('http')) {
          avatarWidget = Image.network(
            custom,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          );
        } else {
          final file = File(custom);
          avatarWidget =
              file.existsSync()
                  ? Image.file(file, width: 80, height: 80, fit: BoxFit.cover)
                  : const SizedBox(width: 80, height: 80);
        }
      } else {
        var idx = int.tryParse(user.avatar) ?? 1;
        if (idx < 1 || idx > 12) idx = 1;
        avatarWidget = Image.asset(
          'lib/assets/characters/$idx.png',
          width: 80,
          height: 80,
          fit: BoxFit.cover,
        );
      }

      pageContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatarWidget,
          const SizedBox(height: 8),
          Text('Email: ${user.email}'),
          Text('Pseudonyme: ${user.username}'),
          const SizedBox(height: 8),
          const Text('Statistiques:', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            'Classique : ${user.stats.classique.gamesPlayed} parties jouées, ${user.stats.classique.gamesWon} parties gagnées',
          ),
          Text(
            'CTF : ${user.stats.ctf.gamesPlayed} parties jouées, ${user.stats.ctf.gamesWon} parties gagnées',
          ),
          const SizedBox(height: 8),
          Text(
            'Temps moyen par partie :',
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text('${user.stats.avgTime.toStringAsFixed(0)}s'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              if (mounted) context.go('/');
            },
            child: const Text('Modifier mon compte (TODO)'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              if (mounted) context.go('/');
            },
            child: const Text('Supprimer mon compte (TODO)'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              if (mounted) context.go('/');
            },
            child: const Text("Retour à l'accueil"),
          ),
          const SizedBox(height: 8),
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

    return WillPopScope(
      onWillPop: () async {
        if (mounted) {
          context.go('/');
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Mon compte')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(child: SingleChildScrollView(child: pageContent)),
            ],
          ),
        ),
      ),
    );
  }
}
