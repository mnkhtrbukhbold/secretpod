import 'package:flutter/material.dart';
import 'dropdown_field.dart';
import '../state/pagination.dart';

/// Shared responsive controls for any server-paged list.
class PaginationControls extends StatelessWidget {
  const PaginationControls({
    super.key,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPage,
    required this.onPageSize,
    this.loading = false,
  });
  final int page, pageSize, total;
  final bool loading;
  final ValueChanged<int> onPage, onPageSize;

  @override
  Widget build(BuildContext context) {
    final pageCount = total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;
    final first = total == 0 ? 0 : page * pageSize + 1;
    final last = ((page + 1) * pageSize).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text(
            '$first–$last of $total',
            semanticsLabel: 'Showing $first to $last of $total results',
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Rows '),
              SizedBox(
                width: 84,
                child: SecretPodDropdown<int>(
                  initialValue: pageSize,
                  decoration: const InputDecoration(),
                  items: PaginationSettings.pageSizes
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: loading
                      ? null
                      : (value) {
                          if (value != null) onPageSize(value);
                        },
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: loading || page == 0 ? null : () => onPage(page - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Flexible(child: Text('Page ${page + 1} of $pageCount')),
              IconButton(
                tooltip: 'Next page',
                onPressed: loading || page + 1 >= pageCount
                    ? null
                    : () => onPage(page + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
