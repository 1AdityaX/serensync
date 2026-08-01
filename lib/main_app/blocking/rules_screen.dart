import 'package:flutter/material.dart';

import '../../apps/app_service.dart';
import 'rule_store.dart';
import 'widgets/rule_list.dart';

class RulesScreen extends StatelessWidget {
  final RuleStore ruleStore;
  final AppService appService;

  const RulesScreen({
    super.key,
    required this.ruleStore,
    required this.appService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App limits')),
      body: RuleList(ruleStore: ruleStore, appService: appService),
    );
  }
}
