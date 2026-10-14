import 'package:flutter/material.dart';
import 'common.dart';

class ListTableColumn {
  const ListTableColumn(this.label, {this.flex = 1, this.width});
  final String label;
  final int flex;
  final double? width;
}

/// The shared Secrets table surface, with stacked rows on compact displays.
class ListTable extends StatelessWidget {
  const ListTable({
    super.key,
    required this.columns,
    required this.rowsBuilder,
    this.footer,
    this.empty,
    this.minWidth = 700,
  });
  final List<ListTableColumn> columns;
  final List<Widget> Function(bool wide) rowsBuilder;
  final Widget? footer, empty;
  final double minWidth;

  static bool isWide(
    BuildContext context,
    double width, [
    double minimum = 700,
  ]) => width >= minimum * MediaQuery.textScalerOf(context).scale(14) / 14;

  @override
  Widget build(BuildContext context) => ListTablePanel(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = isWide(context, constraints.maxWidth, minWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (empty != null)
              empty!
            else ...[
              if (wide) ListTableHeader(columns: columns),
              ...rowsBuilder(wide),
            ],
            ?footer,
          ],
        );
      },
    ),
  );
}

class ListTablePanel extends StatelessWidget {
  const ListTablePanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: context.colors.panel,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: context.colors.outline),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class ListTableCells extends StatelessWidget {
  const ListTableCells({
    super.key,
    required this.columns,
    required this.children,
  }) : assert(columns.length == children.length);
  final List<ListTableColumn> columns;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      for (var i = 0; i < columns.length; i++)
        if (columns[i].width != null)
          SizedBox(width: columns[i].width, child: children[i])
        else
          Expanded(
            flex: columns[i].flex,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: children[i],
            ),
          ),
    ],
  );
}

class ListTableHeader extends StatelessWidget {
  const ListTableHeader({super.key, required this.columns});
  final List<ListTableColumn> columns;
  @override
  Widget build(BuildContext context) => Container(
    color: context.colors.tablePanel,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    child: ListTableCells(
      columns: columns,
      children: [
        for (final column in columns)
          Semantics(
            header: true,
            child: Text(
              column.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: context.colors.muted,
              ),
            ),
          ),
      ],
    ),
  );
}

class ListTableRow extends StatelessWidget {
  const ListTableRow({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.panel,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 19),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.outline)),
        ),
        child: child,
      ),
    ),
  );
}
