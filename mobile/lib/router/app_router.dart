import 'package:go_router/go_router.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/main.dart';
import 'package:mobile/screens/account_screen.dart';
import 'package:mobile/screens/character_creation_screen.dart';
import 'package:mobile/screens/endgame_screen.dart';
import 'package:mobile/screens/game_screen.dart';
import 'package:mobile/screens/gamecreation_screen.dart';
import 'package:mobile/screens/join_game_screen.dart';
import 'package:mobile/screens/waiting_room_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/join-game',
        name: 'join-game',
        builder: (context, state) => const JoinGameScreen(),
      ),
      GoRoute(
        path: '/:gameId/waiting-room/player',
        name: 'waiting-room',
        builder: (context, state) {
          final gameId = state.pathParameters['gameId'];
          final extra = state.extra;

          GameSettings? settings;
          if (extra is GameSettings) {
            settings = extra;
          } else if (extra is Map<String, dynamic>) {
            settings = extra['settings'] as GameSettings?;
          }

          return WaitingRoomScreen(
            gameId: gameId,
            gameSettings: settings,
          );
        },
      ),
      GoRoute(
        path: '/:mapName/waiting-room/host',
        name: 'waiting-room-host',
        builder: (context, state) {
          final mapName = state.pathParameters['mapName'];
          final extra = state.extra;

          GameSettings? settings;
          if (extra is GameSettings) {
            settings = extra;
          } else if (extra is Map<String, dynamic>) {
            settings = extra['settings'] as GameSettings?;
          }

          return WaitingRoomScreen(
            mapName: mapName,
            gameSettings: settings,
          );
        },
      ),
      GoRoute(
        path: '/:gameId/choose-character',
        name: 'choose-character',
        builder: (context, state) {
          final code = state.pathParameters['gameId'] ?? '';
          final extra = state.extra;

          GameSettings? settings;
          var isObserver = false;
          String? mapName;

          if (extra is Map<String, dynamic>) {
            settings = extra['settings'] as GameSettings?;
            isObserver = extra['isObserver'] as bool? ?? false;
            mapName = extra['mapName'] as String?;
          } else if (extra is GameSettings) {
            settings = extra;
          }

          return CharacterCreationScreen(
            gameId: code,
            mapName: mapName,
            gameSettings: settings,
            isObserver: isObserver,
          );
        },
      ),
      GoRoute(
        path: '/create-game',
        name: 'create-game',
        builder: (context, state) => const GameCreationScreen(),
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder:
            (context, state) =>
                AuthScreen(initialTab: state.queryParameters['tab']),
      ),
      GoRoute(
        path: '/game/:gameId/:mapName',
        name: 'game',
        builder: (context, state) {
          final gameId = state.pathParameters['gameId'] ?? '';
          final mapName = state.pathParameters['mapName'] ?? '';
          return GameScreen(gameId: gameId, mapName: mapName);
        },
      ),
      GoRoute(
        path: '/create-game/:mapName/choose-character',
        builder: (context, state) {
          final mapName = state.pathParameters['mapName'] ?? '';
          final extra = state.extra;

          GameSettings? settings;
          if (extra is GameSettings) {
            settings = extra;
          }

          return CharacterCreationScreen(
            mapName: mapName,
            gameSettings: settings,
          );
        },
      ),
      GoRoute(
        path: '/endgame/:gameId',
        name: 'endgame',
        builder: (context, state) {
          final gameId = state.pathParameters['gameId'] ?? '';
          final extra = state.extra;

          if (extra is Map<String, dynamic>) {
            final game = extra['game'] as GameClassic;
            final moneyReward = extra['moneyReward'] as int? ?? 0;
            return EndgameScreen(
              gameId: gameId,
              game: game,
              moneyReward: moneyReward,
            );
          } else {
            final game = extra! as GameClassic;
            return EndgameScreen(gameId: gameId, game: game);
          }
        },
      ),
    ],
  );
}
