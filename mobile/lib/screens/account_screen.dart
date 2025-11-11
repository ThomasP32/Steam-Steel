import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/common/user.dart';
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
  String? _customAvatarPreview;
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
      await _authService.login(_usernameCtrl.text, _passCtrl.text);
      if (mounted) {
        context.go('/');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Compte créé avec succès')),
          );
        });
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

  Future<void> _login() async {
    if (mounted) setState(() => _loading = true);
    try {
      await _authService.login(_usernameCtrl.text, _passCtrl.text);
      if (mounted) {
        context.go('/');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Connexion réussie')));
          }
        });
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

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 80,
              vertical: 24,
            ),
            title: const Center(
              child: Text(
                'Confirmer la suppression\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            content: const Text(
              'Êtes-vous sûr de vouloir supprimer votre compte ?\n\n'
              'Cette action est irréversible.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await _authService.deleteAccount();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Compte supprimé')));
        context.go('/');
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
        ).showSnackBar(SnackBar(content: Text('Erreur: $msg')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showEditModal(User user) async {
    final usernameEditCtrl = TextEditingController(text: user.username);
    final emailEditCtrl = TextEditingController(text: user.email);

    var selectedAvatar = Avatar.values.firstWhere(
      (a) => a.value == int.tryParse(user.avatar),
      orElse: () => Avatar.avatar1,
    );
    var customPreview = user.avatarCustom;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setModalState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: const Text(
                    'Modifier mon compte\n',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: usernameEditCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Pseudonyme',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: emailEditCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Avatar :',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AvatarPicker(
                          selected: selectedAvatar,
                          customPreview: customPreview,
                          onAvatarChanged: (a) {
                            setModalState(() {
                              selectedAvatar = a;
                              customPreview = null;
                            });
                          },
                          onCustomPreviewChanged:
                              (p) => setModalState(() => customPreview = p),
                        ),
                      ],
                    ),
                  ),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      onPressed:
                          () => Navigator.of(ctx).pop({
                            'username': usernameEditCtrl.text.trim(),
                            'email': emailEditCtrl.text.trim(),
                            'avatar': selectedAvatar,
                            'avatarCustom': customPreview,
                          }),
                      child: const Text('Sauvegarder'),
                    ),
                  ],
                ),
          ),
    );

    if (result == null || !mounted) return;

    setState(() => _loading = true);
    try {
      await _authService.updateAccount(
        username: result['username'] as String,
        email: result['email'] as String,
        avatar: result['avatar'] as Avatar,
        avatarCustom: result['avatarCustom'] as String?,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Compte mis à jour')));
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
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
      // Login/Register forms - centered without scroll
      pageContent = LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: constraints.maxHeight * 0.9,
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child:
                      _showRegister ? _buildRegisterForm() : _buildLoginForm(),
                ),
              ),
            ),
          );
        },
      );
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
          width: 250,
          height: 250,
          fit: BoxFit.cover,
        );
      }

      final profileSection = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () async {
                  if (mounted) context.go('/');
                },
                child: const Text('Retour'),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 30),
                  child: Text(
                    'Mon compte',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              avatarWidget,
              const SizedBox(width: 50),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pseudonyme:'),
                    Text(
                      user.username,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    const Text('Status:'),
                    Text(
                      _getStatusText(user.status),
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(user.status),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Email:'),
              Text(
                user.email,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _loading ? null : () => _showEditModal(user),
            child: const Text('Modifier mon compte'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _deleteAccount,
            child: const Text('Supprimer mon compte'),
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

      final statsSection = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistiques',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildStatCard(
            'Mode Classique',
            user.stats.classique.gamesPlayed,
            user.stats.classique.gamesWon,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Mode CTF',
            user.stats.ctf.gamesPlayed,
            user.stats.ctf.gamesWon,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Temps moyen par partie',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${user.stats.avgTime.toStringAsFixed(0)}s',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

      pageContent = Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: profileSection),
              const SizedBox(width: 24),
              Expanded(child: statsSection),
            ],
          ),
        ),
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
        resizeToAvoidBottomInset: true,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('lib/assets/backgrounds/backgroundcombat.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(child: pageContent),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Se connecter',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Pseudonyme',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _loading ? null : _login(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child:
                  _loading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text(
                        'Se connecter',
                        style: TextStyle(fontSize: 16),
                      ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _showRegister = true),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text('Pas encore inscrit ? Inscription'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "S'inscrire",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
              ),
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Pseudonyme',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            const Text(
              'Choisissez un avatar :',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              textAlign: TextAlign.center,
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
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child:
                  _loading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text(
                        "S'inscrire",
                        style: TextStyle(fontSize: 16),
                      ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _showRegister = false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text('Déjà inscrit ? Se connecter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, int played, int won) {
    final winRate =
        played > 0 ? ((won / played) * 100).toStringAsFixed(1) : '0.0';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text('Jouées: $played'), Text('Gagnées: $won')],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Taux de victoire'),
                    Text(
                      '$winRate%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
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
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return 'En ligne';
      case 'offline':
        return 'Hors ligne';
      case 'ingame':
        return 'En jeu';
      default:
        return 'Inconnu';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return Colors.green;
      case 'offline':
        return Colors.grey;
      case 'ingame':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
