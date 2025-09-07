import 'package:go_router/go_router.dart';
import 'package:mobile/main.dart';
import 'package:mobile/screens/gamecreation_screen.dart';
import 'package:mobile/screens/joingame_screen.dart';

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
      // GoRoute(
      //   path: '/game/:code',
      //   name: 'game',
      //   builder: (context, state) {
      //     final code = state.pathParameters['code'] ?? '';
      //     return JoinGameScreen(initialCode: code, autoJoin: true);
      //   },
      // ),
      GoRoute(
        path: '/create-game',
        name: 'create-game',
        builder: (context, state) => const GameCreationScreen(),
      ),
    ],
  );
}
