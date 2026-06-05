import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/create_protocol_screen.dart';
import 'screens/lab_tools_screen.dart';
import 'screens/saved_tables_screen.dart';
import 'theme/app_theme.dart';
import 'data/completed_protocols_data.dart';
import 'features/today_tasks/screens/task_history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadPersistentProtocols();
  runApp(const ProtocolFlowApp());
}

class ProtocolFlowApp extends StatelessWidget {
  const ProtocolFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProtocolFlow',
      debugShowCheckedModeBanner: false,
      theme: ProtocolFlowTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/create': (context) => const CreateProtocolScreen(),
        '/library': (context) => const LibraryScreen(),
        '/lab_tools': (context) => const LabToolsScreen(),
        '/saved_tables': (context) => const SavedTablesScreen(),
        '/task_history': (context) => const TaskHistoryScreen(),
      },
    );
  }
}
