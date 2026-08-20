import 'package:flutter/material.dart';

import '../widgets/protocolflow_app_bar.dart';
import 'library_screen.dart';

class ProtocolsScreen extends StatelessWidget {
  const ProtocolsScreen({super.key, this.initialProjectId});

  final String? initialProjectId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProtocolFlowAppBar(title: 'Protocols'),
      body: LibraryScreen(
        embedded: true,
        initialTabIndex: 1,
        initialProjectId: initialProjectId,
      ),
    );
  }
}
