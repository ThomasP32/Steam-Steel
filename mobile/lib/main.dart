import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/assets/theme/app_theme.dart';
import 'package:mobile/models/user_models.dart' show UserStatus;
import 'package:mobile/router/app_router.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/friend_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/services/theme_service.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:mobile/widgets/chat_widget.dart';
import 'package:mobile/widgets/friends/friend_button.dart';
import 'package:mobile/widgets/game/game_invitation_listener.dart';
import 'package:mobile/widgets/mainpage/account_button.dart';
import 'package:mobile/widgets/mainpage/main_page_footer.dart';
import 'package:mobile/widgets/mainpage/shop_widget.dart';
import 'package:mobile/widgets/theme/theme_widget.dart';
import 'package:provider/provider.dart';

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

        FriendService().updateUserStatus(UserStatus.online);
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

class MobileApp extends StatefulWidget {
  const MobileApp({super.key});

  @override
  State<MobileApp> createState() => _MobileAppState();
}

class _MobileAppState extends State<MobileApp> {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.init();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _themeService,
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'Steam & Steel Battlegrounds',
            routerConfig: AppRouter.router,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeService.isLight ? ThemeMode.light : ThemeMode.dark,
            builder: (context, child) {
              return GameInvitationListener(
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const Positioned.fill(child: ThemeBackground(pageId: 'home')),
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
                                            () => context.go('/join-game'),
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
                                        onPressed: () {
                                          showDialog<void>(
                                            context: context,
                                            builder:
                                                (context) => const ShopWidget(),
                                          );
                                        },
                                        child: const Text('Boutique'),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [AccountButton(), FriendButton(), ChatWidget()],
                  ),
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
