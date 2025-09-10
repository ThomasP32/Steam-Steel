import 'package:go_router/go_router.dart';
import 'package:mobile/main.dart';
import 'package:mobile/screens/account_screen.dart';
import 'package:mobile/screens/character_creation_screen.dart';
import 'package:mobile/screens/gamecreation_screen.dart';
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
        path: '/:gameId/waiting-room/player',
        name: 'waiting-room',
        builder: (context, state) {
          final code = state.pathParameters['gameId'] ?? '';
          return WaitingRoomScreen(gameId: code);
        },
      ),
      GoRoute(
        path: '/:gameId/choose-character',
        name: 'choose-character',
        builder: (context, state) {
          final code = state.pathParameters['gameId'] ?? '';
          return CharacterCreationScreen(gameId: code);
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
        builder: (context, state) => const AuthScreen(),
      ),
    ],
  );
}
