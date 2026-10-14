import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Creates the API client only after runtime configuration has been loaded.
class RuntimeBootstrap extends StatefulWidget {
  const RuntimeBootstrap({
    super.key,
    required this.load,
    required this.appBuilder,
  });
  final Future<String> Function() load;
  final Widget Function(String apiUrl) appBuilder;

  @override
  State<RuntimeBootstrap> createState() => _RuntimeBootstrapState();
}

class _RuntimeBootstrapState extends State<RuntimeBootstrap> {
  String? _apiUrl;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final url = await widget.load().timeout(const Duration(seconds: 15));
      if (mounted) setState(() => _apiUrl = url);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_apiUrl != null) return widget.appBuilder(_apiUrl!);
    return MaterialApp(
      title: 'SecretPod',
      debugShowCheckedModeBanner: false,
      theme: secretPodTheme(Brightness.light),
      darkTheme: secretPodTheme(Brightness.dark),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Brand(large: true),
                  const SizedBox(height: 28),
                  if (_failed) ...[
                    const Text('Unable to load application configuration.'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ] else ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Connecting to SecretPod…'),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
