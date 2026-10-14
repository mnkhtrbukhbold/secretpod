import 'package:flutter/material.dart';
import '../state/vault_controller.dart';
import '../widgets/common.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({
    super.key,
    required this.controller,
    required this.organizationId,
  });

  final VaultController controller;
  final String organizationId;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final organization = controller.organization;
      final names = organization?.id == organizationId
          ? controller.projects
          : <String>[];
      final wide = MediaQuery.sizeOf(context).width >= 1000;
      final counts = <String, int>{};
      for (final secret in controller.secrets) {
        counts.update(
          secret.project.toLowerCase(),
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      if (controller.summary != null) {
        final summarized = <String>{};
        for (final entry in controller.summary!.projectCounts.entries) {
          final name = entry.key.toLowerCase();
          if (summarized.add(name)) counts[name] = entry.value;
        }
      }
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 76,
          titleSpacing: wide ? 40 : 20,
          title: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 20),
                    label: const Text('Back to workspace'),
                  ),
                ),
              ),
              if (wide) ...[
                const Brand(),
              ],
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final margin = ((constraints.maxWidth - 1250) / 2).clamp(
                wide ? 40.0 : 20.0,
                double.infinity,
              );
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(margin, 24, margin, 32),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _heading(context, organization?.name ?? ''),
                        ),
                        DecoratedSliver(
                          decoration: BoxDecoration(
                            color: context.colors.panel,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: context.colors.outline),
                          ),
                          sliver: SliverMainAxisGroup(
                            slivers: [
                              SliverToBoxAdapter(
                                child: _listHeader(context, names.length),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.only(bottom: 16),
                                sliver: names.isEmpty
                                    ? const SliverToBoxAdapter(
                                        child: EmptyState(
                                          icon: Icons.folder_outlined,
                                          title: 'Workspace changed',
                                          subtitle:
                                              'Go back to the workspace to see its projects.',
                                        ),
                                      )
                                    : SliverList.separated(
                                        itemCount: names.length,
                                        itemBuilder: (context, index) =>
                                            Material(
                                              type: MaterialType.transparency,
                                              child: _ProjectRow(
                                                name: names[index],
                                                count:
                                                    counts[names[index]
                                                        .toLowerCase()] ??
                                                    0,
                                              ),
                                            ),
                                        separatorBuilder: (context, _) =>
                                            Divider(
                                              height: 1,
                                              indent: 24,
                                              endIndent: 24,
                                              color: context.colors.outline,
                                            ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Text(
                              'Projects group your secrets. Assign a project when adding or editing a secret.',
                              style: TextStyle(
                                color: context.colors.muted,
                                fontSize: 12,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );

  Widget _heading(BuildContext context, String organizationName) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'WORKSPACE  /  ${organizationName.toUpperCase()}',
        style: TextStyle(
          color: context.colors.muted,
          fontSize: 10,
          letterSpacing: 1.3,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 20),
      Text(
        'Projects',
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w500,
          letterSpacing: -1.1,
          color: context.colors.ink,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'A place for every secret. Choose a project to explore its vault.',
        style: TextStyle(color: context.colors.muted, height: 1.5),
      ),
      const SizedBox(height: 30),
    ],
  );

  Widget _listHeader(BuildContext context, int count) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(24),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'All projects',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: context.colors.ink,
              ),
            ),
            Text(
              '$count ${count == 1 ? 'project' : 'projects'}',
              style: TextStyle(fontSize: 12, color: context.colors.muted),
            ),
          ],
        ),
      ),
      Divider(height: 1, color: context.colors.outline),
    ],
  );
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.name, required this.count});
  final String name;
  final int count;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    leading: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: context.colors.purpleContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.folder_outlined,
        color: context.colors.purple,
        size: 22,
      ),
    ),
    title: Text(
      name.isEmpty ? 'Unassigned' : name,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: context.colors.ink,
      ),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '$count ${count == 1 ? 'secret' : 'secrets'}',
        style: TextStyle(fontSize: 12, color: context.colors.muted),
      ),
    ),
    trailing: Icon(Icons.chevron_right, size: 20, color: context.colors.muted),
    onTap: () => Navigator.of(context).pop(name.toLowerCase()),
  );
}
