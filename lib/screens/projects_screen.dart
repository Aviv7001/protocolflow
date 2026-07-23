import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/protocol.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import 'library_screen.dart';

class ProjectsScreen extends StatefulWidget {
  final bool embedded;
  final void Function(String? projectId)? onProjectSelected;

  const ProjectsScreen({
    super.key,
    this.embedded = false,
    this.onProjectSelected,
  });

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  static const String _unassignedFilterId = '__unassigned__';

  final StorageService _storageService = StorageService();
  List<Project> _projects = [];
  List<Protocol> _protocols = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final projects = await _storageService.loadProjects();
    final protocols = await _storageService.loadProtocols();
    if (!mounted) return;
    setState(() {
      _projects = projects;
      _protocols = protocols;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Text(
                        'Projects',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Organize protocols and templates by study or workflow',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240,
                          mainAxisExtent: 180,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    delegate: SliverChildListDelegate([
                      _buildUnassignedCard(),
                      ..._projects.map(_buildProjectCard),
                    ]),
                  ),
                ),
              ],
            ),
          );

    if (widget.embedded) {
      return Scaffold(body: body, floatingActionButton: _buildFab());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: body,
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton(
      tooltip: 'Create project',
      onPressed: _createProject,
      child: const Icon(Icons.create_new_folder_outlined),
    );
  }

  Widget _buildUnassignedCard() {
    final counts = _countsFor(null);
    return _ProjectCard(
      icon: Icons.folder_off_outlined,
      color: Colors.grey,
      title: 'Unassigned',
      subtitle: '${counts.protocols} protocols, ${counts.templates} templates',
      onTap: () => _openLibrary(_unassignedFilterId),
    );
  }

  Widget _buildProjectCard(Project project) {
    final counts = _countsFor(project.id);
    return _ProjectCard(
      icon: Icons.folder_outlined,
      color: Color(project.colorValue),
      title: project.name,
      subtitle: '${counts.protocols} protocols, ${counts.templates} templates',
      trailing: PopupMenuButton<String>(
        tooltip: 'Project options',
        onSelected: (value) {
          if (value == 'rename') _renameProject(project);
          if (value == 'delete') _confirmDeleteProject(project);
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'delete', child: Text('Delete project')),
        ],
      ),
      onTap: () => _openLibrary(project.id),
    );
  }

  ({int protocols, int templates}) _countsFor(String? projectId) {
    var protocols = 0;
    var templates = 0;
    for (final protocol in _protocols) {
      final assigned = protocol.projectId;
      final matches = projectId == null
          ? assigned == null ||
                assigned.isEmpty ||
                !_projects.any((project) => project.id == assigned)
          : assigned == projectId;
      if (!matches) continue;
      if (protocol.isTemplate) {
        templates++;
      } else {
        protocols++;
      }
    }
    return (protocols: protocols, templates: templates);
  }

  Future<void> _openLibrary(String? projectId) async {
    if (widget.onProjectSelected != null) {
      widget.onProjectSelected!(projectId);
      return;
    }
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LibraryScreen(initialTabIndex: 1, initialProjectId: projectId),
      ),
    );
    _loadData();
  }

  Future<void> _createProject() async {
    await _editProjectName();
  }

  Future<void> _renameProject(Project project) async {
    await _editProjectName(project: project);
  }

  Future<void> _editProjectName({Project? project}) async {
    final controller = TextEditingController(text: project?.name ?? '');
    var selectedColor = Color(
      project?.colorValue ?? AppColors.primary.toARGB32(),
    );
    try {
      final result = await showDialog<_ProjectEditResult>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(project == null ? 'New Project' : 'Edit Project'),
            content: _ProjectEditorFields(
              controller: controller,
              selectedColor: selectedColor,
              onColorChanged: (color) =>
                  setDialogState(() => selectedColor = color),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  _ProjectEditResult(
                    name: controller.text.trim(),
                    color: selectedColor,
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (result == null || result.name.isEmpty) return;
      final name = result.name;
      final lowerName = name.toLowerCase();
      final duplicate = _projects.any(
        (item) =>
            item.id != project?.id && item.name.toLowerCase() == lowerName,
      );
      if (duplicate) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A project with this name exists.')),
        );
        return;
      }

      final saved = project == null
          ? Project(
              id: 'project_${DateTime.now().microsecondsSinceEpoch}',
              name: name,
              colorValue: result.color.toARGB32(),
            )
          : project.copyWith(
              name: name,
              colorValue: result.color.toARGB32(),
              updatedAt: DateTime.now(),
            );
      await _storageService.upsertProject(saved);
      await _loadData();
    } finally {
      controller.dispose();
    }
  }

  Future<void> _confirmDeleteProject(Project project) async {
    final counts = _countsFor(project.id);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Project?'),
        content: Text(
          'This will keep ${counts.protocols + counts.templates} item(s) and move them to Unassigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    await _storageService.deleteProject(project.id);
    await _loadData();
  }
}

class _ProjectCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withValues(alpha: 0.2), width: 1),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            if (trailing != null)
              Positioned(top: 4, right: 4, child: trailing!),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 32, color: color),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectEditResult {
  final String name;
  final Color color;

  const _ProjectEditResult({required this.name, required this.color});
}

class _ProjectEditorFields extends StatelessWidget {
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

  final TextEditingController controller;
  final Color selectedColor;
  final ValueChanged<Color> onColorChanged;

  const _ProjectEditorFields({
    required this.controller,
    required this.selectedColor,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Project name'),
          textCapitalization: TextCapitalization.words,
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
                onTap: () => onColorChanged(color),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selectedColor == color
                          ? Colors.black87
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: selectedColor == color
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
