import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/services/audio_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/friend_service.dart';
import 'package:mobile/services/join_game_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:mobile/widgets/chat_widget.dart';
import 'package:mobile/widgets/friends/friend_button.dart';
import 'package:mobile/widgets/money_widget.dart';
import 'package:mobile/widgets/theme/theme_widget.dart';
import 'package:mobile/widgets/waiting_room/game_preview_widget.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class JoinGameScreen extends StatefulWidget {
  const JoinGameScreen({super.key});

  @override
  State<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends State<JoinGameScreen> {
  static const int _codeLength = 4;

  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  late JoinGameService _joinService;
  late SocketService _socketService;

  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _accessTimeout;

  bool _isLoading = false;
  List<Map<String, dynamic>> _games = [];
  bool _loadingGames = true;
  String? _pendingGameCode;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_codeLength, (_) => TextEditingController());
    _focusNodes = List.generate(_codeLength, (_) => FocusNode());
    _joinService = JoinGameService();
    _socketService = SocketService();

    _loadFriends();

    _setupListeners();
    _joinService.fetchGames();
  }

  Future<void> _loadFriends() async {
    try {
      await FriendService().getFriends();
    } on Exception catch (_) {
      // Silently fail
    }
  }

  void _setupListeners() {
    _subs
      ..add(_joinService.gamesStream.listen(_handleGamesUpdate))
      ..add(_joinService.loadingStream.listen(_handleLoadingUpdate))
      ..add(
        _socketService
            .listen<void>('gameListUpdated')
            .listen(_onGameListUpdated),
      )
      ..add(_socketService.listen<dynamic>('getGames').listen(_onGetGames))
      ..add(_socketService.listen<void>('gameAccessed').listen(_onGameAccessed))
      ..add(
        _socketService
            .listen<Map<String, dynamic>>('gameResumed')
            .listen(_onGameResumed),
      )
      ..add(
        _socketService
            .listen<Map<String, dynamic>>('youJoined')
            .listen(_onYouJoined),
      )
      ..add(
        _socketService.listen<String?>('gameNotFound').listen(_onGameNotFound),
      )
      ..add(_socketService.listen<String>('gameLocked').listen(_onGameLocked))
      ..add(_socketService.listen<void>('gameClosed').listen(_onGameClosed))
      ..add(
        _socketService
            .listen<void>('gameEndedNoActivePlayers')
            .listen(_onGameEnded),
      )
      ..add(_socketService.listen<void>('gameFinished').listen(_onGameEnded))
      ..add(
        _socketService
            .listen<Map<String, dynamic>>('friendRemoved')
            .listen(_onFriendRemoved),
      )
      ..add(
        _socketService
            .listen<Map<String, dynamic>>('friendAdded')
            .listen(_onFriendAdded),
      )
      ..add(
        _socketService
            .listen<Map<String, dynamic>>('friendListUpdated')
            .listen(_onFriendListUpdated),
      );
  }

  void _handleGamesUpdate(List<Map<String, dynamic>> games) {
    if (!mounted) return;
    setState(() => _games = games);
  }

  void _handleLoadingUpdate(bool loading) {
    if (!mounted) return;
    setState(() => _loadingGames = loading);
  }

  void _onGameListUpdated(void _) => _joinService.fetchGames();

  void _onGameClosed(void _) {
    _joinService.fetchGames();
  }

  void _onGameEnded(void _) {
    _joinService.fetchGames();
  }

  void _onGetGames(dynamic data) => _joinService.handleGamesResponse(data);

  void _onFriendRemoved(Map<String, dynamic> data) {
    final username = data['username'] as String?;
    if (username != null) {
      _loadFriends().then((_) {
        _joinService.fetchGames();
      });
    }
  }

  void _onFriendAdded(Map<String, dynamic> data) {
    _loadFriends().then((_) {
      _joinService.fetchGames();
    });
  }

  void _onFriendListUpdated(Map<String, dynamic> data) {
    _loadFriends().then((_) {
      _joinService.fetchGames();
    });
  }

  void _onGameAccessed(void _) {
    _cancelTimeout();
    if (!mounted) return;

    setState(() => _isLoading = false);
    final code = _pendingGameCode ?? _getEnteredCode();
    _navigateToCharacterCreation(code);
  }

  void _onYouJoined(Map<String, dynamic> data) {
    _cancelTimeout();
    if (!mounted) return;

    setState(() => _isLoading = false);

    try {
      _joinService.handleYouJoined(data);
      final updatedGame = data['updatedGame'] as Map<String, dynamic>?;
      final updatedPlayer = data['updatedPlayer'] as Map<String, dynamic>?;

      if (updatedGame != null && updatedPlayer != null) {
        _pendingGameCode = null;

        final isObserver = updatedPlayer['isObserver'] as bool? ?? false;
        final gameId = updatedGame['id'] as String;

        if (isObserver) {
          DebugLogger.log(
            'Player is observer, navigating to game view',
            tag: 'JoinGameScreen',
          );
          context.go('/game/$gameId/${updatedGame['name']}');
        } else {
          final route = _joinService.buildGameRoute(updatedGame);
          context.go(route);
        }
      }
    } on Exception catch (e) {
      DebugLogger.log(
        'Navigation failed after youJoined: $e',
        tag: 'JoinGameScreen',
      );
    }
  }

  void _onGameNotFound(String? reason) {
    _cancelTimeout();
    if (!mounted) return;

    if (_isLoading || _pendingGameCode != null) {
      setState(() => _isLoading = false);
      _showError('Partie introuvable');
      _resetInputs();
    }
    _pendingGameCode = null;
  }

  void _onGameLocked(String reason) {
    _cancelTimeout();
    if (!mounted) return;

    if (_isLoading || _pendingGameCode != null) {
      setState(() => _isLoading = false);
      final message = reason.isNotEmpty ? reason : 'La partie est verrouillée';
      _showError(message);
      _resetInputs();
    }
    _pendingGameCode = null;
  }

  void _onGameTap(Map<String, dynamic> game) {
    final gameId = game['id'] as String?;
    if (gameId == null) return;

    final hasStarted =
        game.containsKey('hasStarted')
            ? game['hasStarted'] as bool? ?? false
            : false;

    if (hasStarted) {
      _onJoinGame(game);
    } else {
      if (!_checkEntryFee(game)) {
        return;
      }
      _handleJoinFlow(gameId);
    }
  }

  bool _checkEntryFee(Map<String, dynamic> game) {
    final settings = game['settings'] as Map<String, dynamic>?;
    final entryFee = settings?['entryFee'] as int? ?? 0;

    if (entryFee > 0) {
      final user = AuthService().notifier.value;
      final userMoney = user?.virtualMoney ?? 0;

      if (userMoney < entryFee) {
        _showError(
          'Vous n\'avez pas assez de monnaie virtuelle pour rejoindre cette partie',
        );
        return false;
      }
    }
    return true;
  }

  void _handleObserverFlow(Map<String, dynamic> game, String gameId) {
    final existingPlayer = _joinService.getExistingPlayer(game);

    if (existingPlayer != null) {
      _observeWithExistingPlayer(gameId, existingPlayer);
    } else {
      _observeAsNewObserver(gameId);
    }
  }

  void _observeAsNewObserver(String gameId) {
    DebugLogger.log(
      'Creating minimal observer and joining directly',
      tag: 'JoinGameScreen',
    );

    setState(() {
      _isLoading = true;
      _pendingGameCode = gameId;
    });

    final minimalObserver = _joinService.createMinimalObserverPlayer();
    _joinService.observeGame(gameId: gameId, player: minimalObserver);
    _startTimeout();
  }

  void _observeWithExistingPlayer(String gameId, Map<String, dynamic> player) {
    DebugLogger.log(
      'Observing with existing player: ${player['name']}',
      tag: 'JoinGameScreen',
    );

    setState(() {
      _isLoading = true;
      _pendingGameCode = gameId;
    });

    _joinService.observeGame(gameId: gameId, player: player);
    _startTimeout();
  }

  void _handleJoinFlow(String gameId) {
    setState(() {
      _isLoading = true;
      _pendingGameCode = gameId;
    });

    _joinService.accessGame(gameId);
    _startTimeout();
  }

  void _onJoinGame(Map<String, dynamic> game) {
    final gameId = game['id'] as String?;
    if (gameId == null) return;

    if (!_checkEntryFee(game)) {
      return;
    }

    final hasStarted = game['hasStarted'] as bool? ?? false;
    final existingPlayer = _joinService.getExistingPlayer(game);
    final isEliminated = _joinService.isPlayerEliminated(game);

    if (hasStarted && existingPlayer != null) {
      if (isEliminated) {
        _handleEliminatedPlayerRejoin(game, gameId);
      } else {
        _handleActivePlayerRejoin(game, gameId);
      }
      return;
    }

    if (hasStarted && existingPlayer == null) {
      setState(() {
        _isLoading = true;
        _pendingGameCode = gameId;
      });
      _joinService.accessGame(gameId);
      _startTimeout();
      return;
    }

    final mapName = _joinService.extractMapName(game);
    final settings = _joinService.extractGameSettings(game);

    AudioService().stopMusic();
    context.go(
      '/$gameId/choose-character',
      extra: {'isObserver': false, 'mapName': mapName, 'settings': settings},
    );
  }

  void _handleEliminatedPlayerRejoin(Map<String, dynamic> game, String gameId) {
    DebugLogger.log('Rejoining as eliminated player', tag: 'JoinGameScreen');

    final existingPlayer = _joinService.getExistingPlayer(game);
    if (existingPlayer != null) {
      setState(() {
        _isLoading = true;
        _pendingGameCode = gameId;
      });

      _joinService.resumeGame(gameId: gameId, player: existingPlayer);
      _startTimeout();
    }
  }

  void _handleActivePlayerRejoin(Map<String, dynamic> game, String gameId) {
    DebugLogger.log('Rejoining as active player', tag: 'JoinGameScreen');

    final existingPlayer = _joinService.getExistingPlayer(game);
    if (existingPlayer != null) {
      setState(() {
        _isLoading = true;
        _pendingGameCode = gameId;
      });

      _joinService.resumeGame(gameId: gameId, player: existingPlayer);
      _startTimeout();
    }
  }

  void _navigateToCharacterCreation(String code) {
    _pendingGameCode = null;
    try {
      final game = _games.firstWhere(
        (g) => g['id'] == code,
        orElse: () => <String, dynamic>{},
      );

      if (game.isNotEmpty) {
        if (!_checkEntryFee(game)) {
          return;
        }

        final settings = _joinService.extractGameSettings(game);
        final mapName = _joinService.extractMapName(game);
        AudioService().stopMusic();
        context.go(
          '/$code/choose-character',
          extra: {'mapName': mapName, 'settings': settings},
        );
      } else {
        // Fallback: navigate without settings, will be fetched via socket
        AudioService().stopMusic();
        context.go('/$code/choose-character');
      }
    } on Exception catch (e) {
      DebugLogger.log('Navigation failed: $e', tag: 'JoinGameScreen');
    }
  }

  void _onCodeComplete() {
    final code = _getEnteredCode();
    setState(() => _isLoading = true);

    _joinService.accessGame(code);
    _startTimeout();
  }

  void _startTimeout() {
    _cancelTimeout();
    _accessTimeout = Timer(const Duration(seconds: 5), () {
      if (!mounted || !_isLoading) return;

      setState(() {
        _isLoading = false;
        _pendingGameCode = null;
      });

      _showError("Délai d'attente dépassé");
      _resetInputs();
    });
  }

  void _cancelTimeout() {
    _accessTimeout?.cancel();
  }

  void _resetInputs() {
    for (final c in _controllers) {
      c.clear();
    }
    if (_focusNodes.isNotEmpty) {
      _focusNodes.first.requestFocus();
    }
  }

  String _getEnteredCode() => _controllers.map((c) => c.text).join();

  void _showError(String message) {
    showTopSnackBar(
      Overlay.of(context),
      CustomSnackBar.error(message: message),
    );
  }

  @override
  void dispose() {
    _cancelTimeout();
    _pendingGameCode = null;

    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();

    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (mounted) {
          context.go('/');
        }
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            const Positioned.fill(
              child: ThemeBackground(pageId: 'gamecreation'),
            ),
            Stack(
              children: [
                Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 25),
                    _buildCodeEntry(),
                    const SizedBox(height: 24),
                    _buildGamesSection(),
                  ],
                ),
                if (_isLoading) _buildLoadingOverlay(),
                const Positioned(
                  top: 18,
                  right: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 7),
                        child: MoneyWidget(),
                      ),
                      SizedBox(width: 8),
                      FriendButton(),
                      ChatWidget(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: SizedBox(
          height: kToolbarHeight,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Retour'),
                ),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? Colors.black45
                            : Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'REJOINS UNE PARTIE',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeEntry() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:
                isDark ? Colors.black45 : Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Veuillez entrer le code de la partie',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_codeLength, _buildCodeInput),
        ),
      ],
    );
  }

  Widget _buildCodeInput(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 60,
      height: 60,
      child: TextField(
        enabled: !_isLoading,
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        keyboardType: TextInputType.text,
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        onChanged: (value) => _onCodeInputChanged(index, value),
      ),
    );
  }

  void _onCodeInputChanged(int index, String value) {
    if (_isLoading) return;

    if (value.isEmpty) {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
        _controllers[index - 1].clear();
      }
      return;
    }

    _controllers[index]
      ..text = value[0]
      ..selection = const TextSelection.collapsed(offset: 1);

    if (index + 1 < _codeLength) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _onCodeComplete();
    }
  }

  Widget _buildGamesSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? Colors.black45
                        : Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Parties disponibles',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildGamesList()),
        ],
      ),
    );
  }

  Widget _buildGamesList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black54;

    if (_loadingGames) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_games.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:
                isDark ? Colors.black45 : Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Aucune partie disponible',
            style: TextStyle(color: textColor, fontSize: 16),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.66,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _games.length,
      itemBuilder: (context, index) {
        final game = _games[index];
        return GamePreviewWidget(
          game: game,
          onTap: () => _onGameTap(game),
          onJoinGame: () => _onJoinGame(game),
          onObserve: () => _handleObserverFlow(game, game['id'] as String),
          currentUsername: _joinService.currentUsername,
        );
      },
    );
  }

  Widget _buildLoadingOverlay() {
    return const Positioned.fill(
      child: ColoredBox(
        color: Color.fromRGBO(0, 0, 0, 0.5),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _onGameResumed(Map<String, dynamic> game) {
    _cancelTimeout();
    if (!mounted) return;
    setState(() => _isLoading = false);

    try {
      final existingPlayer = _joinService.getExistingPlayer(game);
      final gameId = game['id'] as String;

      if (existingPlayer != null) {
        _joinService.joinGame(gameId: gameId, player: existingPlayer);
      } else {
        final mapName = _joinService.extractMapName(game);
        final settings = _joinService.extractGameSettings(game);

        context.go(
          '/$gameId/choose-character',
          extra: {
            'isObserver': false,
            'mapName': mapName,
            'settings': settings,
          },
        );
      }
    } on Exception catch (e) {
      DebugLogger.log(
        'Failed to handle gameResumed: $e',
        tag: 'JoinGameScreen',
      );
    }
  }
}
