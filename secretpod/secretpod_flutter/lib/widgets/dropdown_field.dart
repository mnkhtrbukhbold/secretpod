import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'common.dart';

const menuRadius = BorderRadius.all(Radius.circular(6));
TextStyle menuTextStyle(AppColors colors) =>
    TextStyle(fontFamily: 'Roboto', fontSize: 14, color: colors.ink);

MenuStyle secretPodMenuStyle(AppColors colors) => MenuStyle(
  backgroundColor: WidgetStatePropertyAll(colors.raisedPanel),
  surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
  shadowColor: WidgetStatePropertyAll(
    Color(colors.isDark ? 0x66000000 : 0x33000000),
  ),
  elevation: WidgetStatePropertyAll(6),
  side: WidgetStatePropertyAll(BorderSide(color: colors.menuBorder)),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: menuRadius),
  ),
  padding: WidgetStatePropertyAll(EdgeInsets.all(4)),
  alignment: AlignmentDirectional.bottomStart,
);

ButtonStyle selectTriggerStyle(BuildContext context) => ButtonStyle(
  textStyle: WidgetStatePropertyAll(menuTextStyle(context.colors)),
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled)
        ? context.colors.muted.withValues(alpha: .5)
        : context.colors.ink,
  ),
  backgroundColor: WidgetStatePropertyAll(context.colors.selectPanel),
  overlayColor: WidgetStatePropertyAll(
    Color(context.colors.isDark ? 0x0FFFFFFF : 0x08000000),
  ),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  ),
  minimumSize: WidgetStatePropertyAll(
    Size(0, MediaQuery.sizeOf(context).width < 600 ? 44 : 38),
  ),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  shape: const WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: menuRadius),
  ),
  side: WidgetStateProperty.resolveWith(
    (states) => BorderSide(
      color: states.contains(WidgetState.focused)
          ? context.colors.blue.withValues(alpha: .6)
          : context.colors.menuBorder,
      width: states.contains(WidgetState.focused) ? 2 : 1,
    ),
  ),
);

class SecretPodMenuItem extends StatelessWidget {
  const SecretPodMenuItem({
    super.key,
    required this.child,
    this.onPressed,
    this.leading,
    this.trailing,
    this.selected = false,
    this.autofocus = false,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final Widget? leading, trailing;
  final bool selected, autofocus;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: MenuItemButton(
      onPressed: onPressed,
      autofocus: autofocus,
      leadingIcon: leading,
      trailingIcon: selected
          ? const Icon(Icons.check_rounded, size: 16)
          : trailing,
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(menuTextStyle(context.colors)),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? context.colors.muted.withValues(alpha: .5)
              : context.colors.ink,
        ),
        iconColor: WidgetStatePropertyAll(context.colors.muted),
        iconSize: const WidgetStatePropertyAll(16),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)
              ? context.colors.menuHighlight
              : Colors.transparent,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        minimumSize: WidgetStatePropertyAll(
          Size(0, MediaQuery.sizeOf(context).width < 600 ? 44 : 32),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
      ),
      child: child,
    ),
  );
}

class SecretPodMenuDivider extends StatelessWidget {
  const SecretPodMenuDivider({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Divider(height: 1, thickness: 1, color: context.colors.menuBorder),
  );
}

/// Shared anchored popover for workspace and profile actions.
class SecretPodMenu extends StatefulWidget {
  const SecretPodMenu({
    super.key,
    required this.children,
    required this.builder,
    this.width = 248,
    this.alignEnd = false,
  });
  final List<Widget> children;
  final double width;
  final bool alignEnd;
  final Widget Function(BuildContext, VoidCallback, FocusNode) builder;
  @override
  State<SecretPodMenu> createState() => _SecretPodMenuState();
}

class _SecretPodMenuState extends State<SecretPodMenu> {
  final _controller = MenuController();
  final _focus = FocusNode();
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = math.min(widget.width, MediaQuery.sizeOf(context).width - 24);
    return MenuAnchor(
      controller: _controller,
      childFocusNode: _focus,
      consumeOutsideTap: true,
      crossAxisUnconstrained: false,
      alignmentOffset: Offset(widget.alignEnd ? -width : 0, 4),
      style: secretPodMenuStyle(context.colors).copyWith(
        alignment: widget.alignEnd
            ? AlignmentDirectional.bottomEnd
            : AlignmentDirectional.bottomStart,
        minimumSize: WidgetStatePropertyAll(Size(width, 0)),
        maximumSize: WidgetStatePropertyAll(Size(width, 360)),
      ),
      menuChildren: widget.children,
      builder: (context, controller, _) => widget.builder(
        context,
        () => controller.isOpen ? controller.close() : controller.open(),
        _focus,
      ),
    );
  }
}

/// A form select with a separate label and an anchored, keyboard-accessible menu.
class SecretPodDropdown<T> extends FormField<T> {
  SecretPodDropdown({
    super.key,
    required super.initialValue,
    required this.items,
    required this.onChanged,
    required this.decoration,
  }) : super(
         enabled: onChanged != null,
         builder: (field) => (field as _SecretPodDropdownState<T>)._control(),
       );

  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  @override
  FormFieldState<T> createState() => _SecretPodDropdownState<T>();
}

class _SecretPodDropdownState<T> extends FormFieldState<T> {
  final _menu = MenuController();
  final _focus = FocusNode();
  @override
  SecretPodDropdown<T> get widget => super.widget as SecretPodDropdown<T>;

  @override
  void didUpdateWidget(covariant SecretPodDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      setValue(widget.initialValue);
    }
    if (!widget.enabled && _menu.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _menu.close();
      });
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  void reset() {
    _menu.close();
    super.reset();
    widget.onChanged?.call(value);
  }

  Widget _control() {
    final selected = widget.items
        .where((item) => item.value == value)
        .firstOrNull;
    final label = widget.decoration.labelText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label,
            style: menuTextStyle(
              context.colors,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return MenuAnchor(
              controller: _menu,
              childFocusNode: _focus,
              consumeOutsideTap: true,
              crossAxisUnconstrained: false,
              alignmentOffset: const Offset(0, 4),
              style: secretPodMenuStyle(context.colors).copyWith(
                minimumSize: WidgetStatePropertyAll(Size(width, 0)),
                maximumSize: WidgetStatePropertyAll(Size(width, 320)),
              ),
              menuChildren: [
                for (final item in widget.items)
                  SecretPodMenuItem(
                    selected: item.value == value,
                    autofocus: item.value == value,
                    onPressed: widget.enabled && item.enabled
                        ? () {
                            didChange(item.value);
                            item.onTap?.call();
                            widget.onChanged?.call(item.value);
                          }
                        : null,
                    child: item.child,
                  ),
              ],
              builder: (context, controller, _) => Semantics(
                label: label,
                child: Shortcuts(
                  shortcuts: const {
                    SingleActivator(LogicalKeyboardKey.arrowDown):
                        ActivateIntent(),
                  },
                  child: TextButton(
                    key: const ValueKey('dropdown-trigger'),
                    focusNode: _focus,
                    style: selectTriggerStyle(context),
                    onPressed: widget.enabled && widget.items.isNotEmpty
                        ? () => controller.isOpen
                              ? controller.close()
                              : controller.open()
                        : null,
                    child: Row(
                      children: [
                        Expanded(
                          child: DefaultTextStyle.merge(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            child:
                                selected?.child ??
                                Text(
                                  widget.decoration.hintText ??
                                      'Select an option',
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 16,
                          color: context.colors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.decoration.helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.decoration.helperText!,
            style: TextStyle(fontSize: 12, color: context.colors.muted),
          ),
        ],
      ],
    );
  }
}
