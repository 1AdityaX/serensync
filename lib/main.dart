import 'dart:async';

import 'package:flutter/material.dart';

import 'apps/app_service.dart';
import 'launcher/apps_screen.dart';
import 'launcher/home/home_screen.dart';
import 'launcher/launcher_controller.dart';
import 'main_app/blocking/block_overlay.dart';
import 'main_app/blocking/blocking_engine.dart';
import 'main_app/blocking/onboarding/permission_status.dart';
import 'main_app/blocking/rule_store.dart';
import 'main_app/dashboard_screen.dart';
import 'main_app/onboarding/onboarding_screen.dart';
import 'main_app/onboarding/onboarding_store.dart';
import 'main_app/pomodoro/pomodoro_store.dart';
import 'main_app/strict/strict_mode_store.dart';

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
  final RuleStore ruleStore;
  final OnboardingStore onboardingStore;
  final PermissionStatus permissionStatus;
  final BlockingService blockingService;
  final PomodoroStore pomodoroStore;
  final StrictModeStore strictModeStore;

  MyApp({
    super.key,
    AppService? appService,
    LauncherController? launcherController,
    RuleStore? ruleStore,
    OnboardingStore? onboardingStore,
    PermissionStatus? permissionStatus,
    BlockingService? blockingService,
    PomodoroStore? pomodoroStore,
    StrictModeStore? strictModeStore,
  }) : appService = appService ?? AppService(),
       launcherController = launcherController ?? LauncherController(),
       ruleStore = ruleStore ?? RuleStore(),
       onboardingStore = onboardingStore ?? OnboardingStore(),
       permissionStatus = permissionStatus ?? PermissionStatus(),
       blockingService = blockingService ?? BlockingService(),
       pomodoroStore = pomodoroStore ?? PomodoroStore(),
       strictModeStore = strictModeStore ?? StrictModeStore();

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
        navigationBarTheme: const NavigationBarThemeData(
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
        ruleStore: ruleStore,
        onboardingStore: onboardingStore,
        permissionStatus: permissionStatus,
        blockingService: blockingService,
        pomodoroStore: pomodoroStore,
        strictModeStore: strictModeStore,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final AppService appService;
  final LauncherController launcherController;
  final RuleStore ruleStore;
  final OnboardingStore onboardingStore;
  final PermissionStatus permissionStatus;
  final BlockingService blockingService;
  final PomodoroStore pomodoroStore;
  final StrictModeStore strictModeStore;

  const MainScreen({
    super.key,
    required this.appService,
    required this.launcherController,
    required this.ruleStore,
    required this.onboardingStore,
    required this.permissionStatus,
    required this.blockingService,
    required this.pomodoroStore,
    required this.strictModeStore,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool? _showLauncher;
  bool? _onboarded;

  @override
  void initState() {
    super.initState();
    widget.launcherController.listenForPresentationChanges(_setPresentation);
    _readInitialPresentation();
  }

  Future<void> _readInitialPresentation() async {
    final showLauncher = await widget.launcherController.openedAsLauncher;
    final onboarded = await widget.onboardingStore.isComplete;
    if (!mounted) return;
    setState(() {
      _showLauncher = showLauncher;
      _onboarded = onboarded;
    });
  }

  Future<void> _completeOnboarding() async {
    await widget.onboardingStore.markComplete();
    if (mounted) setState(() => _onboarded = true);
  }

  void _setPresentation(bool showLauncher) {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _showLauncher = showLauncher);
  }

  @override
  Widget build(BuildContext context) {
    final showLauncher = _showLauncher;
    final onboarded = _onboarded;
    if (showLauncher == null || onboarded == null) {
      return const Scaffold(body: SizedBox.expand());
    }
    if (!showLauncher && !onboarded) {
      return OnboardingScreen(
        permissionStatus: widget.permissionStatus,
        onFinished: () => unawaited(_completeOnboarding()),
      );
    }
    if (!showLauncher) {
      return DashboardScreen(
        appService: widget.appService,
        ruleStore: widget.ruleStore,
        blockingService: widget.blockingService,
        permissionStatus: widget.permissionStatus,
        pomodoroStore: widget.pomodoroStore,
        strictModeStore: widget.strictModeStore,
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
