import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/assets/theme/app_theme.dart';
import 'package:mobile/router/app_router.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:mobile/widgets/chat_widget.dart';
import 'package:mobile/widgets/mainpage/join_game_code.dart';
import 'package:mobile/widgets/mainpage/main_page_footer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  try {
    DebugLogger.log('Resolved API baseUrl: ${ApiClient.baseUrl}', tag: 'main');
    const storage = FlutterSecureStorage();
    final stored = await storage.read(key: 'authToken');
    DebugLogger.log(
      'Persisted authToken (start): ${stored == null ? 'null' : '${stored.substring(0, 8)}...'}',
      tag: 'main',
    );
  } on Exception catch (e) {
    DebugLogger.log('Debug startup read failed: $e', tag: 'main');
  }
  try {
    await setupUserAndGlobalChat();
  } on Object catch (e) {
    DebugLogger.log('setupUserAndGlobalChat failed: $e', tag: 'main');
  }

  try {
    final token = await AuthService().token;
    if (token == null) {
      DebugLogger.log(
        'No auth token found; skipping SocketService.connect',
        tag: 'main',
      );
    } else {
      await SocketService().connect();
      DebugLogger.log('SocketService connected', tag: 'main');
      try {
        SocketService().send('joinChatRoom', 'global');
      } on Object catch (e) {
        DebugLogger.log(
          'Failed to send joinChatRoom after connect: $e',
          tag: 'main',
        );
      }
    }
  } on Object catch (e) {
    DebugLogger.log('SocketService.connect failed: $e', tag: 'main');
  }
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } on Object catch (e) {
    DebugLogger.log('Failed to set preferred orientations: $e', tag: 'main');
  }

  runApp(const MobileApp());
}

Future<void> setupUserAndGlobalChat() async {
  try {
    await AuthService().fetchUser();
  } on Object catch (e) {
    DebugLogger.log('AuthService.fetchUser error: $e', tag: 'main');
  }
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
            content: JoinGameCode(onJoin: (code) {}),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
                      ValueListenableBuilder(
                        valueListenable: AuthService().notifier,
                        builder: (context, user, _) {
                          final loggedIn = user != null;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children:
                                loggedIn
                                    ? [
                                      TextButton(
                                        onPressed:
                                            () => _showJoinModal(context),
                                        child: const Text(
                                          'Rejoindre une partie',
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      TextButton(
                                        onPressed:
                                            () => context.go('/create-game'),
                                        child: const Text(
                                          'Commencer une nouvelle partie',
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      TextButton(
                                        onPressed: () => context.go('/auth'),
                                        child: const Text('Compte'),
                                      ),
                                    ]
                                    : [
                                      TextButton(
                                        onPressed:
                                            () => context.go(
                                              '/auth?tab=register',
                                            ),
                                        child: const Text('Inscription'),
                                      ),
                                      const SizedBox(width: 24),
                                      TextButton(
                                        onPressed:
                                            () => context.go('/auth?tab=login'),
                                        child: const Text('Se connecter'),
                                      ),
                                    ],
                          );
                        },
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
          ValueListenableBuilder(
            valueListenable: AuthService().notifier,
            builder: (context, user, _) {
              if (user != null) {
                return const Positioned(
                  top: 18,
                  right: 12,
                  child: ChatWidget(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
