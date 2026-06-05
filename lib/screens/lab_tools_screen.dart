import 'package:flutter/material.dart';

import 'table_selection_screen.dart';

class LabToolsScreen extends StatelessWidget {
  const LabToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TableSelectionScreen(
      title: 'Lab Tools',
      subtitle: 'Build, copy, export, and save standalone lab tables',
      standaloneMode: true,
    );
  }
}
