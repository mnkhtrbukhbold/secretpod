import 'package:flutter/material.dart';
import 'common.dart';

/// Fixed submit buttons may be pressed while invalid fields are offscreen.
bool validateDialogForm(FormState form) {
  final invalid = form.validateGranularly();
  if (invalid.isEmpty) return true;
  _revealDialogFeedback(invalid.first.context);
  return false;
}

void _revealDialogFeedback(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    Scrollable.ensureVisible(
      context,
      alignment: 1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  });
}

/// Reveals an operation error without moving the fixed header or action row.
class DialogErrorNotice extends StatefulWidget {
  const DialogErrorNotice(this.message, {super.key});
  final String message;

  @override
  State<DialogErrorNotice> createState() => _DialogErrorNoticeState();
}

class _DialogErrorNoticeState extends State<DialogErrorNotice> {
  @override
  void initState() {
    super.initState();
    _revealDialogFeedback(context);
  }

  @override
  void didUpdateWidget(DialogErrorNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) _revealDialogFeedback(context);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: ErrorNotice(widget.message),
  );
}

/// Keeps the header and actions outside the dialog's scrolling content.
class SecretPodDialog extends StatelessWidget {
  const SecretPodDialog({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.icon,
    this.maxWidth = 560,
    this.selectableTitle = false,
    this.actions = const [],
    this.headerBottom,
    this.scrollController,
  });

  final String title;
  final VoidCallback? onClose;
  final Widget child;
  final IconData? icon;
  final double maxWidth;
  final bool selectableTitle;
  final List<Widget> actions;
  final Widget? headerBottom;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final shortViewport =
        media.size.height - media.viewInsets.vertical - media.padding.vertical <
        240;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: shortViewport ? 4 : 20,
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        // A landscape keyboard can leave very little height. Use the available
        // width then so the action row doesn't consume the body's last space.
        constraints: BoxConstraints(
          maxWidth: shortViewport ? double.infinity : maxWidth,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 300;
            final titleText = Text(
              title,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 18 : 24,
                fontWeight: FontWeight.w500,
              ),
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  key: const ValueKey('dialog-header'),
                  padding: EdgeInsets.fromLTRB(
                    28,
                    compact ? 4 : 20,
                    20,
                    compact ? 4 : 16,
                  ),
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: context.colors.blue),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Semantics(
                          namesRoute: true,
                          header: true,
                          child: Tooltip(
                            message: title,
                            child: selectableTitle
                                ? SelectionArea(child: titleText)
                                : titleText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: onClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: context.colors.outline),
                ?headerBottom,
                Flexible(
                  child: SingleChildScrollView(
                    key: const ValueKey('dialog-body-scroll'),
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
                    child: child,
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: context.colors.outline,
                  ),
                  Padding(
                    key: const ValueKey('dialog-actions'),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 16 : 28,
                      vertical: compact ? 4 : 16,
                    ),
                    child: _actions(context, compact),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, bool compact) {
    final bar = OverflowBar(
      alignment: MainAxisAlignment.end,
      overflowAlignment: OverflowBarAlignment.end,
      spacing: 8,
      overflowSpacing: 8,
      children: actions,
    );
    if (!compact) return bar;
    final theme = Theme.of(context);
    const style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, 40)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Theme(
      data: theme.copyWith(
        textButtonTheme: TextButtonThemeData(
          style: (theme.textButtonTheme.style ?? const ButtonStyle()).merge(
            style,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: (theme.filledButtonTheme.style ?? const ButtonStyle()).merge(
            style,
          ),
        ),
      ),
      child: bar,
    );
  }
}
