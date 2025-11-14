import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/services/player_service.dart';
import 'package:mobile/services/socket_service.dart';

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

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withValues(alpha: 0.85),
          child: Center(
            child: Container(
              width: 900,
              height: 500,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage(
                    'lib/assets/backgrounds/backgroundcombat.png',
                  ),
                  fit: BoxFit.cover,
                ),
                border: Border.all(
                  color: const Color.fromARGB(255, 19, 19, 19),
                  width: 5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCombatPlayer(_currentChallenger!, true),
                      Column(
                        children: [
                          const Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 50,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$_countdown',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_attackDice != null || _defenseDice != null) ...[
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

                  Text(
                    _combatMessage.isEmpty
                        ? 'Le combat est en cours...'
                        : _combatMessage,
                    style: TextStyle(
                      color:
                          widget.isObserver
                              ? Colors.white70
                              : (isMyTurn
                                  ? Colors.greenAccent
                                  : Colors.white70),
                      fontSize: 16,
                      fontWeight:
                          isMyTurn && !widget.isObserver
                              ? FontWeight.bold
                              : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: (isMyTurn && !isObserver) ? _attack : null,
                        style: ElevatedButton.styleFrom(
                          disabledBackgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 14,
                          ),
                        ),
                        child: const Text(
                          'Attaquer',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed:
                            (isMyTurn && !isObserver && evasionsLeft > 0)
                                ? _evade
                                : null,
                        style: ElevatedButton.styleFrom(
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDice(int value, bool isAttack) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Text(
        value.toString(),
        style: const TextStyle(
          color: Colors.white,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$displayLife PV',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
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
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Attaque : $attack',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        Text(
          'Défense : $defense',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }
}
