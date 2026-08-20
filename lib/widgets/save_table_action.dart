import 'package:flutter/material.dart';

import '../models/protocol_table.dart';
import '../services/storage_service.dart';
import 'save_table_dialog.dart';

class SaveTableAction extends StatelessWidget {
  const SaveTableAction({super.key, required this.table});

  final ProtocolTable table;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.bookmark_add_outlined),
      tooltip: 'Save to Saved Tables',
      onPressed: () => _save(context),
    );
  }

  Future<void> _save(BuildContext context) async {
    final details = await showSaveTableDialog(
      context,
      suggestedName: table.title.isEmpty ? 'Untitled Table' : table.title,
      initialProjectId: table.projectId,
    );
    if (details == null || !context.mounted) return;
    final copy = details.projectId == null
        ? table.deepCopy().copyWith(title: details.name, clearProjectId: true)
        : table.deepCopy().copyWith(
            title: details.name,
            projectId: details.projectId,
          );
    await StorageService().upsertSavedTable(copy);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${details.name}" saved to Saved Tables')),
    );
  }
}
