import 'package:flutter/material.dart';

import 'apps/app_service.dart';
import 'apps/apps_screen.dart';
import 'home/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final AppService appService;

  const MyApp({super.key, this.appService = const AppService()});

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
    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: <Widget>[
          HomeScreen(appService: widget.appService),
          AppsScreen(appService: widget.appService),
        ],
      ),
    );
  }
}
