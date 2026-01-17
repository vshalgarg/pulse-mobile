import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/app_colors.dart';
import '../utils/logger.dart';
import '../services/database_manager.dart';

class SQLiteQueryScreen extends StatefulWidget {
  const SQLiteQueryScreen({super.key});

  @override
  State<SQLiteQueryScreen> createState() => _SQLiteQueryScreenState();
}

class _SQLiteQueryScreenState extends State<SQLiteQueryScreen> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _resultsScrollController = ScrollController();
  
  List<Map<String, dynamic>> _queryResults = [];
  String _errorMessage = '';
  bool _isExecuting = false;
  String _executionTime = '';
  int _rowsAffected = 0;
  
  // Database manager instance
  final DatabaseManager _dbManager = DatabaseManager();

  @override
  void initState() {
    super.initState();
    _initializeDatabases();
    _loadSampleQueries();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _resultsScrollController.dispose();
    _closeDatabases();
    super.dispose();
  }

  Future<void> _initializeDatabases() async {
    try {
      // Initialize databases using the database manager
      await _dbManager.getDatabase('asset_audit');
      await _dbManager.getDatabase('image_upload');
      
      // Try to initialize local storage database if it exists
      try {
        await _dbManager.getDatabase('local_storage');
      } catch (e) {
        Logger.debugLog('Local storage database not found: $e');
      }
      
      Logger.debugLog('✅ Databases initialized successfully using DatabaseManager');
    } catch (e) {
      Logger.errorLog('❌ Error initializing databases: $e');
      setState(() {
        _errorMessage = 'Failed to initialize databases: $e';
      });
    }
  }

  Future<void> _closeDatabases() async {
    await _dbManager.closeDatabase('asset_audit');
    await _dbManager.closeDatabase('image_upload');
    await _dbManager.closeDatabase('local_storage');
  }

  void _loadSampleQueries() {
    _queryController.text = '''-- Sample queries to get you started
-- 1. Show all tables in asset audit database
SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';

-- 2. Get all raw API data
SELECT site_audit_sch_id, created_at FROM raw_api_data ORDER BY created_at DESC LIMIT 10;

-- 3. Get all images
SELECT unique_id, server_id, LENGTH(image_bytes) as size_bytes FROM images LIMIT 10;

-- 4. Get form data for all screens
SELECT screen_name, COUNT(*) as count FROM form_data GROUP BY screen_name;

-- 5. Get cached images
SELECT site_audit_sch_id, image_id, LENGTH(image_data) as size_bytes FROM cached_images LIMIT 10;''';
  }

  Future<void> _executeQuery() async {
    if (_queryController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a SQL query';
      });
      return;
    }

    setState(() {
      _isExecuting = true;
      _errorMessage = '';
      _queryResults = [];
      _executionTime = '';
      _rowsAffected = 0;
    });

    final stopwatch = Stopwatch()..start();

    try {
      // Split queries by semicolon and execute each one
      final queries = _queryController.text
          .split(';')
          .map((q) => q.trim())
          .where((q) => q.isNotEmpty)
          .toList();

      List<Map<String, dynamic>> allResults = [];
      int totalRowsAffected = 0;

      for (final query in queries) {
        if (query.trim().isEmpty) continue;
        
        final queryPreview = query.length > 100 ? '${query.substring(0, 100)}...' : query;
        Logger.debugLog('🔍 Executing query: $queryPreview');
        
        // Try each database until one succeeds
        List<Map<String, dynamic>>? results;
        int rowsAffected = 0;
        
        // Try Asset Audit Database first
        try {
          final assetAuditDb = await _dbManager.getDatabase('asset_audit');
          if (query.toLowerCase().startsWith('select') || 
              query.toLowerCase().startsWith('with') ||
              query.toLowerCase().startsWith('explain')) {
            results = await assetAuditDb.rawQuery(query);
          } else {
            rowsAffected = await assetAuditDb.rawUpdate(query);
          }
        } catch (e) {
          Logger.debugLog('Asset audit DB failed: $e');
        }
        
        // Try Image Upload Database if asset audit failed
        if (results == null && rowsAffected == 0) {
          try {
            final imageUploadDb = await _dbManager.getDatabase('image_upload');
            if (query.toLowerCase().startsWith('select') || 
                query.toLowerCase().startsWith('with') ||
                query.toLowerCase().startsWith('explain')) {
              results = await imageUploadDb.rawQuery(query);
            } else {
              rowsAffected = await imageUploadDb.rawUpdate(query);
            }
          } catch (e) {
            Logger.debugLog('Image upload DB failed: $e');
          }
        }
        
        // Try Local Storage Database if others failed
        if (results == null && rowsAffected == 0) {
          try {
            final localStorageDb = await _dbManager.getDatabase('local_storage');
            if (query.toLowerCase().startsWith('select') || 
                query.toLowerCase().startsWith('with') ||
                query.toLowerCase().startsWith('explain')) {
              results = await localStorageDb.rawQuery(query);
            } else {
              rowsAffected = await localStorageDb.rawUpdate(query);
            }
          } catch (e) {
            Logger.debugLog('Local storage DB failed: $e');
          }
        }
        
        if (results != null) {
          allResults.addAll(results);
        }
        totalRowsAffected += rowsAffected;
      }

      stopwatch.stop();
      
      setState(() {
        _queryResults = allResults;
        _executionTime = '${stopwatch.elapsedMilliseconds}ms';
        _rowsAffected = totalRowsAffected;
        _isExecuting = false;
      });

      Logger.debugLog('✅ Query executed successfully in ${stopwatch.elapsedMilliseconds}ms');
      Logger.debugLog('📊 Results: ${allResults.length} rows, $totalRowsAffected affected');
      
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _errorMessage = 'Query execution failed: $e';
        _isExecuting = false;
        _executionTime = '${stopwatch.elapsedMilliseconds}ms';
      });
      Logger.errorLog('❌ Query execution error: $e');
    }
  }

  void _clearResults() {
    setState(() {
      _queryResults = [];
      _errorMessage = '';
      _executionTime = '';
      _rowsAffected = 0;
    });
  }

  void _clearQuery() {
    _queryController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.green7,
      appBar: AppBar(
        title: const Text(
          'SQLite Query Executor',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.auditColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _clearResults,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear Results',
          ),
          IconButton(
            onPressed: _clearQuery,
            icon: const Icon(Icons.clear),
            tooltip: 'Clear Query',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Query Input Section
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.code, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            'SQL Query',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _isExecuting ? null : _executeQuery,
                            icon: _isExecuting 
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.play_arrow),
                            label: Text(_isExecuting ? 'Executing...' : 'Execute'),
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.auditColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: _queryController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Enter your SQL query here...\n\nTip: Use semicolons to separate multiple queries',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Results Section
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.table_chart, color: Colors.green),
                          const SizedBox(width: 8),
                          const Text(
                            'Query Results',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          if (_executionTime.isNotEmpty) ...[
                            Text(
                              'Time: $_executionTime',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (_rowsAffected > 0) ...[
                            Text(
                              'Rows: $_rowsAffected',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        child: _buildResultsContent(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsContent() {
    if (_isExecuting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Executing query...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red.shade600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_queryResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.query_stats,
              color: Colors.grey,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'No results yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Execute a query to see results here',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return _buildResultsTable();
  }

  Widget _buildResultsTable() {
    if (_queryResults.isEmpty) {
      return const Center(
        child: Text('No data to display'),
      );
    }

    // Get all unique column names
    final Set<String> allColumns = {};
    for (final row in _queryResults) {
      allColumns.addAll(row.keys);
    }
    final columns = allColumns.toList()..sort();

    return Column(
      children: [
        // Scroll indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.swipe_left,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                'Swipe horizontally to see all columns',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        // Scrollable table
        Expanded(
          child: SingleChildScrollView(
            controller: _resultsScrollController,
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTable(
                columnSpacing: 20,
                horizontalMargin: 12,
                columns: columns.map((column) => DataColumn(
                  label: Container(
                    constraints: const BoxConstraints(minWidth: 120),
                    child: Text(
                      column,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )).toList(),
                rows: _queryResults.map((row) => DataRow(
                  cells: columns.map((column) => DataCell(
                    Container(
                      constraints: const BoxConstraints(minWidth: 120, maxWidth: 300),
                      child: Text(
                        _formatCellValue(row[column]),
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )).toList(),
                )).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatCellValue(dynamic value) {
    if (value == null) return 'NULL';
    if (value is String) {
      // Truncate very long strings
      return value.length > 100 ? '${value.substring(0, 100)}...' : value;
    }
    return value.toString();
  }
}
