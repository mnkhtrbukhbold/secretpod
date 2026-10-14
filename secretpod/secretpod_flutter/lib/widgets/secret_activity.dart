import 'package:flutter/material.dart';
import 'package:secretpod_client/secretpod_client.dart';
import '../state/vault_controller.dart';
import '../state/pagination.dart';
import 'common.dart';

class SecretActivity extends StatefulWidget {
  const SecretActivity({
    super.key,
    required this.controller,
    required this.secret,
    required this.revision,
  });
  final VaultController controller;
  final SecretView secret;
  final int revision;
  @override
  State<SecretActivity> createState() => _SecretActivityState();
}

class _SecretActivityState extends State<SecretActivity> {
  List<AuditView> _events = [];
  bool _loading = true, _hasMore = false;
  String? _error;
  bool _failedMore = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SecretActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision ||
        oldWidget.secret.id != widget.secret.id) {
      _load();
    }
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    final cursor = more && _events.isNotEmpty ? _events.last.id : null;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await widget.controller.client.vault.secretActivity(
        widget.secret.organizationId,
        widget.secret.id,
        cursor,
        limit: PaginationSettings.defaultPageSize,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _events = more ? [..._events, ...events] : events;
        _hasMore = events.length == PaginationSettings.defaultPageSize;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _failedMore = more;
          _error =
              'Could not load activity. ${VaultController.describeError(e)}';
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(Icons.history, size: 20, color: context.colors.blue),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Activity',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            tooltip: 'Refresh activity',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ],
      ),
      Text(
        'Newest first · Times shown in your local time',
        style: TextStyle(color: context.colors.muted, fontSize: 12),
      ),
      const SizedBox(height: 12),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      if (_error != null)
        ErrorNotice(
          _error!,
          onRetry: _loading ? null : () => _load(more: _failedMore),
        ),
      if (!_loading && _error == null && _events.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No activity linked to this secret yet. Earlier entries remain in organization Activity.',
            style: TextStyle(color: context.colors.muted, height: 1.5),
          ),
        ),
      for (final event in _events)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: context.colors.blueContainer,
                child: Icon(
                  activityIcon(event.action),
                  color: context.colors.blue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activityLabel(event.action),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(event.actor, style: const TextStyle(fontSize: 13)),
                    if (event.version != null)
                      Text(
                        'Version ${event.version}',
                        style: TextStyle(
                          color: context.colors.muted,
                          fontSize: 12,
                        ),
                      ),
                    if (event.details != null)
                      Text(
                        event.details!,
                        style: TextStyle(
                          color: context.colors.muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      activityTime(event.createdAt),
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      if (_hasMore)
        TextButton.icon(
          onPressed: _loading ? null : () => _load(more: true),
          icon: const Icon(Icons.expand_more),
          label: const Text('Load older activity'),
        ),
    ],
  );
}

String activityLabel(String action) => switch (action) {
  'rotated' || 'updated' => 'Modified',
  'saved' => 'Saved',
  'copy requested' => 'Copy requested',
  'copied' => 'Copied',
  'revealed' => 'Revealed',
  'created' => 'Created',
  'deleted' => 'Deleted',
  'marked needs rotating' => 'Marked needs rotating',
  'cleared rotation flag' => 'Cleared rotation flag',
  'removed member' => 'Removed member',
  _ => action,
};
IconData activityIcon(String action) => switch (action) {
  'copy requested' || 'copied' => Icons.copy_outlined,
  'revealed' => Icons.visibility_outlined,
  'rotated' || 'updated' || 'saved' => Icons.edit_outlined,
  'deleted' => Icons.delete_outline,
  'marked needs rotating' ||
  'cleared rotation flag' => Icons.change_circle_outlined,
  'removed member' => Icons.person_remove_outlined,
  _ => Icons.history,
};
String activityTime(DateTime time) {
  final local = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} · ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}
