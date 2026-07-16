import 'package:flutter/material.dart';

import 'table_selection_screen.dart';

class LabToolsScreen extends StatelessWidget {
  final bool embedded;
  const LabToolsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    return TableSelectionScreen(
      title: 'Lab Tools',
      subtitle: 'Build, copy, export, and save standalone lab tables',
      standaloneMode: true,
      embedded: embedded,
    );
  }
}
