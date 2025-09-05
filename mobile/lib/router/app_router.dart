import 'package:go_router/go_router.dart';
import 'package:mobile/main.dart';
import 'package:mobile/screens/joingame_screen.dart';

// Defines the application router using GoRouter

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
    ],
  );
}
