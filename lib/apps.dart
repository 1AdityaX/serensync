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
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          ),
          body: appsAsyncValue.when(
              loading: () {},
              error: (error, stacktrace) {
                return null;
              },
              data: (apps) {
                return ListView.builder(
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(
                        apps[index].appName,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      onTap: () =>
                          {DeviceApps.openApp(apps[index].packageName)},
                    );
                  },
                  padding: const EdgeInsets.only(left: 20, top: 10, bottom: 30),
                );
              }));
    });
  }
}
