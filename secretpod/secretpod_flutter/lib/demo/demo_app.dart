import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secretpod_client/secretpod_client.dart';
import '../main.dart';
import '../state/session_store.dart';
import '../state/invitation_link.dart';
import '../state/vault_controller.dart';
import 'demo_client.dart';
import 'demo_store.dart';

/// Entry point for the separately built playground. No server URL is loaded.
class DemoApp extends StatefulWidget {
  const DemoApp({super.key, this.store});
  final DemoStore? store;
  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  late final DemoStore _store;
  StreamSubscription<void>? _changes;
  VaultController? _controller;
  String? _epoch, _error;
  String? _sampleLink;
  bool _linkCopied = false;
  bool _confirmReset = false, _busy = false;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? createDemoStore();
    _changes = _store.changes.listen((_) => unawaited(_externalChange()));
    unawaited(_open());
  }

  Future<void> _externalChange() async {
    try {
      final epoch = await _store.access((state) => state['epoch'] as String);
      if (!mounted) return;
      if (epoch != _epoch) {
        await _open();
      } else {
        await _controller?.refresh();
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _open() async {
    try {
      final epoch = await _store.access((state) => state['epoch'] as String);
      if (!mounted) return;
      final controller = VaultController(
        'https://demo.invalid/',
        api: Client(
          'https://demo.invalid/',
          httpClientOverride: DemoClient(_store),
        ),
        sessionStore: _DemoSessionStore(),
      );
      final previous = _controller;
      setState(() {
        _epoch = epoch;
        _controller = controller;
        _error = null;
        _confirmReset = false;
        _sampleLink = null;
        _version++;
      });
      // MyApp removes its listener when replaced; avoid disposing it beforehand.
      WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (mounted) {
      setState(
        () => _error = switch (error) {
          FormatException() =>
            'Saved demo data cannot be loaded. Reset the demo to start again.',
          StateError() =>
            'This browser could not access demo storage. Allow site data and use a current browser over HTTPS or localhost. Your saved data has not been reset.',
          _ => VaultController.describeError(error),
        },
      );
    }
  }

  Future<void> _showInvitation() async {
    try {
      final token = await _store.access((state) {
        final account = (state['accounts'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((a) => a['id'] == state['accountId']);
        final invites = (state['invitations'] as List)
            .cast<Map<String, dynamic>>()
            .where(
              (i) =>
                  i['recipientEmail'] == account['email'] &&
                  i['status'] == 'pending' &&
                  DateTime.parse(
                    i['expiresAt'] as String,
                  ).isAfter(DateTime.now()),
            );
        return invites.isEmpty ? null : invites.first['token'] as String?;
      });
      if (mounted) {
        setState(() {
          _sampleLink = token == null
              ? 'No pending sample invitations. Reset demo to restore them.'
              : invitationLink(token);
          _linkCopied = false;
        });
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _reset() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _store.reset();
      await _open();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _changes?.cancel();
    _controller?.dispose();
    if (widget.store == null) _store.dispose();
    super.dispose();
  }

  Widget _banner(BuildContext context, Widget? child) => Column(
    // Keep these controls after the Navigator in semantics order: routes block
    // earlier siblings. Reverse the layout direction to keep the banner on top.
    verticalDirection: VerticalDirection.up,
    children: [
      Material(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              children: [
                Text(
                  _confirmReset
                      ? 'Discard this browser’s demo edits and restore the sample data?'
                      : 'Demo · Fictional data · Changes stay in this browser. Do not enter real secrets.',
                  textAlign: TextAlign.center,
                ),
                if (_confirmReset) ...[
                  TextButton(
                    onPressed: _busy ? null : _reset,
                    child: const Text('Confirm reset'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _confirmReset = false),
                    child: const Text('Cancel'),
                  ),
                ] else
                  TextButton(
                    onPressed: () => setState(() => _confirmReset = true),
                    child: const Text('Reset demo'),
                  ),
                TextButton(
                  onPressed: _showInvitation,
                  child: const Text('Sample invitation'),
                ),
              ],
            ),
          ),
        ),
      ),
      if (_sampleLink != null)
        Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Text(
                  'Use this link in My invitations → Accept. It works only in this browser’s demo.',
                ),
                SelectableText(_sampleLink!, textAlign: TextAlign.center),
                Wrap(
                  children: [
                    if (invitationTokenFromLink(_sampleLink!) != null)
                      TextButton(
                        onPressed: () async {
                          try {
                            await Clipboard.setData(
                              ClipboardData(text: _sampleLink!),
                            );
                            if (mounted) setState(() => _linkCopied = true);
                          } catch (_) {
                            if (mounted) setState(() => _linkCopied = false);
                          }
                        },
                        child: Text(
                          _linkCopied ? 'Copied' : 'Copy invitation link',
                        ),
                      ),
                    TextButton(
                      onPressed: () => setState(() => _sampleLink = null),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      Expanded(child: child ?? const SizedBox()),
    ].reversed.toList(),
  );

  @override
  Widget build(BuildContext context) {
    if (_error != null || _controller == null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Demo storage needs attention'),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        TextButton(
                          onPressed: _open,
                          child: const Text('Try again'),
                        ),
                        if (_confirmReset) ...[
                          const Text('This discards your demo edits.'),
                          TextButton(
                            onPressed: _busy ? null : _reset,
                            child: const Text('Confirm reset'),
                          ),
                        ] else
                          TextButton(
                            onPressed: () =>
                                setState(() => _confirmReset = true),
                            child: const Text('Reset demo'),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }
    return MyApp(
      key: ValueKey(_version),
      controller: _controller,
      builder: _banner,
      signedOutBuilder: (_) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Explore SecretPod', style: TextStyle(fontSize: 28)),
              const SizedBox(height: 12),
              const Text('A fictional team workspace, ready to try.'),
              const SizedBox(height: 20),
              FilledButton(onPressed: _open, child: const Text('Enter demo')),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoSessionStore implements SessionStore {
  String? _token = 'demo-session';
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  String? read() => _token;
  @override
  void write(String? token) => _token = token;
}
