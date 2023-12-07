import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:serensync/helpers/app_state.dart';

class AppsPage extends StatefulWidget {
  const AppsPage({super.key});

  @override
  _AppListScreenState createState() => _AppListScreenState();
}

class _AppListScreenState extends State<AppsPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final appsAsyncValue = ref.watch(appsProvider);
      return Scaffold(
          appBar: AppBar(
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 25, 25, 25),
                borderRadius: BorderRadius.circular(23),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white70),
                  const SizedBox(
                      width: 8), // Add some space between icon and textfield
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search Apps',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.white70),
                      ),
                      onChanged: (query) {
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: appsAsyncValue.when(loading: () {
            return null;
          }, error: (error, stacktrace) {
            return null;
          }, data: (apps) {
            return ListView.builder(
              itemCount: apps.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    apps[index].appName,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  onTap: () => {DeviceApps.openApp(apps[index].packageName)},
                );
              },
              padding: const EdgeInsets.only(left: 20, bottom: 30),
            );
          }));
    });
  }
}
