import 'package:flutter/material.dart';
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
  // Debug: log the resolved API base URL and any persisted auth token
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
    await SocketService().connect();
    DebugLogger.log('SocketService connected', tag: 'main');
  } on Object catch (e) {
    DebugLogger.log('SocketService.connect failed: $e', tag: 'main');
  }
  // Fetch user info and join the global chat room so mobile mirrors web behavior
  try {
    await setupUserAndGlobalChat();
  } on Object catch (e) {
    DebugLogger.log('setupUserAndGlobalChat failed: $e', tag: 'main');
  }
  runApp(const MobileApp());
}

Future<void> setupUserAndGlobalChat() async {
  try {
    await AuthService().fetchUser();
  } on Object catch (e) {
    DebugLogger.log('AuthService.fetchUser error: $e', tag: 'main');
  }

  try {
    SocketService().send('joinChatRoom', 'global');
  } on Object catch (e) {
    DebugLogger.log('Failed to send joinChatRoom: $e', tag: 'main');
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
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'lib/assets/backgrounds/origbig.png',
              fit: BoxFit.cover,
            ),
          ),
          const Positioned.fill(child: ChatWidget()),
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
        ],
      ),
    );
  }
}
