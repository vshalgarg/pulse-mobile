import 'package:flutter/material.dart';
import '../services/location_permission_service.dart';
import '../services/location_service.dart';
import '../utils/location_test_helper.dart';

class LocationTestWidget extends StatefulWidget {
  const LocationTestWidget({Key? key}) : super(key: key);

  @override
  State<LocationTestWidget> createState() => _LocationTestWidgetState();
}

class _LocationTestWidgetState extends State<LocationTestWidget> {
  Map<String, dynamic>? _permissionStatus;
  Map<String, dynamic>? _locationResult;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await LocationPermissionService.getPermissionStatus();
      setState(() {
        _permissionStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error checking permission status: $e');
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await LocationPermissionService.requestLocationPermissions();
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );
      
      // Refresh permission status
      await _checkPermissionStatus();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error requesting permissions: $e');
    }
  }

  Future<void> _testLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await LocationTestHelper.testLocationService();
      setState(() {
        _locationResult = result;
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['success'] 
            ? 'Location test successful: ${result['latitude']}, ${result['longitude']}'
            : 'Location test failed: ${result['error']}'),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error testing location: $e');
    }
  }

  Future<void> _openSettings() async {
    await LocationPermissionService.openLocationSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Permission Status',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_permissionStatus != null) ...[
                      Text('Fine Location: ${_permissionStatus!['fineLocation']}'),
                      Text('Coarse Location: ${_permissionStatus!['coarseLocation']}'),
                      Text('Location Service: ${_permissionStatus!['locationServiceEnabled']}'),
                      Text('Has Any Permission: ${_permissionStatus!['hasAnyPermission']}'),
                    ] else
                      const Text('Loading...'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Location Test Result',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_locationResult != null) ...[
                      Text('Success: ${_locationResult!['success']}'),
                      Text('Latitude: ${_locationResult!['latitude']}'),
                      Text('Longitude: ${_locationResult!['longitude']}'),
                      Text('Method: ${_locationResult!['method']}'),
                      if (_locationResult!['error'] != null)
                        Text('Error: ${_locationResult!['error']}'),
                    ] else
                      const Text('No test results yet'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _requestPermissions,
              child: const Text('Request Location Permissions'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testLocation,
              child: const Text('Test Location Service'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _openSettings,
              child: const Text('Open App Settings'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _checkPermissionStatus,
              child: const Text('Refresh Status'),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
