import 'package:go_router/go_router.dart';
import 'package:mobile/main.dart';
import 'package:mobile/screens/game_screen.dart';

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
        path: '/game',
        name: 'game',
        builder: (context, state) => const GameScreen(),
      ),
    ],
  );
}
