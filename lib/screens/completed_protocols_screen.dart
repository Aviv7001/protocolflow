import 'package:flutter/material.dart';
import '../data/completed_protocols_data.dart';
import '../theme/app_colors.dart';
import 'completed_protocol_detail_screen.dart';
import '../utils/date_time_format.dart';

class CompletedProtocolsScreen extends StatefulWidget {
  const CompletedProtocolsScreen({super.key});

  @override
  State<CompletedProtocolsScreen> createState() =>
      _CompletedProtocolsScreenState();
}

class _CompletedProtocolsScreenState extends State<CompletedProtocolsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Completed Protocols')),
      body: completedProtocols.isEmpty
          ? const Center(child: Text('No completed protocols yet.'))
          : ListView.builder(
              itemCount: completedProtocols.length,
              itemBuilder: (context, index) {
                final completed = completedProtocols[index];
                final dateStr = formatDateTime(completed.completedAt);

                return ListTile(
                  leading: const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                  ),
                  title: Text(completed.protocol.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Completed on: $dateStr'),
                      Text(
                        'Completed by: '
                        '${completed.completedByName ?? 'Unknown user'}',
                      ),
                    ],
                  ),
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
