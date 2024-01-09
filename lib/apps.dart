import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:serensync/helpers/app_state.dart';

class AppsPage extends StatefulWidget {
  const AppsPage({super.key});

  @override
  AppListScreenState createState() => AppListScreenState();
}

class AppListScreenState extends State<AppsPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ValueNotifier<bool> _isFocused = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      _isFocused.value = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: _searchBar(),
        ),
        body: _appsList());
  }

  Widget _searchBar() {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 25, 25, 25),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          ValueListenableBuilder(
              valueListenable: _isFocused,
              builder: (BuildContext context, bool isFocused, Widget? child) {
                return IconButton(
                  onPressed: () {
                    if (isFocused) {
                      setState(() {
                        _focusNode.unfocus();
                        _controller.clear();
                      });
                    } else {
                      _focusNode.requestFocus();
                    }
                  },
                  icon: Icon(
                    _focusNode.hasFocus ? Icons.arrow_back : Icons.search,
                    color: Colors.white70,
                  ),
                );
              }),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                hintText: 'Search Apps',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white70),
              ),
              onChanged: (query) {
                setState(() {
                  _controller.text = query;
                });
              },
            ),
          ),
          IconButton(
              icon: _controller.text.isEmpty
                  ? const Icon(Icons.settings)
                  : const Icon(Icons.clear),
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  setState(() {
                    _controller.clear();
                  });
                } else {
                  _focusNode.unfocus();
                }
              })
        ],
      ),
    );
  }

  Widget _appsList() {
    return Consumer(
      builder: (context, ref, child) {
        final appsAsyncValue = ref.watch(appsProvider);
        return appsAsyncValue.when(loading: () {
          return const Center(child: CircularProgressIndicator());
        }, error: (error, stackTrace) {
          return const Center(child: Text('Error'));
        }, data: (apps) {
          final filteredApps = apps
              .where((app) => app.appName
                  .toLowerCase()
                  .contains(_controller.text.toLowerCase()))
              .toList();
          return ListView.builder(
            itemCount: filteredApps.length,
            itemBuilder: (buildContext, index) {
              return ListTile(
                title: Text(
                  filteredApps[index].appName,
                ),
                onTap: () => {
                  DeviceApps.openApp(filteredApps[index].packageName),
                  setState(() {
                    _controller.clear();
                    _focusNode.unfocus();
                  }),
                },
                onLongPress: () => showPopupDialog(filteredApps[index]),
              );
            },
            padding: const EdgeInsets.only(left: 20),
          );
        });
      },
    );
  }

  Future<void> showPopupDialog(Application app) async => showDialog(
      context: context,
      builder: (context) => Dialog(
              child: Container(
            padding: const EdgeInsets.all(0),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.white), color: Colors.black),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white),
                    ),
                    child: ListTile(
                      title: Center(child: Text(app.appName)),
                    ),
                  ),
                  Material(
                    child: ListTile(
                        title: const Text('Settings'),
                        leading: const Icon(Icons.settings_outlined),
                        onTap: () {
                          DeviceApps.openAppSettings(app.packageName);
                          Navigator.of(context).pop();
                        }),
                  ),
                  Material(
                    child: ListTile(
                      title: const Text('Uninstall'),
                      leading: const Icon(Icons.delete_outline),
                      onTap: () {
                        DeviceApps.uninstallApp(app.packageName);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  Material(
                    child: ListTile(
                      title: const Text('Hide app'),
                      leading: const Icon(Icons.visibility_off_outlined),
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  Material(
                    child: ListTile(
                      title: const Text('Lock App'),
                      leading: const Icon(Icons.lock_outline),
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ]),
          )));

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    _isFocused.dispose();
    super.dispose();
  }
}
