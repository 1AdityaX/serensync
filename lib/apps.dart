import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppsPage extends StatefulWidget {
  const AppsPage({super.key});

  @override
  _AppListScreenState createState() => _AppListScreenState();
}

class _AppListScreenState extends State<AppsPage> {
  Provider<List<Application>> _apps = Provider((ref) => []);

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    List<Application> apps = await DeviceApps.getInstalledApplications(
      onlyAppsWithLaunchIntent: true,
      includeSystemApps: true,
    );

    apps.sort((a, b) => a.appName.compareTo(b.appName));
    setState(() {
      _apps = Provider((ref) => apps);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final __apps = ref.watch(_apps);
      return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: ListView.builder(
        itemCount: __apps.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(
              __apps[index].appName,
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            onTap: () => {DeviceApps.openApp(__apps[index].packageName)},
          );
        },
        padding: const EdgeInsets.only(left: 20, top: 10, bottom: 30),
      ),
    );
    });
  }
}
