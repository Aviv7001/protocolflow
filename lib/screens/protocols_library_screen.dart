import 'package:flutter/material.dart';

import '../data/mock_protocols.dart';
import '../models/protocol.dart';
import '../services/storage_service.dart';
import 'protocol_detail_screen.dart';

class ProtocolsLibraryScreen extends StatefulWidget {
  const ProtocolsLibraryScreen({super.key});

  @override
  State<ProtocolsLibraryScreen> createState() => _ProtocolsLibraryScreenState();
}

class _ProtocolsLibraryScreenState extends State<ProtocolsLibraryScreen> {
  final StorageService _storageService = StorageService();
  List<Protocol> protocols = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProtocols();
  }

  Future<void> _loadProtocols() async {
    setState(() => _isLoading = true);
    final loadedProtocols = await _storageService.loadProtocols();
    if (loadedProtocols.isEmpty) {
      protocols = getMockProtocols();
      await _storageService.saveProtocols(protocols);
    } else {
      protocols = loadedProtocols;
    }
    setState(() => _isLoading = false);
  }

  void _openProtocol(BuildContext context, Protocol protocol) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ProtocolDetailScreen(protocol: protocol),
      ),
    );
  }

  Future<void> _createNewProtocol() async {
    final dynamic result = await Navigator.pushNamed(context, '/create');

    if (result != null && result is Protocol) {
      _loadProtocols();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Protocols Library'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: protocols.length,
              itemBuilder: (context, index) {
                final protocol = protocols[index];

                return ListTile(
                  leading: const Icon(Icons.radio_button_unchecked, color: Colors.blueGrey),
                  title: Text(protocol.title),
                  subtitle: Text(protocol.objective, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openProtocol(context, protocol),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewProtocol,
        child: const Icon(Icons.add),
      ),
    );
  }
}
