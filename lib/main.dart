import 'package:flutter/material.dart';
import 'services/settings_store.dart';
import 'state/app_state.dart';
import 'ui/app_shell.dart';
import 'ui/strings.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await SettingsStore.create();
  final saved = store.load();
  AppStrings.setLocale(saved.language);
  runApp(LimitAIApp(settings: store, saved: saved));
}

class LimitAIApp extends StatefulWidget {
  const LimitAIApp({super.key, this.settings, this.saved});

  final SettingsStore? settings;
  final StoredSettings? saved;

  @override
  State<LimitAIApp> createState() => _LimitAIAppState();
}

class _LimitAIAppState extends State<LimitAIApp> {
  late final AppState state;

  @override
  void initState() {
    super.initState();
    final saved = widget.saved;
    state = AppState(
      endpoint: saved?.endpoint ?? '127.0.0.1:4096',
      directory: saved?.directory ?? '',
      settings: widget.settings,
      initialModelId: saved?.modelId,
      initialProviderId: saved?.providerId,
      initialVariant: saved?.variant,
    );
    AppStrings.locale.addListener(_persistLocale);
    state.init();
  }

  Future<void> _persistLocale() async {
    await widget.settings?.save(language: AppStrings.locale.value);
  }

  @override
  void dispose() {
    AppStrings.locale.removeListener(_persistLocale);
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppStrings.locale,
      builder: (_, locale, _) => Directionality(
        textDirection: locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: MaterialApp(
          title: 'multi mause',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: AppShell(state: state),
        ),
      ),
    );
  }
}
