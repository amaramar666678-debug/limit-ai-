import 'package:flutter/material.dart';
import 'state/app_state.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

void main() {
  runApp(const LimitAIApp());
}

class LimitAIApp extends StatefulWidget {
  const LimitAIApp({super.key});

  @override
  State<LimitAIApp> createState() => _LimitAIAppState();
}

class _LimitAIAppState extends State<LimitAIApp> {
  late final AppState state;

  @override
  void initState() {
    super.initState();
    state = AppState();
    state.init();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Limit AI',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: AppShell(state: state),
    );
  }
}
