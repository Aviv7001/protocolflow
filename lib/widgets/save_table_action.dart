import 'package:flutter/material.dart';

import '../models/protocol_table.dart';
import '../services/storage_service.dart';

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
    await StorageService().upsertSavedTable(table.deepCopy());
    if (!context.mounted) return;
    final title = table.title.isEmpty ? 'Untitled Table' : table.title;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('"$title" saved to Saved Tables')));
  }
}
