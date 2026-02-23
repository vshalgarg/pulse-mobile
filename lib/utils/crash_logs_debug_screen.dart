import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:app/utils/CrashLogger.dart';

class CrashLogsDebugScreen extends StatefulWidget {
  const CrashLogsDebugScreen({super.key});

  @override
  State<CrashLogsDebugScreen> createState() => _CrashLogsDebugScreenState();
}

class _CrashLogsDebugScreenState extends State<CrashLogsDebugScreen> {
  List<String> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<Directory> _getCrashesDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return Directory('${dir.path}/crashes');
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);

    try {
      final crashDir = await _getCrashesDir();
      if (!await crashDir.exists()) {
        if (mounted) setState(() {
          _logs = [];
          _loading = false;
        });
        return;
      }
      final files = await crashDir
          .list()
          .where((e) => e is File && e.path.endsWith('.json'))
          .cast<File>()
          .toList();
      files.sort((a, b) => b.path.compareTo(a.path)); // newest first

      final List<String> entries = [];
      for (final file in files) {
        try {
          final content = await file.readAsString();
          final map = jsonDecode(content) as Map<String, dynamic>;
          final time = map['time']?.toString() ?? '';
          final error = map['error']?.toString() ?? '';
          final stack = map['stack']?.toString() ?? '';
          entries.add('[$time]\n$error\n${stack.isNotEmpty ? stack : ''}');
        } catch (_) {}
      }
      if (mounted) setState(() => _logs = entries);
    } catch (e) {
      if (mounted) setState(() => _logs = ['Error reading logs: $e']);
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _triggerTestCrash() async {
    await CrashLogger().logCrash(
      Exception('Intentional test crash – verifying CrashLogger'),
      StackTrace.current,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test crash logged. Pull to refresh to see it.'),
        backgroundColor: Colors.green,
      ),
    );
    await _loadLogs();
  }

  Future<void> _clearLogs() async {
    final crashDir = await _getCrashesDir();
    if (await crashDir.exists()) {
      for (final entity in await crashDir.list().toList()) {
        if (entity is File) await entity.delete();
      }
    }
    await _loadLogs();
  }

  Future<void> _uploadLogs() async {
    // 🔁 TODO: connect your LogPushService here

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Upload triggered (implement API call)'),
      ),
    );
  }

  void _showLog(String log) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: SelectableText(log),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crash Logs Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
          // IconButton(
          //   icon: const Icon(Icons.cloud_upload),
          //   onPressed: _uploadLogs,
          // ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
          ),
        ],
      ),
      
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('No crash logs found'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final log = _logs[index];

                    return InkWell(
                      onTap: () => _showLog(log),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 6,
                              color: Colors.black12,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                        child: Text(
                          log.length > 120
                              ? '${log.substring(0, 120)}...'
                              : log,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
