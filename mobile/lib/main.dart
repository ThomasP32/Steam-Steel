import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/assets/theme/app_theme.dart';
import 'package:mobile/router/app_router.dart';

void main() {
  runApp(MobileApp()); //TODO: MAKE CONST
}

class MobileApp extends StatelessWidget {
  MobileApp({super.key});
  final AppRouter appRouter = AppRouter();

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
      appBar: AppBar(title: const Text('Steam & Steel Battlegrounds')),
      backgroundColor: Colors.black,
      body: Center(
        child: ElevatedButton(
          onPressed: () => context.go('/game'),
          child: const Text('Game Screen'),
        ),
      ),
    );
  }
}
