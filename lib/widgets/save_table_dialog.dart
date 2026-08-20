import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/storage_service.dart';
import 'project_assignment_menu.dart';

class SaveTableDetails {
  const SaveTableDetails({required this.name, this.projectId});

  final String name;
  final String? projectId;
}

Future<SaveTableDetails?> showSaveTableDialog(
  BuildContext context, {
  required String suggestedName,
  String? initialProjectId,
}) {
  return showDialog<SaveTableDetails>(
    context: context,
    builder: (_) => _SaveTableDialog(
      suggestedName: suggestedName,
      initialProjectId: initialProjectId,
    ),
  );
}

class _SaveTableDialog extends StatefulWidget {
  const _SaveTableDialog({required this.suggestedName, this.initialProjectId});

  final String suggestedName;
  final String? initialProjectId;

  @override
  State<_SaveTableDialog> createState() => _SaveTableDialogState();
}

class _SaveTableDialogState extends State<_SaveTableDialog> {
  final StorageService _storageService = StorageService();
  late final TextEditingController _nameController;
  List<Project> _projects = const [];
  late String _selectedProjectId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.suggestedName);
    _selectedProjectId = widget.initialProjectId ?? '';
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final projects = await _storageService.loadProjects();
    if (!mounted) return;
    setState(() {
      _projects = projects;
      if (_selectedProjectId.isNotEmpty &&
          !_projects.any((project) => project.id == _selectedProjectId)) {
        _selectedProjectId = '';
      }
      _loading = false;
    });
  }

  Future<void> _createProject() async {
    final details = await showNewProjectDialog(context);
    if (details == null || !mounted) return;
    final name = details.name;
    for (final existing in _projects) {
      if (existing.name.toLowerCase() == name.toLowerCase()) {
        setState(() => _selectedProjectId = existing.id);
        return;
      }
    }
    final project = Project(
      id: 'project_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      colorValue: details.color.toARGB32(),
    );
    await _storageService.upsertProject(project);
    if (!mounted) return;
    setState(() {
      _projects = [..._projects, project]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _selectedProjectId = project.id;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('save-table-dialog'),
      title: const Text('Save Table'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Table name',
                hintText: 'Enter table name...',
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const LinearProgressIndicator()
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Project',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  ProjectAssignmentMenu(
                    projects: _projects,
                    selectedProjectId: _selectedProjectId,
                    onSelected: (projectId) =>
                        setState(() => _selectedProjectId = projectId ?? ''),
                    onCreateProject: _createProject,
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading
              ? null
              : () {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(
                    context,
                    SaveTableDetails(
                      name: name,
                      projectId: _selectedProjectId.isEmpty
                          ? null
                          : _selectedProjectId,
                    ),
                  );
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
