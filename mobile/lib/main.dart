import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/assets/theme/app_theme.dart';
import 'package:mobile/router/app_router.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:mobile/widgets/mainpage/join_game_code.dart';
import 'package:mobile/widgets/mainpage/main_page_footer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  try {
    SocketService().connect();
    DebugLogger.log('SocketService connected', tag: 'main');
  } catch (_) {}
  runApp(const MobileApp());
}

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Steam & Steel Battlegrounds',
      routerConfig: AppRouter.router,
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showJoinModal(BuildContext context) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Entrez le code de la partie'),
            content: JoinGameCode(
              onJoin: (code) {
                Navigator.of(ctx).pop();
                // Navigate to the game lobby / waiting room
                try {
                  context.go('/game/$code');
                } catch (_) {
                  // ignore navigation errors in case router isn't set up yet
                }
              },
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Debug join 2633',
        child: const Icon(Icons.play_arrow),
        onPressed: () {
          // Build a minimal JoinGameData payload. Many fields are not required
          // server-side for addPlayerToGame name uniqueness, so keep it small.
          final socket = SocketService().socketId;
          final payload = {
            'gameId': '7357',
            'player': {
              'socketId': socket ?? 'debug-socket',
              'name': 'DebugPlayer',
              'avatar': 1,
              'isActive': true,
              'specs': {
                'life': 4,
                'evasions': 2,
                'speed': 4,
                'attack': 4,
                'defense': 4,
                'attackBonus': 4,
                'defenseBonus': 4,
                'movePoints': 3,
                'actions': 1,
                'nVictories': 0,
                'nDefeats': 0,
                'nCombats': 0,
                'nEvasions': 0,
                'nLifeTaken': 0,
                'nLifeLost': 0,
                'nItemsUsed': 0,
              },
              'inventory': <dynamic>[],
              'position': {'x': 0, 'y': 0},
              'initialPosition': {'x': 0, 'y': 0},
              'turn': 0,
              'visitedTiles': <dynamic>[],
              'profile': '',
            },
          };
          SocketService().send('joinGame', payload);
        },
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'lib/assets/backgrounds/origbig.png',
              fit: BoxFit.cover,
            ),
          ),
          Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Image.asset(
                          'lib/assets/main-menu/SteamSteel.png',
                          width: MediaQuery.of(context).size.width * 0.6,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => _showJoinModal(context),
                            child: const Text('Rejoindre une partie'),
                          ),
                          const SizedBox(width: 24),
                          TextButton(
                            onPressed: () => context.go('/create-game'),
                            child: const Text('Commencer une nouvelle partie'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
              const SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: MainPageFooter(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
