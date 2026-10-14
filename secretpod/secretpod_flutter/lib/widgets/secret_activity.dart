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
  static const _pageSize = PaginationSettings.defaultPageSize;
  bool _loading = false, _hasMore = false;
  List<String?> _cursors = [null];
  int _page = 0, _failedPage = 0;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  @override
  void didUpdateWidget(SecretActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.secret.id != widget.secret.id ||
        oldWidget.secret.organizationId != widget.secret.organizationId ||
        oldWidget.controller != widget.controller) {
      _events = [];
      _cursors = [null];
      _page = 0;
      _hasMore = false;
      _load(refresh: true);
    } else if (oldWidget.revision != widget.revision) {
      _load(refresh: true);
    }
  }

  Future<void> _load({int page = 0, bool refresh = false}) async {
    // Guard synchronously as two clicks can arrive before the disabled rebuild.
    if (_loading && !refresh) return;
    final generation = ++_generation;
    final cursor = page == 0 ? null : _cursors[page];
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await widget.controller.client.vault.secretActivity(
        widget.secret.organizationId,
        widget.secret.id,
        cursor,
        // One lookahead row avoids an empty Next page for exact multiples.
        limit: _pageSize + 1,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _events = events.take(_pageSize).toList();
        _hasMore = events.length > _pageSize;
        _page = page;
        _cursors = _cursors.take(page + 1).toList();
        if (_hasMore) _cursors.add(_events.last.id);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _generation) return;
        final position = Scrollable.maybeOf(context)?.position;
        if (position != null && position.hasContentDimensions) {
          position.jumpTo(position.minScrollExtent);
        }
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _failedPage = page;
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
            onPressed: _loading ? null : () => _load(refresh: true),
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
          onRetry: _loading ? null : () => _load(page: _failedPage),
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
                backgroundColor: activityColors(
                  context,
                  event.action,
                ).background,
                child: Icon(
                  activityIcon(event.action),
                  color: activityColors(context, event.action).foreground,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ActivityBadge(event.action),
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
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton.icon(
            onPressed: _loading || _page == 0
                ? null
                : () => _load(page: _page - 1),
            icon: const Icon(Icons.chevron_left),
            label: const Text('Previous'),
          ),
          Text(
            'Page ${_page + 1}',
            semanticsLabel: 'Activity page ${_page + 1}',
          ),
          TextButton.icon(
            onPressed: _loading || !_hasMore
                ? null
                : () => _load(page: _page + 1),
            icon: const Icon(Icons.chevron_right),
            label: const Text('Next'),
          ),
        ],
      ),
    ],
  );
}

String activityLabel(String action) => switch (action) {
  'rotated' => 'Rotated',
  'updated' => 'Edited',
  'saved' => 'Saved',
  'copy requested' => 'Copy requested',
  'copied' => 'Copied',
  'revealed' => 'Revealed',
  'created' => 'Created',
  'deleted' => 'Deleted',
  'marked needs rotating' => 'Marked needs rotating',
  'cleared rotation flag' => 'Cleared rotation flag',
  'removed member' => 'Removed member',
  _ =>
    action.isEmpty
        ? 'Unknown action'
        : '${action[0].toUpperCase()}${action.substring(1)}',
};
IconData activityIcon(String action) => switch (action) {
  'created' => Icons.add_circle_outline,
  'copy requested' || 'copied' => Icons.copy_outlined,
  'revealed' => Icons.visibility_outlined,
  'rotated' || 'updated' || 'saved' => Icons.edit_outlined,
  'deleted' => Icons.delete_outline,
  'marked needs rotating' ||
  'cleared rotation flag' => Icons.change_circle_outlined,
  'removed member' => Icons.person_remove_outlined,
  'disabled member access' => Icons.block_outlined,
  'enabled member access' => Icons.lock_open_outlined,
  _ => Icons.history,
};

({Color foreground, Color background}) activityColors(
  BuildContext context,
  String action,
) {
  final colors = context.colors;
  return switch (action) {
    'revealed' => (foreground: colors.blue, background: colors.blueContainer),
    'deleted' || 'removed member' || 'disabled member access' => (
      foreground: colors.danger,
      background: colors.dangerContainer,
    ),
    'rotated' || 'updated' || 'saved' => (
      foreground: colors.isDark
          ? const Color(0xFFFFB77A)
          : const Color(0xFFA34308),
      background: colors.isDark
          ? const Color(0xFF482B18)
          : const Color(0xFFFFEDD5),
    ),
    'created' || 'enabled member access' => (
      foreground: colors.success,
      background: colors.successContainer,
    ),
    _ => (foreground: colors.muted, background: colors.iconPanel),
  };
}

class ActivityBadge extends StatelessWidget {
  const ActivityBadge(this.action, {super.key});
  final String action;
  @override
  Widget build(BuildContext context) {
    final colors = activityColors(context, action);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: colors.foreground.withValues(alpha: .18)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          activityLabel(action),
          style: TextStyle(
            color: colors.foreground,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

String activityTime(DateTime time) {
  final local = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} · ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}
