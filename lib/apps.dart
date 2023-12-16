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
    return Consumer(builder: (context, ref, child) {
      final appsAsyncValue = ref.watch(appsProvider);
      return Scaffold(
          appBar: AppBar(
            title: Container(
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
                      builder: (BuildContext context, bool isFocused,
                          Widget? child) {
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
                            _focusNode.hasFocus
                                ? Icons.arrow_back
                                : Icons.search,
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
            ),
          ),
          body: appsAsyncValue.when(loading: () {
            return null;
          }, error: (error, stacktrace) {
            return null;
          }, data: (apps) {
            final filteredApps = apps
                .where((app) => app.appName
                    .toLowerCase()
                    .contains(_controller.text.toLowerCase()))
                .toList();
            return ListView.builder(
              itemCount: filteredApps.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    filteredApps[index].appName,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  onTap: () => {
                    DeviceApps.openApp(filteredApps[index].packageName),
                    setState(() {
                      _controller.clear();
                      _focusNode.unfocus();
                    }),
                  },
                );
              },
              padding: const EdgeInsets.only(left: 20),
            );
          }));
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    _isFocused.dispose();
    super.dispose();
  }
}
