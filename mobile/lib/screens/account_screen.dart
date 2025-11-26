import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/common/user.dart';
import 'package:mobile/services/audio_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:mobile/widgets/register/profile_picture_picker.dart';
import 'package:mobile/widgets/theme/theme_widget.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initialTab});

  final String? initialTab;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  final AudioService _audioService = AudioService();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  bool _loading = false;
  bool _showRegister = false;
  ProfilePicture _selectedProfilePicture = ProfilePicture.profile1;
  String? _customProfilePicturePreview;
  bool _showLoginPassword = false;
  bool _showRegisterPassword = false;
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
        _selectedProfilePicture,
        _customProfilePicturePreview,
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

    var selectedProfilePicture = ProfilePicture.values.firstWhere(
      (a) => a.value == user.profilePicture,
      orElse: () => ProfilePicture.profile1,
    );
    var customPreview = user.profilePictureCustom;

    final unlockedProfilePictures = <int>{1, 2, 3};

    for (final item in user.shopItems) {
      if (item.itemId.startsWith('profile_')) {
        final profileNum = int.tryParse(
          item.itemId.replaceFirst('profile_', ''),
        );
        if (profileNum != null) {
          unlockedProfilePictures.add(profileNum);
        }
      }
    }

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
                          maxLength: 10,
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
                            'Photo de profil :',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ProfilePicturePicker(
                          selected: selectedProfilePicture,
                          customPreview: customPreview,
                          showOnlyFree: false,
                          onProfilePictureChanged: (pp) {
                            setModalState(() {
                              selectedProfilePicture = pp;
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
                            'profilePicture': selectedProfilePicture,
                            'profilePictureCustom': customPreview,
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
        profilePicture: result['profilePicture'] as ProfilePicture,
        profilePictureCustom: result['profilePictureCustom'] as String?,
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
    final audioService = AudioService();

    Widget pageContent;
    if (user == null) {
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
      Widget profilePictureWidget;
      final custom = user.profilePictureCustom;
      if (custom != null && custom.isNotEmpty) {
        if (custom.startsWith('data:')) {
          try {
            final parts = custom.split(',');
            final payload = parts.length > 1 ? parts.last : parts.first;
            final bytes = base64Decode(payload);
            profilePictureWidget = Image.memory(
              bytes,
              width: 250,
              height: 250,
              fit: BoxFit.cover,
            );
          } on Object catch (_) {
            profilePictureWidget = const SizedBox(width: 250, height: 250);
          }
        } else if (custom.startsWith('http')) {
          profilePictureWidget = Image.network(
            custom,
            width: 250,
            height: 250,
            fit: BoxFit.cover,
          );
        } else {
          final file = File(custom);
          profilePictureWidget =
              file.existsSync()
                  ? Image.file(file, width: 250, height: 250, fit: BoxFit.cover)
                  : const SizedBox(width: 250, height: 250);
        }
      } else {
        var idx = user.profilePicture ?? 1;
        if (idx < 1 || idx > 13) idx = 1;
        profilePictureWidget = Image.asset(
          'lib/assets/profile/$idx.png',
          width: 250,
          height: 250,
          fit: BoxFit.cover,
        );
      }

      final isDark = Theme.of(context).brightness == Brightness.dark;

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
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? Colors.black45
                          : Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Mon compte',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),

              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              profilePictureWidget,
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? Colors.black45
                                    : Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Pseudonyme:'),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? Colors.black45
                                    : Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user.username,
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 8),
                              Image.asset(
                                'lib/assets/level-badges/level-${user.stats.level}.png',
                                width: 48,
                                height: 48,
                                errorBuilder: (context, error, stackTrace) {
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? Colors.black45
                                : Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Statut:'),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? Colors.black45
                                : Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getStatusText(user.status),
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(user.status),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? Colors.black45
                                    : Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Thème:'),
                        ),
                        const SizedBox(width: 8),
                        const ThemeToggleButton(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? Colors.black45
                                    : Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Musique:'),
                        ),
                        const SizedBox(width: 8),
                        ValueListenableBuilder<bool>(
                          valueListenable: audioService.musicEnabledNotifier,
                          builder: (context, enabled, _) {
                            return SizedBox(
                              width: 44,
                              height: 44,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed:
                                    () => setState(
                                      () =>
                                          audioService.musicEnabled = !enabled,
                                    ),
                                child: Icon(
                                  enabled ? Icons.music_note : Icons.music_off,
                                  size: 24,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 24),
                      ],
                    ),
                    // Music selector
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? Colors.black45
                                    : Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Musique sélectionnée:'),
                        ),
                        const SizedBox(height: 4),
                        ValueListenableBuilder<String>(
                          valueListenable: audioService.equippedMusicNotifier,
                          builder: (context, selectedMusic, _) {
                            // Check if user owns Minecraft music
                            DebugLogger.log(
                              'Shop items: ${user.shopItems.map((e) => e.itemId).toList()}',
                              tag: 'AccountScreen',
                            );
                            final ownsMinecraft = user.shopItems.any(
                              (item) => item.itemId == 'sound_1',
                            );
                            DebugLogger.log(
                              'Owns Minecraft: $ownsMinecraft',
                              tag: 'AccountScreen',
                            );

                            final musicItems = <DropdownMenuItem<String>>[
                              const DropdownMenuItem(
                                value: 'music2.mp3',
                                child: Text('Musique par défaut'),
                              ),
                            ];

                            if (ownsMinecraft) {
                              musicItems.add(
                                const DropdownMenuItem(
                                  value: 'minecraft.mp3',
                                  child: Text('Minecraft'),
                                ),
                              );
                            }

                            return DropdownButton<String>(
                              value: selectedMusic,
                              isExpanded: true,
                              items: musicItems,
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  audioService.setEquippedMusic(newValue);
                                }
                              },
                            );
                          },
                        ),
                      ],
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? Colors.black45
                          : Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Email:'),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? Colors.black45
                          : Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? Colors.black45
                      : Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Statistiques',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          _buildStatCard(
            'Classique',
            user.stats.classique.gamesPlayed,
            user.stats.classique.gamesWon,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'CTF',
            user.stats.ctf.gamesPlayed,
            user.stats.ctf.gamesWon,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Temps moyen par partie',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SizedBox(),
                      Text(
                        _formatTime(user.stats.avgTime),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Défis complétés',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SizedBox(),
                      Text(
                        '${user.stats.challengesCompleted}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
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
        GoRouter.of(context).go('/');
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            const Positioned.fill(child: ThemeBackground(pageId: 'account')),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(child: SingleChildScrollView(child: pageContent)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white70 : Colors.black87;

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
              decoration: InputDecoration(
                labelText: 'Pseudonyme',
                labelStyle: TextStyle(color: labelColor),
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.accentHighlight(context),
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(Icons.person),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                labelStyle: TextStyle(color: labelColor),
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.accentHighlight(context),
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: GestureDetector(
                  onTapDown: (_) => setState(() => _showLoginPassword = true),
                  onTapUp: (_) => setState(() => _showLoginPassword = false),
                  onTapCancel: () => setState(() => _showLoginPassword = false),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('👁', style: TextStyle(fontSize: 20)),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
              ),
              obscureText: !_showLoginPassword,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white70 : Colors.black87;

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
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: labelColor),
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.accentHighlight(context),
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(Icons.email),
                contentPadding: const EdgeInsets.symmetric(
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
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                labelStyle: TextStyle(color: labelColor),
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.accentHighlight(context),
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: GestureDetector(
                  onTapDown:
                      (_) => setState(() => _showRegisterPassword = true),
                  onTapUp: (_) => setState(() => _showRegisterPassword = false),
                  onTapCancel:
                      () => setState(() => _showRegisterPassword = false),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('👁', style: TextStyle(fontSize: 20)),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
              ),
              obscureText: !_showRegisterPassword,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameCtrl,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'Pseudonyme',
                labelStyle: TextStyle(color: labelColor),
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.accentHighlight(context),
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(Icons.person),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            const Text(
              'Choisissez une photo de profil :',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ProfilePicturePicker(
              selected: _selectedProfilePicture,
              customPreview: _customProfilePicturePreview,
              showOnlyFree: true,
              onProfilePictureChanged:
                  (pp) => setState(() => _selectedProfilePicture = pp),
              onCustomPreviewChanged:
                  (p) => setState(() => _customProfilePicturePreview = p),
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

  String _formatTime(double seconds) {
    final totalSeconds = seconds.round();
    final minutes = totalSeconds ~/ 60;
    final remainingSeconds = totalSeconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }
}
