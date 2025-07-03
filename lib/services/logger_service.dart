// // lib/services/logger_service.dart
// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:package_info_plus/package_info_plus.dart';

// enum LogLevel {
//   debug,
//   info,
//   warning,
//   error,
//   fatal,
// }

// class LogEntry {
//   final String id;
//   final DateTime timestamp;
//   final LogLevel level;
//   final String message;
//   final String? tag;
//   final Map<String, dynamic>? metadata;
//   final String? stackTrace;
//   final String? userId;
//   final String? clubId;
//   final String? screen;
//   final String? action;

//   LogEntry({
//     required this.id,
//     required this.timestamp,
//     required this.level,
//     required this.message,
//     this.tag,
//     this.metadata,
//     this.stackTrace,
//     this.userId,
//     this.clubId,
//     this.screen,
//     this.action,
//   });

//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'timestamp': timestamp.toIso8601String(),
//       'level': level.name,
//       'message': message,
//       'tag': tag,
//       'metadata': metadata,
//       'stackTrace': stackTrace,
//       'userId': userId,
//       'clubId': clubId,
//       'screen': screen,
//       'action': action,
//     };
//   }

//   factory LogEntry.fromJson(Map<String, dynamic> json) {
//     return LogEntry(
//       id: json['id'],
//       timestamp: DateTime.parse(json['timestamp']),
//       level: LogLevel.values.firstWhere((e) => e.name == json['level']),
//       message: json['message'],
//       tag: json['tag'],
//       metadata: json['metadata'],
//       stackTrace: json['stackTrace'],
//       userId: json['userId'],
//       clubId: json['clubId'],
//       screen: json['screen'],
//       action: json['action'],
//     );
//   }
// }

// class LoggerService {
//   static final LoggerService _instance = LoggerService._internal();
//   factory LoggerService() => _instance;
//   LoggerService._internal();

//   static const String _baseUrl = 'https://duggy.app/api';
//   static const String _logsEndpoint = '/logs';
//   static const int _maxLocalLogs = 1000;
//   static const int _batchSize = 50;

//   List<LogEntry> _logs = [];
//   String? _userId;
//   String? _clubId;
//   String? _currentScreen;
//   String? _deviceId;
//   String? _appVersion;
//   String? _deviceModel;
//   String? _osVersion;
//   bool _isInitialized = false;

//   // Initialize the logger service
//   Future<void> initialize() async {
//     if (_isInitialized) return;

//     try {
//       await _loadDeviceInfo();
//       await _loadUserInfo();
//       await _loadStoredLogs();
//       _isInitialized = true;
      
//       // Schedule periodic sync
//       _schedulePeriodicSync();
      
//       log(LogLevel.info, 'Logger service initialized', tag: 'LoggerService');
//     } catch (e) {
//       debugPrint('Failed to initialize logger: $e');
//     }
//   }

//   // Load device and app information
//   Future<void> _loadDeviceInfo() async {
//     try {
//       final deviceInfo = DeviceInfoPlugin();
//       final packageInfo = await PackageInfo.fromPlatform();
      
//       _appVersion = packageInfo.version;
      
//       if (Platform.isAndroid) {
//         final androidInfo = await deviceInfo.androidInfo;
//         _deviceId = androidInfo.id;
//         _deviceModel = androidInfo.model;
//         _osVersion = 'Android ${androidInfo.version.release}';
//       } else if (Platform.isIOS) {
//         final iosInfo = await deviceInfo.iosInfo;
//         _deviceId = iosInfo.identifierForVendor;
//         _deviceModel = iosInfo.model;
//         _osVersion = 'iOS ${iosInfo.systemVersion}';
//       }
//     } catch (e) {
//       debugPrint('Failed to load device info: $e');
//     }
//   }

//   // Load user information from shared preferences
//   Future<void> _loadUserInfo() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       _userId = prefs.getString('userId');
//       _clubId = prefs.getString('clubId');
//     } catch (e) {
//       debugPrint('Failed to load user info: $e');
//     }
//   }

//   // Update user context
//   void setUserContext({String? userId, String? clubId}) {
//     _userId = userId;
//     _clubId = clubId;
//   }

//   // Set current screen
//   void setCurrentScreen(String screen) {
//     _currentScreen = screen;
//   }

//   // Main logging method
//   void log(
//     LogLevel level,
//     String message, {
//     String? tag,
//     Map<String, dynamic>? metadata,
//     String? stackTrace,
//     String? screen,
//     String? action,
//   }) {
//     if (!_isInitialized) {
//       debugPrint('Logger not initialized: $message');
//       return;
//     }

//     final entry = LogEntry(
//       id: _generateId(),
//       timestamp: DateTime.now(),
//       level: level,
//       message: message,
//       tag: tag,
//       metadata: _enrichMetadata(metadata),
//       stackTrace: stackTrace,
//       userId: _userId,
//       clubId: _clubId,
//       screen: screen ?? _currentScreen,
//       action: action,
//     );

//     _logs.add(entry);
    
//     // Print to console in debug mode
//     if (kDebugMode) {
//       debugPrint('[${level.name.toUpperCase()}] $message');
//       if (stackTrace != null) {
//         debugPrint('Stack trace: $stackTrace');
//       }
//     }

//     // Maintain max logs limit
//     if (_logs.length > _maxLocalLogs) {
//       _logs.removeAt(0);
//     }

//     // Save to local storage
//     _saveLogsToStorage();

//     // Send critical logs immediately
//     if (level == LogLevel.error || level == LogLevel.fatal) {
//       _sendLogsToServer(force: true);
//     }
//   }

//   // Convenience methods for different log levels
//   void debug(String message, {String? tag, Map<String, dynamic>? metadata, String? action}) {
//     log(LogLevel.debug, message, tag: tag, metadata: metadata, action: action);
//   }

//   void info(String message, {String? tag, Map<String, dynamic>? metadata, String? action}) {
//     log(LogLevel.info, message, tag: tag, metadata: metadata, action: action);
//   }

//   void warning(String message, {String? tag, Map<String, dynamic>? metadata, String? action}) {
//     log(LogLevel.warning, message, tag: tag, metadata: metadata, action: action);
//   }

//   void error(String message, {String? tag, Map<String, dynamic>? metadata, String? stackTrace, String? action}) {
//     log(LogLevel.error, message, tag: tag, metadata: metadata, stackTrace: stackTrace, action: action);
//   }

//   void fatal(String message, {String? tag, Map<String, dynamic>? metadata, String? stackTrace, String? action}) {
//     log(LogLevel.fatal, message, tag: tag, metadata: metadata, stackTrace: stackTrace, action: action);
//   }

//   // Log API calls
//   void logApiCall(String method, String endpoint, {
//     int? statusCode,
//     String? requestBody,
//     String? responseBody,
//     int? duration,
//     String? error,
//   }) {
//     final metadata = {
//       'method': method,
//       'endpoint': endpoint,
//       'statusCode': statusCode,
//       'duration': duration,
//       if (requestBody != null) 'requestBody': requestBody,
//       if (responseBody != null) 'responseBody': responseBody,
//     };

//     final level = error != null ? LogLevel.error : LogLevel.info;
//     final message = error != null 
//         ? 'API Error: $method $endpoint - $error'
//         : 'API Call: $method $endpoint';

//     log(level, message, tag: 'API', metadata: metadata, action: 'api_call');
//   }

//   // Log user actions
//   void logUserAction(String action, {
//     String? screen,
//     Map<String, dynamic>? metadata,
//   }) {
//     log(
//       LogLevel.info,
//       'User action: $action',
//       tag: 'UserAction',
//       metadata: metadata,
//       screen: screen,
//       action: action,
//     );
//   }

//   // Log screen views
//   void logScreenView(String screenName, {Map<String, dynamic>? metadata}) {
//     setCurrentScreen(screenName);
//     log(
//       LogLevel.info,
//       'Screen view: $screenName',
//       tag: 'Navigation',
//       metadata: metadata,
//       screen: screenName,
//       action: 'screen_view',
//     );
//   }

//   // Log errors with stack trace
//   void logError(dynamic error, StackTrace? stackTrace, {
//     String? context,
//     Map<String, dynamic>? metadata,
//   }) {
//     log(
//       LogLevel.error,
//       context != null ? '$context: $error' : error.toString(),
//       tag: 'Error',
//       metadata: metadata,
//       stackTrace: stackTrace?.toString(),
//       action: 'error_occurred',
//     );
//   }

//   // Enrich metadata with device and app info
//   Map<String, dynamic> _enrichMetadata(Map<String, dynamic>? metadata) {
//     final enriched = metadata ?? {};
    
//     enriched.addAll({
//       'deviceId': _deviceId,
//       'deviceModel': _deviceModel,
//       'osVersion': _osVersion,
//       'appVersion': _appVersion,
//       'timestamp': DateTime.now().toIso8601String(),
//     });

//     return enriched;
//   }

//   // Generate unique ID for log entries
//   String _generateId() {
//     return DateTime.now().millisecondsSinceEpoch.toString() + 
//            (DateTime.now().microsecond % 1000).toString();
//   }

//   // Save logs to local storage
//   Future<void> _saveLogsToStorage() async {
//     try {
//       final directory = await getApplicationDocumentsDirectory();
//       final file = File('${directory.path}/logs.json');
      
//       final logsJson = _logs.map((log) => log.toJson()).toList();
//       await file.writeAsString(jsonEncode(logsJson));
//     } catch (e) {
//       debugPrint('Failed to save logs: $e');
//     }
//   }

//   // Load logs from local storage
//   Future<void> _loadStoredLogs() async {
//     try {
//       final directory = await getApplicationDocumentsDirectory();
//       final file = File('${directory.path}/logs.json');
      
//       if (await file.exists()) {
//         final content = await file.readAsString();
//         final List<dynamic> logsJson = jsonDecode(content);
        
//         _logs = logsJson
//             .map((json) => LogEntry.fromJson(json))
//             .toList();
//       }
//     } catch (e) {
//       debugPrint('Failed to load stored logs: $e');
//     }
//   }

//   // Send logs to server
//   Future<void> _sendLogsToServer({bool force = false}) async {
//     if (_logs.isEmpty) return;

//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final token = prefs.getString('token');
      
//       if (token == null) {
//         debugPrint('No auth token available for sending logs');
//         return;
//       }

//       // Send logs in batches
//       final logsToSend = _logs.take(_batchSize).toList();
      
//       final response = await http.post(
//         Uri.parse('$_baseUrl$_logsEndpoint'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//         body: jsonEncode({
//           'logs': logsToSend.map((log) => log.toJson()).toList(),
//           'deviceInfo': {
//             'deviceId': _deviceId,
//             'deviceModel': _deviceModel,
//             'osVersion': _osVersion,
//             'appVersion': _appVersion,
//           },
//         }),
//       );

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         // Remove successfully sent logs
//         _logs.removeRange(0, logsToSend.length);
//         await _saveLogsToStorage();
        
//         debugPrint('Successfully sent ${logsToSend.length} logs to server');
//       } else {
//         debugPrint('Failed to send logs: ${response.statusCode}');
//       }
//     } catch (e) {
//       debugPrint('Error sending logs to server: $e');
//     }
//   }

//   // Schedule periodic sync
//   void _schedulePeriodicSync() {
//     Timer.periodic(const Duration(minutes: 5), (timer) {
//       _sendLogsToServer();
//     });
//   }

//   // Manual sync
//   Future<void> syncLogs() async {
//     await _sendLogsToServer(force: true);
//   }

//   // Get logs for display
//   List<LogEntry> getLogs({
//     LogLevel? level,
//     String? tag,
//     DateTime? from,
//     DateTime? to,
//     int? limit,
//   }) {
//     var filteredLogs = _logs.where((log) {
//       if (level != null && log.level != level) return false;
//       if (tag != null && log.tag != tag) return false;
//       if (from != null && log.timestamp.isBefore(from)) return false;
//       if (to != null && log.timestamp.isAfter(to)) return false;
//       return true;
//     }).toList();

//     if (limit != null && filteredLogs.length > limit) {
//       filteredLogs = filteredLogs.sublist(filteredLogs.length - limit);
//     }

//     return filteredLogs;
//   }

//   // Clear logs
//   Future<void> clearLogs() async {
//     _logs.clear();
//     await _saveLogsToStorage();
//   }

//   // Export logs as JSON string
//   String exportLogs() {
//     return jsonEncode(_logs.map((log) => log.toJson()).toList());
//   }

//   // Get logs count
//   int getLogsCount() => _logs.length;

//   // Get logs by level count
//   Map<LogLevel, int> getLogsCountByLevel() {
//     final counts = <LogLevel, int>{};
//     for (final level in LogLevel.values) {
//       counts[level] = _logs.where((log) => log.level == level).length;
//     }
//     return counts;
//   }
// }

// // Extension for easy access
// extension LoggerExtension on Object {
//   void logDebug(String message, {String? tag, Map<String, dynamic>? metadata}) {
//     LoggerService().debug(message, tag: tag ?? runtimeType.toString(), metadata: metadata);
//   }

//   void logInfo(String message, {String? tag, Map<String, dynamic>? metadata}) {
//     LoggerService().info(message, tag: tag ?? runtimeType.toString(), metadata: metadata);
//   }

//   void logWarning(String message, {String? tag, Map<String, dynamic>? metadata}) {
//     LoggerService().warning(message, tag: tag ?? runtimeType.toString(), metadata: metadata);
//   }

//   void logError(String message, {String? tag, Map<String, dynamic>? metadata, String? stackTrace}) {
//     LoggerService().error(message, tag: tag ?? runtimeType.toString(), metadata: metadata, stackTrace: stackTrace);
//   }
// }
