import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/services/player_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/widgets/theme/theme_widget.dart';

class CombatModalWidget extends StatefulWidget {
  const CombatModalWidget({
    required this.challenger,
    required this.opponent,
    required this.gameId,
    this.isObserver = false,
    super.key,
  });

  final Map<String, dynamic> challenger;
  final Map<String, dynamic> opponent;
  final String gameId;
  final bool isObserver;

  @override
  State<CombatModalWidget> createState() => _CombatModalWidgetState();
}

class _CombatModalWidgetState extends State<CombatModalWidget> {
  bool _isYourTurn = false;
  int _countdown = 5;
  String _combatMessage = '';
  int? _attackDice;
  int? _defenseDice;
  bool _attacking = false;
  Map<String, dynamic>? _currentChallenger;
  Map<String, dynamic>? _currentOpponent;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();

    final currentPlayer = PlayerService().player;
    final challengerSocketId = widget.challenger['socketId'] as String?;
    final isCurrentPlayerChallenger =
        currentPlayer.socketId == challengerSocketId;

    if (isCurrentPlayerChallenger) {
      _currentChallenger = Map<String, dynamic>.from(widget.challenger);
      _currentOpponent = Map<String, dynamic>.from(widget.opponent);
    } else {
      _currentChallenger = Map<String, dynamic>.from(widget.opponent);
      _currentOpponent = Map<String, dynamic>.from(widget.challenger);
    }

    if (widget.isObserver) {
      _combatMessage = 'Combat en cours...';
      _isYourTurn = false;
    } else {
      _isYourTurn = isCurrentPlayerChallenger;

      if (_isYourTurn) {
        _combatMessage = "C'est à votre tour de jouer!";
      } else {
        final opponentName =
            _currentOpponent?['name'] as String? ?? 'Adversaire';
        _combatMessage = '$opponentName est en train de jouer.';
      }
    }

    _listenToCombatEvents();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  void _listenToCombatEvents() {
    _subscriptions
      ..add(
        SocketService().listen<dynamic>('yourTurnCombat').listen((_) {
          if (!mounted || widget.isObserver) return;
          setState(() {
            _isYourTurn = true;
            _combatMessage = "C'est à votre tour de jouer!";
          });
        }),
      )
      ..add(
        SocketService().listen<dynamic>('playerTurnCombat').listen((_) {
          if (!mounted || widget.isObserver) return;
          setState(() {
            _isYourTurn = false;
            final opponentName =
                _currentOpponent?['name'] as String? ?? 'Adversaire';
            _combatMessage = '$opponentName est en train de jouer.';
          });
        }),
      )
      ..add(
        SocketService().listen<int>('combatSecondPassed').listen((time) {
          if (!mounted) return;
          setState(() {
            _countdown = time;
          });
        }),
      )
      ..add(
        SocketService().listen<dynamic>('diceRolled').listen((data) {
          if (!mounted) return;
          if (data is Map<String, dynamic>) {
            final attackDice = data['attackDice'] as int?;
            final defenseDice = data['defenseDice'] as int?;

            setState(() {
              if (_isYourTurn) {
                _attackDice = attackDice;
                _defenseDice = defenseDice;
                _attacking = true;
              } else {
                _attackDice = defenseDice;
                _defenseDice = attackDice;
                _attacking = false;
              }
            });
          }
        }),
      )
      ..add(
        SocketService().listen<dynamic>('attackSuccess').listen((data) {
          if (!mounted) return;
          if (data is Map<String, dynamic>) {
            final playerSocketId = data['socketId'] as String?;
            final playerName = data['name'] as String?;

            setState(() {
              if (playerSocketId == _currentOpponent?['socketId']) {
                _currentOpponent = data;
                if (widget.isObserver) {
                  final attackerName =
                      _currentChallenger?['name'] as String? ?? 'Joueur';
                  _combatMessage = '$attackerName a attaqué $playerName';
                } else {
                  _combatMessage = 'Vous avez attaqué $playerName';
                }
              } else if (playerSocketId == _currentChallenger?['socketId']) {
                _currentChallenger = data;
                if (widget.isObserver) {
                  final attackerName =
                      _currentOpponent?['name'] as String? ?? 'Adversaire';
                  _combatMessage = '$attackerName a attaqué $playerName';
                } else {
                  final opponentName =
                      _currentOpponent?['name'] as String? ?? 'Adversaire';
                  _combatMessage = '$opponentName vous a attaqué';
                }
              }
            });
          }
        }),
      )
      ..add(
        SocketService().listen<dynamic>('attackFailure').listen((data) {
          if (!mounted) return;
          if (data is Map<String, dynamic>) {
            final playerSocketId = data['socketId'] as String?;
            final playerName = data['name'] as String?;

            setState(() {
              if (widget.isObserver) {
                _combatMessage = '$playerName a survécu à une attaque';
              } else {
                if (playerSocketId == _currentOpponent?['socketId']) {
                  _combatMessage = '$playerName a survécu à votre attaque';
                } else {
                  _combatMessage = 'Vous avez survécu à une attaque';
                }
              }
            });
          }
        }),
      )
      ..add(
        SocketService().listen<dynamic>('evasionSuccess').listen((data) {
          if (!mounted) return;
          if (data is Map<String, dynamic>) {
            final currentPlayer = PlayerService().player;
            if (currentPlayer.socketId == data['socketId']) {
              PlayerService().setPlayerFromJson(data);
            }
          }
        }),
      )
      ..add(
        SocketService().listen<dynamic>('evasionFailed').listen((data) {
          if (!mounted) return;
          if (data is Map<String, dynamic>) {
            final currentPlayer = PlayerService().player;
            if (currentPlayer.socketId == data['socketId']) {
              PlayerService().setPlayerFromJson(data);
            }
          }
        }),
      );
  }

  void _attack() {
    if (_isYourTurn && !widget.isObserver) {
      SocketService().send('attack', widget.gameId);
      setState(() {
        _isYourTurn = false;
      });
    }
  }

  void _evade() {
    if (_isYourTurn && !widget.isObserver) {
      SocketService().send('startEvasion', widget.gameId);
      setState(() {
        _isYourTurn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Player>(
      valueListenable: PlayerService().notifier,
      builder: (context, currentPlayer, _) {
        final isMyTurn = _isYourTurn && !widget.isObserver;
        final evasionsLeft = currentPlayer.specs.evasions;
        final isObserver = widget.isObserver;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withValues(alpha: 0.85),
          child: Center(
            child: Container(
              width: 900,
              height: 550,
              padding: const EdgeInsets.all(24),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ThemeBackground(pageId: 'combat'),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCombatPlayer(_currentChallenger!, true),
                          Column(
                            children: [
                              Text(
                                'VS',
                                style: TextStyle(
                                  color:
                                      isDark
                                          ? AppColors.textDark
                                          : AppColors.textLight,
                                  fontSize: 50,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$_countdown',
                                style: TextStyle(
                                  color: AppColors.accentHighlight(context),
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_attackDice != null ||
                                  _defenseDice != null) ...[
                                const SizedBox(height: 40),
                                Row(
                                  children: [
                                    if (_attackDice != null)
                                      _buildDice(_attackDice!, _attacking),
                                    const SizedBox(width: 40),
                                    if (_defenseDice != null)
                                      _buildDice(_defenseDice!, !_attacking),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          _buildCombatPlayer(_currentOpponent!, false),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? Colors.black45
                                  : Colors.white.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _combatMessage.isEmpty
                              ? 'Le combat est en cours...'
                              : _combatMessage,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 16,
                            fontWeight:
                                isMyTurn && !widget.isObserver
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (!isObserver)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: isMyTurn ? _attack : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isMyTurn
                                        ? AppColors.accentHighlight(context)
                                        : Colors.grey,
                                disabledBackgroundColor: Colors.grey,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                'Attaquer',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed:
                                  (isMyTurn && evasionsLeft > 0)
                                      ? _evade
                                      : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    (isMyTurn && evasionsLeft > 0)
                                        ? AppColors.accentHighlight(context)
                                        : Colors.grey,
                                disabledBackgroundColor: Colors.grey,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 14,
                                ),
                              ),
                              child: Text(
                                'Évasion ($evasionsLeft)',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (isObserver)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? Colors.black45
                                    : Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Combat en cours...',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDice(int value, bool isAttack) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black45 : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        value.toString(),
        style: TextStyle(
          color: textColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCombatPlayer(Map<String, dynamic> player, bool isLeft) {
    final name = player['name'] as String? ?? 'Joueur';

    final avatar = player['avatar'];
    final avatarValue =
        avatar is Map ? (avatar['value'] ?? '1') : (avatar ?? '1');

    final specs = player['specs'] as Map<String, dynamic>?;
    final life = (specs?['life'] as int?) ?? 0;
    final displayLife = life < 0 ? 0 : life;
    final attack = specs?['attack'] ?? 0;
    final defense = specs?['defense'] ?? 0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
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
              child: Text(
                '$displayLife PV',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 200,
          height: 200,
          child: Image.asset(
            'lib/assets/characters/$avatarValue.png',
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color:
                isDark ? Colors.black45 : Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            name,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color:
                isDark ? Colors.black45 : Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Attaque : $attack',
            style: TextStyle(color: textColor, fontSize: 14),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color:
                isDark ? Colors.black45 : Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Défense : $defense',
            style: TextStyle(color: textColor, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
