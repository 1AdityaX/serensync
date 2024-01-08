import 'package:flutter/material.dart';
import 'package:serensync/apps.dart';
import 'package:serensync/home.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(
                surfaceTintColor: Colors.black, backgroundColor: Colors.black),
            listTileTheme: const ListTileThemeData(
              iconColor: Colors.white,
              tileColor: Colors.black,
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
            ),
            dialogTheme: const DialogTheme(backgroundColor: Colors.black)),
        home: HomePage(),
        routes: {
          "apps": (_) => const AppsPage(),
        });
  }
}

class HomePage extends StatelessWidget {
  final PageController _pageController = PageController();

  HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: const [HomeContent(), AppsPage()],
      ),
    );
  }
}

//TODO: Monochrome mode app uninstall install update