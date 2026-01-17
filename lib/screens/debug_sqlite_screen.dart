import 'package:flutter/material.dart';
import '../utils/debug_sqlite_helper.dart';
import '../utils/logger.dart';

class DebugSQLiteScreen extends StatefulWidget {
  const DebugSQLiteScreen({super.key});

  @override
  State<DebugSQLiteScreen> createState() => _DebugSQLiteScreenState();
}

class _DebugSQLiteScreenState extends State<DebugSQLiteScreen> {
  String _debugOutput = '';

  void _addToOutput(String message) {
    setState(() {
      _debugOutput += '$message\n';
    });
  }

  @override
  void initState() {
    super.initState();
    _addToOutput('Debug SQLite Screen initialized');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug SQLite Database'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Action buttons
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    _addToOutput('=== Printing All Data ===');
                    await DebugSQLiteHelper.printAllData();
                    _addToOutput('Check console/logs for detailed output');
                  },
                  child: const Text('Print All Data'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    _addToOutput('=== Testing Site Data ===');
                    // You can change this ID to test different sites
                    await DebugSQLiteHelper.printSiteData(12345);
                    _addToOutput('Check console/logs for detailed output');
                  },
                  child: const Text('Test Site 12345'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    _addToOutput('=== Testing Model Reconstruction ===');
                    await DebugSQLiteHelper.testAssetAuditModelReconstruction(12345);
                    _addToOutput('Check console/logs for detailed output');
                  },
                  child: const Text('Test Model Reconstruction'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _debugOutput = '';
                    });
                  },
                  child: const Text('Clear Output'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    _addToOutput('=== Clearing All Data ===');
                    await DebugSQLiteHelper.clearAllData();
                    _addToOutput('All data cleared');
                  },
                  child: const Text('Clear All Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Output area
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _debugOutput.isEmpty ? 'No output yet. Tap buttons above to debug.' : _debugOutput,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
