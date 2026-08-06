import 'package:flutter/material.dart';

import '../models/protocol.dart';
import '../models/published_protocol_manifest.dart';
import '../models/published_protocol_package.dart';
import '../services/auth_service.dart';
import '../services/drive_sync_service.dart';
import '../services/protocol_publication_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/date_time_format.dart';
import '../widgets/protocolflow_app_bar.dart';
import 'home_screen.dart';

class SharedProtocolImportScreen extends StatefulWidget {
  const SharedProtocolImportScreen({
    super.key,
    required this.shareUri,
    this.publicationService,
  });

  final String shareUri;
  final ProtocolPublicationService? publicationService;

  @override
  State<SharedProtocolImportScreen> createState() =>
      _SharedProtocolImportScreenState();
}

class _SharedProtocolImportScreenState
    extends State<SharedProtocolImportScreen> {
  final StorageService _storage = StorageService();
  late final ProtocolPublicationService _publicationService;
  PublishedProtocolManifest? _manifest;
  PublishedProtocolPackage? _package;
  Protocol? _existingImport;
  String? _error;
  bool _loading = true;
  bool _versionLoading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _publicationService =
        widget.publicationService ?? ProtocolPublicationService.instance;
    _load();
  }

  Future<void> _load() async {
    try {
      final download = await _publicationService.downloadSharedPublication(
        widget.shareUri,
      );
      final package = download.package;
      final protocols = await _storage.loadProtocols();
      Protocol? existing;
      for (final protocol in protocols) {
        if (protocol.importSource?.publicationId == package.publicationId) {
          existing = protocol;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _manifest = download.manifest;
        _package = package;
        _existingImport = existing;
        _loading = false;
      });
    } on PublicationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Shared protocol import failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _error = 'The shared protocol could not be opened.';
        _loading = false;
      });
    }
  }

  Future<void> _selectVersion(int version) async {
    if (_package?.version == version || _versionLoading) return;
    setState(() => _versionLoading = true);
    try {
      final download = await _publicationService.downloadSharedPublication(
        widget.shareUri,
        version: version,
      );
      if (!mounted) return;
      setState(() {
        _manifest = download.manifest;
        _package = download.package;
        _versionLoading = false;
      });
    } on PublicationException catch (error) {
      if (!mounted) return;
      setState(() => _versionLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _versionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That version could not be loaded.')),
      );
    }
  }

  Future<void> _confirmReplace() async {
    final existing = _existingImport;
    final package = _package;
    if (existing == null || package == null) return;
    final existingVersion = existing.importSource?.version;
    final isDowngrade =
        existingVersion != null && existingVersion > package.version;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isDowngrade
              ? 'Replace with an older version?'
              : 'Replace imported protocol?',
        ),
        content: Text(
          'This will replace "${existing.title}" (version $existingVersion) with published version ${package.version}. Any local edits in that imported copy will be overwritten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (approved == true) await _import(replaceExisting: true);
  }

  Future<void> _import({required bool replaceExisting}) async {
    final package = _package;
    if (package == null || _saving) return;
    setState(() => _saving = true);
    final user = AuthService.instance.currentUser;
    final existing = replaceExisting ? _existingImport : null;
    var imported = package.toImportedProtocol(
      shareUri: widget.shareUri,
      localProtocolId: existing?.id,
      ownerId: user?.googleUserId,
      syncStatus: user == null
          ? ProtocolSyncStatus.localOnly
          : ProtocolSyncStatus.modified,
      projectId: existing?.projectId,
      originalCreatedAt: existing?.createdAt,
    );
    await _storage.upsertProtocol(imported);
    if (user != null) {
      imported = await DriveSyncService.instance.syncProtocolAfterLocalSave(
        imported,
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          replaceExisting
              ? 'Imported protocol updated to version ${package.version}.'
              : '"${imported.title}" added to the Library.',
        ),
      ),
    );
    if (Navigator.canPop(context)) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: ProtocolFlowAppBar(title: 'Import Protocol'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading shared protocol...'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.link_off_outlined,
                size: 44,
                color: AppColors.error,
              ),
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _load();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    final package = _package!;
    final manifest = _manifest!;
    final existing = _existingImport;
    final existingVersion = existing?.importSource?.version;
    final canReplace = existing != null && existingVersion != package.version;
    final isDowngrade =
        existingVersion != null && existingVersion > package.version;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.public, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'SHARED PROTOCOL',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        package.protocol.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      if (manifest.versions.length > 1) ...[
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Published version',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.history),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              key: const Key(
                                'shared-protocol-version-selector',
                              ),
                              value: package.version,
                              isExpanded: true,
                              items: manifest.versions.reversed.map((entry) {
                                final latest =
                                    entry.version == manifest.latestVersion;
                                return DropdownMenuItem<int>(
                                  value: entry.version,
                                  child: Text(
                                    'Version ${entry.version}${latest ? ' (Latest)' : ''} - ${formatDate(entry.publishedAt)}',
                                  ),
                                );
                              }).toList(),
                              onChanged: _versionLoading || _saving
                                  ? null
                                  : (value) {
                                      if (value != null) _selectVersion(value);
                                    },
                            ),
                          ),
                        ),
                        if (_versionLoading) const LinearProgressIndicator(),
                        const SizedBox(height: 14),
                      ],
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          Text('Version ${package.version}'),
                          Text('Published ${formatDate(package.publishedAt)}'),
                          Text('By ${package.authorName ?? 'Anonymous'}'),
                        ],
                      ),
                      const Divider(height: 32),
                      _PreviewField(
                        title: 'Objective',
                        value: package.protocol.objective,
                      ),
                      const SizedBox(height: 18),
                      _PreviewField(
                        title: 'Description',
                        value: package.protocol.description,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 14,
                    children: [
                      _CountItem(
                        icon: Icons.format_list_numbered,
                        label: '${package.protocol.steps.length} steps',
                      ),
                      _CountItem(
                        icon: Icons.inventory_2_outlined,
                        label: '${package.protocol.materials.length} materials',
                      ),
                      _CountItem(
                        icon: Icons.table_chart_outlined,
                        label: '${package.protocol.tables.length} tables',
                      ),
                      const _CountItem(
                        icon: Icons.attach_file,
                        label: 'Local attachments excluded',
                      ),
                    ],
                  ),
                ),
              ),
              if (existing != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    canReplace
                        ? isDowngrade
                              ? 'Version $existingVersion is in your Library. Replacing it with older version ${package.version} requires confirmation and will overwrite local edits.'
                              : 'Version $existingVersion is in your Library. Replacing it with version ${package.version} requires confirmation and will overwrite local edits.'
                        : 'Version $existingVersion is already in your Library. You can still import another independent copy.',
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (canReplace)
                FilledButton.icon(
                  onPressed: _saving || _versionLoading
                      ? null
                      : _confirmReplace,
                  icon: Icon(
                    isDowngrade ? Icons.history : Icons.system_update_alt,
                  ),
                  label: Text(
                    isDowngrade
                        ? 'Replace with older version'
                        : 'Replace imported version',
                  ),
                ),
              if (canReplace) const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _saving || _versionLoading
                    ? null
                    : () => _import(replaceExisting: false),
                icon: const Icon(Icons.library_add_outlined),
                label: Text(
                  existing == null
                      ? 'Add to Library'
                      : 'Import as another copy',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewField extends StatelessWidget {
  const _PreviewField({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(value.trim().isEmpty ? 'Not provided.' : value),
      ],
    );
  }
}

class _CountItem extends StatelessWidget {
  const _CountItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
