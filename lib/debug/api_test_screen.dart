// lib/debug/api_test_screen.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  String _testResults = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('API Connectivity Test'),
        backgroundColor: const Color(0xFF003f9b),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Config Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Configuration',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text('API Base URL: ${AppConfig.apiBaseUrl}'),
                  Text('Is Production: ${AppConfig.isProduction}'),
                  Text('Debug Prints: ${AppConfig.enableDebugPrints}'),
                  Text('Has Auth Token: ${AuthService.hasToken}'),
                  if (AuthService.hasToken)
                    Text('Token: ${AuthService.token?.substring(0, 20)}...'),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Test Buttons
            ElevatedButton(
              onPressed: _isLoading ? null : _testApiConnectivity,
              child: _isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Testing...'),
                      ],
                    )
                  : Text('Test API Connectivity'),
            ),

            SizedBox(height: 8),

            ElevatedButton(
              onPressed: _isLoading ? null : _testProfileEndpoint,
              child: Text('Test Profile Endpoint'),
            ),

            SizedBox(height: 16),

            // Results
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _testResults.isEmpty ? 'No tests run yet.' : _testResults,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),

            SizedBox(height: 16),

            ElevatedButton(
              onPressed: _clearResults,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
              ),
              child: Text('Clear Results'),
            ),
          ],
        ),
      ),
    );
  }

  void _testApiConnectivity() async {
    setState(() {
      _isLoading = true;
      _testResults += '\n=== API Connectivity Test ===\n';
      _testResults += 'Starting connectivity test...\n';
    });

    try {
      // Test basic connectivity with a simple endpoint
      final response = await ApiService.get('/health');

      setState(() {
        _testResults += '✅ API connectivity successful!\n';
        _testResults += 'Response: $response\n';
      });
    } catch (e) {
      setState(() {
        _testResults += '❌ API connectivity failed!\n';
        _testResults += 'Error: $e\n';
        _testResults += 'Error type: ${e.runtimeType}\n';
      });
    } finally {
      setState(() {
        _isLoading = false;
        _testResults += 'Test completed.\n\n';
      });
    }
  }

  void _testProfileEndpoint() async {
    setState(() {
      _isLoading = true;
      _testResults += '\n=== Profile Endpoint Test ===\n';
      _testResults += 'Testing profile endpoint...\n';
    });

    try {
      final response = await ApiService.get('/profile');

      setState(() {
        _testResults += '✅ Profile endpoint successful!\n';
        _testResults += 'Response keys: ${response.keys.toList()}\n';
        if (response['user'] != null) {
          _testResults += 'User data found: ${response['user']['name']}\n';
        }
      });
    } catch (e) {
      setState(() {
        _testResults += '❌ Profile endpoint failed!\n';
        _testResults += 'Error: $e\n';
        _testResults += 'Error type: ${e.runtimeType}\n';
      });
    } finally {
      setState(() {
        _isLoading = false;
        _testResults += 'Test completed.\n\n';
      });
    }
  }

  void _clearResults() {
    setState(() {
      _testResults = '';
    });
  }
}
