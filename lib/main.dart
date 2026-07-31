import 'package:flutter/material.dart';

import 'apps/app_service.dart';
import 'apps/apps_screen.dart';
import 'blocking/block_overlay.dart';
import 'blocking/blocking_engine.dart';
import 'home/home_screen.dart';
import 'launcher/launcher_controller.dart';
import 'main_app/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  final LauncherController launcherController;

  MyApp({
    super.key,
    AppService? appService,
    LauncherController? launcherController,
  }) : appService = appService ?? AppService(),
       launcherController = launcherController ?? LauncherController();

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
      home: MainScreen(
        appService: appService,
        launcherController: launcherController,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final AppService appService;
  final LauncherController launcherController;

  const MainScreen({
    super.key,
    required this.appService,
    required this.launcherController,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool? _showLauncher;

  @override
  void initState() {
    super.initState();
    widget.launcherController.listenForPresentationChanges(_setPresentation);
    _readInitialPresentation();
  }

  Future<void> _readInitialPresentation() async {
    final showLauncher = await widget.launcherController.openedAsLauncher;
    if (mounted) setState(() => _showLauncher = showLauncher);
  }

  void _setPresentation(bool showLauncher) {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _showLauncher = showLauncher);
  }

  @override
  Widget build(BuildContext context) {
    final showLauncher = _showLauncher;
    if (showLauncher == null) {
      return const Scaffold(body: SizedBox.expand());
    }
    if (!showLauncher) {
      return DashboardScreen(
        appService: widget.appService,
        launcherController: widget.launcherController,
      );
    }
    return LauncherScreen(
      appService: widget.appService,
      onOpenMainApp: () => _setPresentation(false),
    );
  }

  @override
  void dispose() {
    widget.launcherController.stopListening();
    super.dispose();
  }
}

class LauncherScreen extends StatefulWidget {
  final AppService appService;
  final VoidCallback onOpenMainApp;

  const LauncherScreen({
    super.key,
    required this.appService,
    required this.onOpenMainApp,
  });

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen> {
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
            AppsScreen(
              appService: widget.appService,
              onOpenSerenSync: widget.onOpenMainApp,
            ),
          ],
        ),
      ),
    );
  }
}
