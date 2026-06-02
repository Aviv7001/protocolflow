import 'package:flutter/material.dart';
import '../data/completed_protocols_data.dart';
import 'completed_protocol_detail_screen.dart';

class CompletedProtocolsScreen extends StatefulWidget {
  const CompletedProtocolsScreen({super.key});

  @override
  State<CompletedProtocolsScreen> createState() => _CompletedProtocolsScreenState();
}

class _CompletedProtocolsScreenState extends State<CompletedProtocolsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completed Protocols'),
      ),
      body: completedProtocols.isEmpty
          ? const Center(
              child: Text('No completed protocols yet.'),
            )
          : ListView.builder(
              itemCount: completedProtocols.length,
              itemBuilder: (context, index) {
                final completed = completedProtocols[index];
                final date = completed.completedAt;
                final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                
                return ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(completed.protocol.title),
                  subtitle: Text('Completed on: $dateStr'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CompletedProtocolDetailScreen(
                          completedProtocol: completed,
                        ),
                      ),
                    );
                    // Refresh the list when returning from the detail screen
                    if (mounted) {
                      setState(() {});
                    }
                  },
                );
              },
            ),
    );
  }
}
