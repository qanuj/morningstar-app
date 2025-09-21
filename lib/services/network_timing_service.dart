// lib/services/network_timing_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NetworkTiming {
  final DateTime startTime;
  DateTime? dnsResolutionTime;
  DateTime? connectionTime;
  DateTime? tlsHandshakeTime;
  DateTime? requestSentTime;
  DateTime? firstByteTime;
  DateTime? endTime;
  String? error;
  int? statusCode;
  int? responseSize;
  String? host;
  String? method;
  String? path;

  NetworkTiming({required this.startTime});

  Duration get totalDuration => endTime != null
      ? endTime!.difference(startTime)
      : DateTime.now().difference(startTime);

  Duration? get dnsResolutionDuration => dnsResolutionTime?.difference(startTime);
  Duration? get connectionDuration => connectionTime?.difference(dnsResolutionTime ?? startTime);
  Duration? get tlsHandshakeDuration => tlsHandshakeTime?.difference(connectionTime ?? dnsResolutionTime ?? startTime);
  Duration? get requestSentDuration => requestSentTime?.difference(tlsHandshakeTime ?? connectionTime ?? dnsResolutionTime ?? startTime);
  Duration? get firstByteDuration => firstByteTime?.difference(requestSentTime ?? startTime);
  Duration? get downloadDuration => endTime?.difference(firstByteTime ?? requestSentTime ?? startTime);

  Map<String, dynamic> toJson() => {
    'startTime': startTime.toIso8601String(),
    'dnsResolutionTime': dnsResolutionTime?.toIso8601String(),
    'connectionTime': connectionTime?.toIso8601String(),
    'tlsHandshakeTime': tlsHandshakeTime?.toIso8601String(),
    'requestSentTime': requestSentTime?.toIso8601String(),
    'firstByteTime': firstByteTime?.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'error': error,
    'statusCode': statusCode,
    'responseSize': responseSize,
    'host': host,
    'method': method,
    'path': path,
    'totalDuration': totalDuration.inMilliseconds,
    'dnsResolutionDuration': dnsResolutionDuration?.inMilliseconds,
    'connectionDuration': connectionDuration?.inMilliseconds,
    'tlsHandshakeDuration': tlsHandshakeDuration?.inMilliseconds,
    'requestSentDuration': requestSentDuration?.inMilliseconds,
    'firstByteDuration': firstByteDuration?.inMilliseconds,
    'downloadDuration': downloadDuration?.inMilliseconds,
  };

  String get formattedLog {
    final buffer = StringBuffer();
    buffer.writeln('🔍 Network Timing Analysis for $method $host$path');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (error != null) {
      buffer.writeln('❌ Error: $error');
    } else {
      buffer.writeln('✅ Status: ${statusCode ?? 'Unknown'}');
    }

    buffer.writeln('📊 Timing Breakdown:');
    if (dnsResolutionDuration != null) {
      buffer.writeln('  🌐 DNS Resolution: ${dnsResolutionDuration!.inMilliseconds}ms');
    }
    if (connectionDuration != null) {
      buffer.writeln('  🔗 Connection: ${connectionDuration!.inMilliseconds}ms');
    }
    if (tlsHandshakeDuration != null) {
      buffer.writeln('  🔒 TLS Handshake: ${tlsHandshakeDuration!.inMilliseconds}ms');
    }
    if (requestSentDuration != null) {
      buffer.writeln('  📤 Request Sent: ${requestSentDuration!.inMilliseconds}ms');
    }
    if (firstByteDuration != null) {
      buffer.writeln('  ⚡ First Byte (TTFB): ${firstByteDuration!.inMilliseconds}ms');
    }
    if (downloadDuration != null) {
      buffer.writeln('  📥 Download: ${downloadDuration!.inMilliseconds}ms');
    }

    buffer.writeln('  🎯 Total Time: ${totalDuration.inMilliseconds}ms');

    if (responseSize != null) {
      buffer.writeln('  📦 Response Size: ${(responseSize! / 1024).toStringAsFixed(1)}KB');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    return buffer.toString();
  }
}

class NetworkTimingService {
  static final List<NetworkTiming> _timings = [];
  static bool _enabled = true;

  static bool get enabled => _enabled;
  static void setEnabled(bool enabled) => _enabled = enabled;

  static List<NetworkTiming> get timings => List.unmodifiable(_timings);

  static void clearTimings() => _timings.clear();

  static void addTiming(NetworkTiming timing) {
    if (!_enabled) return;

    _timings.add(timing);

    // Keep only last 50 timings to prevent memory leaks
    if (_timings.length > 50) {
      _timings.removeAt(0);
    }

    // Print detailed timing log
    debugPrint(timing.formattedLog);
  }

  /// Get average timing metrics
  static Map<String, double> getAverageMetrics() {
    if (_timings.isEmpty) return {};

    final validTimings = _timings.where((t) => t.error == null).toList();
    if (validTimings.isEmpty) return {};

    return {
      'avgTotalTime': validTimings
          .map((t) => t.totalDuration.inMilliseconds.toDouble())
          .reduce((a, b) => a + b) / validTimings.length,
      'avgDnsTime': validTimings
          .where((t) => t.dnsResolutionDuration != null)
          .map((t) => t.dnsResolutionDuration!.inMilliseconds.toDouble())
          .fold(0.0, (a, b) => a + b) / validTimings.length,
      'avgConnectionTime': validTimings
          .where((t) => t.connectionDuration != null)
          .map((t) => t.connectionDuration!.inMilliseconds.toDouble())
          .fold(0.0, (a, b) => a + b) / validTimings.length,
      'avgTlsTime': validTimings
          .where((t) => t.tlsHandshakeDuration != null)
          .map((t) => t.tlsHandshakeDuration!.inMilliseconds.toDouble())
          .fold(0.0, (a, b) => a + b) / validTimings.length,
      'avgFirstByteTime': validTimings
          .where((t) => t.firstByteDuration != null)
          .map((t) => t.firstByteDuration!.inMilliseconds.toDouble())
          .fold(0.0, (a, b) => a + b) / validTimings.length,
    };
  }

  /// Detect slow operations
  static List<NetworkTiming> getSlowRequests({int thresholdMs = 2000}) {
    return _timings
        .where((t) => t.totalDuration.inMilliseconds > thresholdMs)
        .toList();
  }

  /// Get DNS resolution issues
  static List<NetworkTiming> getDnsIssues({int thresholdMs = 1000}) {
    return _timings
        .where((t) => t.dnsResolutionDuration != null &&
                     t.dnsResolutionDuration!.inMilliseconds > thresholdMs)
        .toList();
  }

  /// Get TLS handshake issues
  static List<NetworkTiming> getTlsIssues({int thresholdMs = 2000}) {
    return _timings
        .where((t) => t.tlsHandshakeDuration != null &&
                     t.tlsHandshakeDuration!.inMilliseconds > thresholdMs)
        .toList();
  }

  /// Print performance summary
  static void printPerformanceSummary() {
    if (_timings.isEmpty) {
      debugPrint('📊 No network timing data available');
      return;
    }

    final metrics = getAverageMetrics();
    final slowRequests = getSlowRequests();
    final dnsIssues = getDnsIssues();
    final tlsIssues = getTlsIssues();

    final buffer = StringBuffer();
    buffer.writeln('📊 Network Performance Summary');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📈 Requests Analyzed: ${_timings.length}');
    buffer.writeln('🎯 Average Total Time: ${metrics['avgTotalTime']?.toStringAsFixed(1)}ms');
    buffer.writeln('🌐 Average DNS Time: ${metrics['avgDnsTime']?.toStringAsFixed(1)}ms');
    buffer.writeln('🔗 Average Connection Time: ${metrics['avgConnectionTime']?.toStringAsFixed(1)}ms');
    buffer.writeln('🔒 Average TLS Time: ${metrics['avgTlsTime']?.toStringAsFixed(1)}ms');
    buffer.writeln('⚡ Average TTFB: ${metrics['avgFirstByteTime']?.toStringAsFixed(1)}ms');
    buffer.writeln('');
    buffer.writeln('🐌 Slow Requests (>2s): ${slowRequests.length}');
    buffer.writeln('🌐 DNS Issues (>1s): ${dnsIssues.length}');
    buffer.writeln('🔒 TLS Issues (>2s): ${tlsIssues.length}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    debugPrint(buffer.toString());
  }
}

/// Custom HTTP client with precise timing measurement
class TimedHttpClient extends http.BaseClient {
  final http.Client _inner;

  TimedHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final timing = NetworkTiming(startTime: DateTime.now());
    final uri = request.url;

    timing.host = uri.host;
    timing.method = request.method;
    timing.path = uri.path;

    try {
      // Create socket connection to measure precise timings
      Socket? socket;
      SecurityContext? securityContext;

      try {
        // Start DNS resolution timing
        final addresses = await InternetAddress.lookup(uri.host);
        timing.dnsResolutionTime = DateTime.now();

        debugPrint('🌐 DNS resolved ${uri.host} to ${addresses.first.address} in ${timing.dnsResolutionDuration!.inMilliseconds}ms');

        // Start connection timing

        if (uri.scheme == 'https') {
          // Create secure socket for HTTPS
          securityContext = SecurityContext.defaultContext;
          socket = await SecureSocket.connect(
            addresses.first.address,
            uri.port,
            context: securityContext,
          );
          timing.tlsHandshakeTime = DateTime.now();
          debugPrint('🔒 TLS handshake completed in ${timing.tlsHandshakeDuration!.inMilliseconds}ms');
        } else {
          // Create regular socket for HTTP
          socket = await Socket.connect(
            addresses.first.address,
            uri.port,
          );
        }

        timing.connectionTime = DateTime.now();
        debugPrint('🔗 Connection established in ${timing.connectionDuration!.inMilliseconds}ms');

        // Close the test socket
        await socket.close();

      } catch (e) {
        debugPrint('⚠️ Socket timing measurement failed: $e');
        // Continue with regular HTTP request even if socket timing fails
      }

      // Mark request sent time
      timing.requestSentTime = DateTime.now();

      // Send the actual HTTP request
      final response = await _inner.send(request);

      // Mark first byte received time
      timing.firstByteTime = DateTime.now();
      timing.statusCode = response.statusCode;

      debugPrint('📤 Request sent to ${uri.host}${uri.path}');
      debugPrint('⚡ First byte received in ${timing.firstByteDuration?.inMilliseconds ?? 0}ms');

      // Create a new response that measures download time
      final responseBytes = <int>[];
      final responseStream = response.stream.map((chunk) {
        responseBytes.addAll(chunk);
        return chunk;
      });

      final newResponse = http.StreamedResponse(
        responseStream,
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );

      // Listen for completion to mark end time
      newResponse.stream.listen(
        (chunk) {
          // Data is being received
        },
        onDone: () {
          timing.endTime = DateTime.now();
          timing.responseSize = responseBytes.length;
          NetworkTimingService.addTiming(timing);
        },
        onError: (error) {
          timing.endTime = DateTime.now();
          timing.error = error.toString();
          NetworkTimingService.addTiming(timing);
        },
      );

      return newResponse;

    } catch (e) {
      timing.endTime = DateTime.now();
      timing.error = e.toString();
      NetworkTimingService.addTiming(timing);
      rethrow;
    }
  }

  @override
  void close() {
    _inner.close();
  }
}