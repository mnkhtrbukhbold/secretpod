import 'package:flutter/material.dart';
import '../state/vault_controller.dart';
import 'common.dart';
import 'dropdown_field.dart';
import 'secret_activity.dart';

class ActivityFilters extends StatelessWidget {
  const ActivityFilters({super.key, required this.controller});
  final VaultController controller;

  Future<void> _dateRange(BuildContext context) async {
    final c = controller;
    final organization = c.organization?.id;
    final account = c.account?.id;
    final start = c.activityFrom?.toLocal();
    final until = c.activityUntil?.toLocal();
    final end = until == null
        ? null
        : DateTime(until.year, until.month, until.day - 1);
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: start != null && start.year < 1970 ? start : DateTime(1970),
      lastDate: end != null && end.year > now.year + 1
          ? end
          : DateTime(now.year + 1, 12, 31),
      initialDateRange: start == null || end == null
          ? null
          : DateTimeRange(start: start, end: end),
      helpText: 'Filter activity by date',
      saveText: 'Apply',
      builder: (context, child) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
              child: LayoutBuilder(
                builder: (context, constraints) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      datePickerTheme: DatePickerTheme.of(context).copyWith(
                        rangePickerHeaderHeadlineStyle:
                            constraints.maxWidth < 400
                            ? Theme.of(context).textTheme.bodyMedium
                            : Theme.of(context).textTheme.titleMedium,
                        rangePickerShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    child: child!,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (selected == null ||
        !context.mounted ||
        c.organization?.id != organization ||
        c.account?.id != account) {
      return;
    }
    await c.filterActivity(
      from: DateTime(
        selected.start.year,
        selected.start.month,
        selected.start.day,
      ).toUtc(),
      // Construct the next calendar day, so DST days may be 23 or 25 hours.
      until: DateTime(
        selected.end.year,
        selected.end.month,
        selected.end.day + 1,
      ).toUtc(),
      project: c.activityProject,
      action: c.activityAction,
      user: c.activityUser,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final projectNames = <String, String>{};
    for (final project in [
      ...c.projects,
      ...?c.summary?.activityProjects,
      ?c.activityProject,
    ]) {
      projectNames.putIfAbsent(project.toLowerCase(), () => project);
    }
    final projects = projectNames.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final actions = {
      ...c.summary?.activityActions ?? c.activity.map((e) => e.action),
      if (c.activityAction != null) c.activityAction!,
    }.toList()..sort((a, b) => activityLabel(a).compareTo(activityLabel(b)));
    final users =
        c.summary?.activityUsers ??
        {
          for (final member in c.members)
            'id:${member.account.id}':
                '${member.account.name} (${member.account.email})',
        };
    final memberOptions = Map<String, String>.of(users);
    if (c.activityUser != null) {
      memberOptions.putIfAbsent(
        c.activityUser!,
        () => 'Historical member selection',
      );
    }
    final userEntries = memberOptions.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    final start = c.activityFrom?.toLocal();
    final until = c.activityUntil?.toLocal();
    final end = until == null
        ? null
        : DateTime(until.year, until.month, until.day - 1);
    final dates = start == null || end == null
        ? 'All dates'
        : '${MaterialLocalizations.of(context).formatCompactDate(start)} – ${MaterialLocalizations.of(context).formatCompactDate(end)}';
    Widget select(
      String label,
      String all,
      String? value,
      List<DropdownMenuItem<String>> items,
      ValueChanged<String?> changed,
    ) => SecretPodDropdown<String>(
      key: ValueKey('activity-filter-$label'),
      initialValue: value ?? '',
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem(value: '', child: Text(all)),
        ...items,
      ],
      onChanged: c.loading
          ? null
          : (value) => changed(value == '' ? null : value),
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.panel,
        border: Border.all(color: context.colors.outline),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final columns = constraints.maxWidth >= 880 * scale
              ? 4
              : constraints.maxWidth >= 460 * scale
              ? 2
              : 1;
          final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date range',
                          style: menuTextStyle(
                            context.colors,
                          ).copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: const ValueKey('activity-date-range'),
                            style: selectTriggerStyle(context),
                            onPressed: c.loading
                                ? null
                                : () => _dateRange(context),
                            icon: const Icon(
                              Icons.date_range_outlined,
                              size: 18,
                            ),
                            label: Text(dates),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: select(
                      'Project',
                      'All projects',
                      projectNames[c.activityProject?.toLowerCase()],
                      [
                        for (final project in projects)
                          DropdownMenuItem(
                            value: project,
                            child: Text(project),
                          ),
                      ],
                      (value) => c.filterActivity(
                        from: c.activityFrom,
                        until: c.activityUntil,
                        project: value,
                        action: c.activityAction,
                        user: c.activityUser,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: select(
                      'Action',
                      'All actions',
                      c.activityAction,
                      [
                        for (final action in actions)
                          DropdownMenuItem(
                            value: action,
                            child: Text(activityLabel(action)),
                          ),
                      ],
                      (value) => c.filterActivity(
                        from: c.activityFrom,
                        until: c.activityUntil,
                        project: c.activityProject,
                        action: value,
                        user: c.activityUser,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: select(
                      'Members',
                      'All members',
                      c.activityUser,
                      [
                        for (final user in userEntries)
                          DropdownMenuItem(
                            value: user.key,
                            child: Text(user.value),
                          ),
                      ],
                      (value) => c.filterActivity(
                        from: c.activityFrom,
                        until: c.activityUntil,
                        project: c.activityProject,
                        action: c.activityAction,
                        user: value,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Dates use your local time',
                    style: TextStyle(color: context.colors.muted, fontSize: 12),
                  ),
                  if (c.hasActivityFilters)
                    TextButton.icon(
                      onPressed: c.loading ? null : () => c.filterActivity(),
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                      label: const Text('Clear filters'),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
