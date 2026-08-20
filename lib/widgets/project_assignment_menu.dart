import 'package:flutter/material.dart';

import '../models/project.dart';
import '../theme/app_colors.dart';

class ProjectAssignmentMenu extends StatelessWidget {
  const ProjectAssignmentMenu({
    super.key,
    required this.projects,
    required this.selectedProjectId,
    required this.onSelected,
    required this.onCreateProject,
    this.tooltip = 'Choose project',
  });

  static const _unassigned = '__unassigned__';
  static const _create = '__create__';

  final List<Project> projects;
  final String? selectedProjectId;
  final ValueChanged<String?> onSelected;
  final Future<void> Function() onCreateProject;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    Project? selected;
    for (final project in projects) {
      if (project.id == selectedProjectId) selected = project;
    }
    final color = selected == null
        ? AppColors.textSecondary
        : Color(selected.colorValue);

    return PopupMenuButton<String>(
      tooltip: tooltip,
      initialValue: selected?.id ?? _unassigned,
      onSelected: (value) async {
        if (value == _create) {
          await onCreateProject();
        } else {
          onSelected(value == _unassigned ? null : value);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _unassigned,
          child: ListTile(
            leading: Icon(Icons.folder_off_outlined),
            title: Text('Unassigned'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        for (final project in projects)
          PopupMenuItem(
            value: project.id,
            child: ListTile(
              leading: Icon(
                Icons.folder_outlined,
                color: Color(project.colorValue),
              ),
              title: Text(project.name),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _create,
          child: ListTile(
            leading: Icon(Icons.create_new_folder_outlined),
            title: Text('Create project'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Chip(
          avatar: Icon(
            selected == null
                ? Icons.folder_off_outlined
                : Icons.folder_outlined,
            color: color,
            size: 18,
          ),
          label: Text(
            selected?.name ?? 'Unassigned',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          side: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
      ),
    );
  }
}

class NewProjectDetails {
  const NewProjectDetails({required this.name, required this.color});

  final String name;
  final Color color;
}

Future<NewProjectDetails?> showNewProjectDialog(BuildContext context) {
  return showDialog<NewProjectDetails>(
    context: context,
    builder: (_) => const _NewProjectDialog(),
  );
}

class _NewProjectDialog extends StatefulWidget {
  const _NewProjectDialog();

  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  static const _colors = [
    AppColors.primary,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.blueGrey,
  ];

  final TextEditingController _controller = TextEditingController();
  Color _selectedColor = AppColors.primary;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Project'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Project name'),
          ),
          const SizedBox(height: 18),
          const Text('Color', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in _colors)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColor == color
                            ? AppColors.textPrimary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: _selectedColor == color
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              NewProjectDetails(name: name, color: _selectedColor),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
