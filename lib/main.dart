import 'package:flutter/material.dart';

import 'apps/app_service.dart';
import 'apps/apps_screen.dart';
import 'blocking/block_overlay.dart';
import 'blocking/blocking_engine.dart';
import 'home/home_screen.dart';

void main() {
  initializeBlockingService();
  runApp(MyApp());
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BlockOverlayApp());
}

class MyApp extends StatelessWidget {
  final AppService appService;

  MyApp({super.key, AppService? appService})
    : appService = appService ?? AppService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          surfaceTintColor: Colors.black,
          backgroundColor: Colors.black,
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: Colors.white,
          tileColor: Colors.black,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        ),
        dialogTheme: const DialogThemeData(backgroundColor: Colors.black),
      ),
      home: MainScreen(appService: appService),
    );
  }
}

class MainScreen extends StatefulWidget {
  final AppService appService;

  const MainScreen({super.key, required this.appService});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentPage != 0) {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: (page) => _currentPage = page,
          children: <Widget>[
            const HomeScreen(),
            AppsScreen(appService: widget.appService),
          ],
        ),
      ),
    );
  }
}
