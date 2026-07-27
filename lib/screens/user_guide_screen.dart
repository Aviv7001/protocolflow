import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class UserGuideScreen extends StatefulWidget {
  final bool embedded;

  const UserGuideScreen({super.key, this.embedded = false});

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> {
  final Set<String> _expandedSections = {};
  final Set<String> _expandedSubsections = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('User Guide')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (widget.embedded)
            Text(
              'User Guide',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          if (widget.embedded) const SizedBox(height: 6),
          const Text(
            'Open a section to learn a workflow. The guide is available inside the app, including when ProtocolFlow is installed as a web app.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          for (final section in _guideSections) ...[
            _buildSection(section),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(_GuideSection section) {
    final isExpanded = _expandedSections.contains(section.id);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            dense: true,
            onTap: () => _toggleSection(section.id),
            leading: Icon(section.icon, color: AppColors.primary),
            title: Text(
              section.title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${section.subsections.length} ${section.subsections.length == 1 ? 'topic' : 'topics'}',
            ),
            trailing: IconButton(
              tooltip: isExpanded
                  ? 'Shrink ${section.title}'
                  : 'Expand ${section.title}',
              onPressed: () => _toggleSection(section.id),
              icon: Icon(isExpanded ? Icons.unfold_less : Icons.unfold_more),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < section.subsections.length;
                    index++
                  ) ...[
                    _buildSubsection(section, section.subsections[index]),
                    if (index < section.subsections.length - 1)
                      const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubsection(_GuideSection section, _GuideSubsection subsection) {
    final key = '${section.id}|${subsection.id}';
    final isExpanded = _expandedSubsections.contains(key);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            dense: true,
            tileColor: AppColors.surfaceContainer,
            onTap: () => _toggleSubsection(key),
            title: Text(
              subsection.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: IconButton(
              tooltip: isExpanded
                  ? 'Shrink ${subsection.title}'
                  : 'Expand ${subsection.title}',
              onPressed: () => _toggleSubsection(key),
              icon: Icon(isExpanded ? Icons.unfold_less : Icons.unfold_more),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: _buildGuideText(subsection),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuideText(_GuideSubsection subsection) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < subsection.paragraphs.length; index++) ...[
          Text(subsection.paragraphs[index]),
          if (index < subsection.paragraphs.length - 1)
            const SizedBox(height: 10),
        ],
        if (subsection.steps.isNotEmpty) ...[
          if (subsection.paragraphs.isNotEmpty) const SizedBox(height: 12),
          for (var index = 0; index < subsection.steps.length; index++)
            _GuideLine(marker: '${index + 1}.', text: subsection.steps[index]),
        ],
        if (subsection.bullets.isNotEmpty) ...[
          if (subsection.paragraphs.isNotEmpty || subsection.steps.isNotEmpty)
            const SizedBox(height: 12),
          for (final bullet in subsection.bullets)
            _GuideLine(marker: '•', text: bullet),
        ],
      ],
    );
  }

  void _toggleSection(String id) {
    setState(() {
      if (!_expandedSections.remove(id)) _expandedSections.add(id);
    });
  }

  void _toggleSubsection(String key) {
    setState(() {
      if (!_expandedSubsections.remove(key)) {
        _expandedSubsections.add(key);
      }
    });
  }
}

class _GuideLine extends StatelessWidget {
  final String marker;
  final String text;

  const _GuideLine({required this.marker, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              marker,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _GuideSection {
  final String id;
  final String title;
  final IconData icon;
  final List<_GuideSubsection> subsections;

  const _GuideSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.subsections,
  });
}

class _GuideSubsection {
  final String id;
  final String title;
  final List<String> paragraphs;
  final List<String> steps;
  final List<String> bullets;

  const _GuideSubsection({
    required this.id,
    required this.title,
    this.paragraphs = const [],
    this.steps = const [],
    this.bullets = const [],
  });
}

// HOW TO EDIT THIS GUIDE
//
// Each _GuideSection below creates one large expand/shrink bar. Give every
// section a unique `id`, a visible `title`, an icon, and a list of subsections.
//
// Each _GuideSubsection creates one smaller bar inside its section. Add normal
// text to `paragraphs`, numbered instructions to `steps`, and bullet points to
// `bullets`. Copy an existing block when adding content; no widget code needs
// to change. Keep subsection IDs unique within their parent section.
const List<_GuideSection> _guideSections = [
  _GuideSection(
    id: 'install',
    title: 'Installing ProtocolFlow',
    icon: Icons.install_desktop_outlined,
    subsections: [
      _GuideSubsection(
        id: 'windows',
        title: 'Windows',
        paragraphs: [
          'ProtocolFlow is a progressive web app (PWA). Installing it creates an app icon and opens it in its own window; it does not install a separate native program.',
        ],
        steps: [
          'Open ProtocolFlow in Microsoft Edge or Google Chrome.',
          'In Edge, open the menu, choose Apps, then Install this site as an app. In Chrome, open the menu, choose Cast, save, and share, then Install page as app.',
          'Confirm the installation and optionally pin ProtocolFlow to Start or the taskbar.',
        ],
      ),
      _GuideSubsection(
        id: 'mac',
        title: 'macOS',
        steps: [
          'Open ProtocolFlow in Safari.',
          'Choose Share in the Safari toolbar, then Add to Dock.',
          'Choose Add. ProtocolFlow will appear in the Dock, Applications, and Spotlight.',
        ],
        bullets: [
          'Chrome can also install ProtocolFlow from its Install page as app command.',
        ],
      ),
      _GuideSubsection(
        id: 'android',
        title: 'Android',
        steps: [
          'Open ProtocolFlow in Chrome.',
          'Open the browser menu, choose Add to home screen, then Install.',
          'Use the new ProtocolFlow icon from the launcher or home screen.',
        ],
      ),
      _GuideSubsection(
        id: 'ios',
        title: 'iPhone / iPad',
        steps: [
          'Open ProtocolFlow in Safari.',
          'Tap Share, then Add to Home Screen.',
          'Turn on Open as Web App when that option is shown, then tap Add.',
        ],
      ),
      _GuideSubsection(
        id: 'local_data',
        title: 'Installed app and local data',
        paragraphs: [
          'The installed app and the browser version use the same browser storage for the same site. Clearing site data, resetting the browser profile, or uninstalling while choosing to delete app data can remove local ProtocolFlow data.',
        ],
        bullets: [
          'Sync or export important work before clearing browser data.',
          'An internet connection is required for Google sign-in and Drive sync. Some local workflows may remain available after the app has loaded.',
        ],
      ),
    ],
  ),
  _GuideSection(
    id: 'sync',
    title: 'Google Sync and Data Safety',
    icon: Icons.cloud_sync_outlined,
    subsections: [
      _GuideSubsection(
        id: 'what_sync_does',
        title: 'What sync does',
        paragraphs: [
          'Google sync copies supported ProtocolFlow data between local browser storage and the signed-in Google account. Use Sync from the sidebar to upload local changes and download newer remote data.',
        ],
        bullets: [
          'Protocols and templates',
          'Projects',
          'Completed protocols',
          'Saved tables',
          'Today\'s Tasks and task history',
          'Measuring Tools settings',
        ],
      ),
      _GuideSubsection(
        id: 'request_access',
        title: 'Request access',
        paragraphs: [
          'Drive sync is currently in limited testing. Your Google account must be approved before you can connect. Contact Aviv at Aviv7001@gmail.com and ask for access.',
        ],
      ),
      _GuideSubsection(
        id: 'where_stored',
        title: 'Where Google stores the data',
        paragraphs: [
          'ProtocolFlow requests Google Drive\'s narrow app-data permission. Synced JSON files are stored in the account\'s hidden appDataFolder, not in the visible My Drive file list.',
          'Google documents this folder as accessible only to the app that created it. Its files cannot be shared through normal Drive sharing and are hidden from other Drive apps.',
        ],
      ),
      _GuideSubsection(
        id: 'safety',
        title: 'Is it safe?',
        paragraphs: [
          'The limited Drive permission and hidden app-data folder reduce exposure, and communication uses Google\'s authenticated HTTPS APIs. ProtocolFlow does not add end-to-end encryption, so do not treat sync as a secure vault for secrets.',
        ],
        bullets: [
          'Protect the Google account with a strong password and two-step verification.',
          'Only sign in on devices and browser profiles you trust.',
          'Signing out stops new sync operations but does not automatically erase local browser data.',
          'Keep independent exports of critical protocols. Sync is convenience and recovery support, not a substitute for laboratory data-retention policy.',
        ],
      ),
      _GuideSubsection(
        id: 'conflicts',
        title: 'Offline work and conflicts',
        paragraphs: [
          'Local edits can be made while signed out or offline. They remain pending until a successful sync. If local and remote protocol versions conflict, ProtocolFlow can preserve a conflict copy instead of silently discarding one version.',
        ],
      ),
    ],
  ),
  _GuideSection(
    id: 'tasks',
    title: 'Today\'s Tasks',
    icon: Icons.today_outlined,
    subsections: [
      _GuideSubsection(
        id: 'task_workflow',
        title: 'Create and manage tasks',
        steps: [
          'On Home, expand Today\'s Tasks and choose Add Task.',
          'Enter a title and optional description.',
          'Use the status control to mark the task Not started, In progress, or Completed.',
          'Use the task menu to move a task up or down, or delete it.',
        ],
      ),
      _GuideSubsection(
        id: 'task_history',
        title: 'Archive and history',
        paragraphs: [
          'Move completed tasks to history to keep the daily list focused. Open task history from the clock/history button in the Today\'s Tasks header.',
        ],
      ),
    ],
  ),
  _GuideSection(
    id: 'lab_tools',
    title: 'Lab Tools',
    icon: Icons.science_outlined,
    subsections: [
      _GuideSubsection(
        id: 'master_mix',
        title: 'Master Mix',
        paragraphs: [
          'Calculates reagent amounts for a final mix volume. Liquid stocks use stock and final concentrations. Solid materials use a final mass/volume, percent w/v, or molar concentration and receive balance recommendations.',
        ],
      ),
      _GuideSubsection(
        id: 'staining',
        title: 'Staining',
        paragraphs: [
          'Builds staining panels and reagent combinations for samples. Use it to organize conditions and generate a reusable staining table.',
        ],
      ),
      _GuideSubsection(
        id: 'serial_dilution',
        title: 'Serial Dilution',
        paragraphs: [
          'Generates forward or independent dilution series. Set the starting concentration, dilution factor, final volume, and either the number of dilutions or target concentration. A solid can be weighed to prepare D0.',
        ],
      ),
      _GuideSubsection(
        id: 'plate_layout',
        title: 'Plate Layout',
        paragraphs: [
          'Designs sample placement in multi-well plates. Configure the plate and samples, then use the visual layout as a protocol reference table.',
        ],
      ),
      _GuideSubsection(
        id: 'generic_table',
        title: 'Generic Table',
        paragraphs: [
          'Creates a custom grid when no specialized calculator matches the experiment. Rows, columns, text, and cell formatting can be edited directly.',
        ],
      ),
      _GuideSubsection(
        id: 'table_import',
        title: 'Import Table',
        paragraphs: [
          'Imports CSV or Excel data as a generic table. Review the imported structure before saving or attaching it to a protocol.',
        ],
      ),
    ],
  ),
  _GuideSection(
    id: 'measuring_tools',
    title: 'Measuring Tools',
    icon: Icons.straighten,
    subsections: [
      _GuideSubsection(
        id: 'purpose',
        title: 'What Measuring Tools are',
        paragraphs: [
          'Measuring Tools is the list of equipment available in the lab. Liquid tools define usable volume ranges and increments. Solid tools define balance capacity, minimum preferred mass, and readability.',
        ],
      ),
      _GuideSubsection(
        id: 'recommendations',
        title: 'Where recommendations are used',
        paragraphs: [
          'Calculators compare each transfer or weighed mass with active tools. Master Mix and Serial Dilution outputs show the recommended pipette, cylinder, or balance and warn when an amount is near a limit or cannot be measured accurately.',
        ],
        bullets: [
          'Disable equipment that is not currently available.',
          'Edit ranges and increments to match the actual laboratory equipment.',
          'Use Add Tool for custom pipettes, cylinders, or balances.',
        ],
      ),
    ],
  ),
  _GuideSection(
    id: 'tables',
    title: 'Tables',
    icon: Icons.table_chart_outlined,
    subsections: [
      _GuideSubsection(
        id: 'saved_tables',
        title: 'Standalone and saved tables',
        paragraphs: [
          'Lab Tools creates standalone tables. Save useful results to Tables so they can be reviewed, exported, copied, or reused later.',
        ],
      ),
      _GuideSubsection(
        id: 'protocol_tables',
        title: 'Tables inside protocols',
        paragraphs: [
          'A protocol can contain reference tables and tables linked to specific steps. Linked tables appear where they are needed; unlinked reference tables remain available from Files during a protocol run.',
        ],
      ),
      _GuideSubsection(
        id: 'material_list',
        title: 'Material List',
        paragraphs: [
          'The Material List is a dedicated protocol table for reagents, quantities, stock concentrations, catalog numbers, and manufacturers.',
        ],
      ),
    ],
  ),
  _GuideSection(
    id: 'protocols',
    title: 'Building Protocols',
    icon: Icons.edit_note,
    subsections: [
      _GuideSubsection(
        id: 'create',
        title: 'Create a protocol or template',
        steps: [
          'Choose New protocol from Home.',
          'Enter a title and optionally assign a project.',
          'Choose whether the item is a protocol or reusable template.',
          'Add materials, steps, notes, tables, links, and files as needed.',
          'Review the protocol and save it to the Library.',
        ],
      ),
      _GuideSubsection(
        id: 'steps_tables',
        title: 'Steps, notes, and tables',
        paragraphs: [
          'Write one actionable operation per step where practical. Attach a table to the step that uses it. Keep general reference tables unlinked so they remain available without crowding an individual step.',
        ],
      ),
      _GuideSubsection(
        id: 'templates',
        title: 'Templates',
        paragraphs: [
          'Templates preserve a reusable protocol structure. Create a protocol from a template when the workflow repeats but sample names, dates, or conditions change.',
        ],
      ),
    ],
  ),
  _GuideSection(
    id: 'projects',
    title: 'Projects',
    icon: Icons.folder_copy_outlined,
    subsections: [
      _GuideSubsection(
        id: 'project_purpose',
        title: 'What a project is',
        paragraphs: [
          'A project is a color-coded organizational label shared by related protocols and templates. It does not create a separate copy of the protocol.',
        ],
      ),
      _GuideSubsection(
        id: 'project_workflow',
        title: 'Create, assign, and filter',
        steps: [
          'Open Projects from the sidebar and create a named, colored project.',
          'Assign the project while creating or editing a protocol or template.',
          'Select a project card to open the Library with that project filter.',
          'Use the project filter in Library and Dashboard to focus the displayed data.',
        ],
      ),
    ],
  ),
  _GuideSection(
    id: 'lifecycle',
    title: 'Library and Protocol Runs',
    icon: Icons.library_books_outlined,
    subsections: [
      _GuideSubsection(
        id: 'library',
        title: 'Library tabs and filters',
        paragraphs: [
          'The Library brings together protocols, templates, running protocols, and completed history. Use the project filter to show all projects, one project, or unassigned items.',
        ],
      ),
      _GuideSubsection(
        id: 'run',
        title: 'Run and complete a protocol',
        paragraphs: [
          'Starting a run creates a working instance. Follow steps, record notes and data, and use Files for attachments and unlinked reference tables. Completing the run moves its record to completed history with completion metadata.',
        ],
      ),
    ],
  ),
  _GuideSection(
    id: 'data_tools',
    title: 'Dashboard, Import, and Export',
    icon: Icons.dashboard_outlined,
    subsections: [
      _GuideSubsection(
        id: 'dashboard',
        title: 'Dashboard',
        paragraphs: [
          'Dashboard summarizes protocol status, activity, task progress, tool usage, data health, sync state, and local/synced data footprint. Filters change the view; they do not delete data.',
        ],
      ),
      _GuideSubsection(
        id: 'export',
        title: 'Import and export',
        paragraphs: [
          'Use Import / Export in the sidebar for backups and interchange. JSON preserves ProtocolFlow structure. Document and table formats are useful for sharing or review but may not preserve every editable app field.',
        ],
      ),
    ],
  ),
  _GuideSection(
    id: 'troubleshooting',
    title: 'Troubleshooting',
    icon: Icons.help_outline,
    subsections: [
      _GuideSubsection(
        id: 'sync_issues',
        title: 'Sync does not complete',
        bullets: [
          'Confirm the device is online and the intended Google account is signed in.',
          'Use Sync from the sidebar and approve Drive access if prompted.',
          'Check Dashboard data health for pending or error states.',
          'Export important local data before signing out, clearing browser storage, or reinstalling.',
        ],
      ),
      _GuideSubsection(
        id: 'measurement_warnings',
        title: 'Measurement warnings',
        paragraphs: [
          'A warning means the calculated amount is outside an active tool range, near a preferred minimum, or impractical as a direct transfer. Adjust Measuring Tools to match the lab, scale the preparation, or make an intermediate stock.',
        ],
      ),
    ],
  ),
];
