import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/assets/theme/app_theme.dart';
import 'package:mobile/router/app_router.dart';
import 'package:mobile/widgets/mainpage/main_page_footer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
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
          Column(
            children: [
              // Main content takes the available space and is centered
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'lib/assets/main-menu/SteamSteel.png',
                        width: 800,
                        height: 400,
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => context.go('/join-game'),
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
