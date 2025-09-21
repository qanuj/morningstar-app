import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import 'auth_service.dart';

class FileUploadService {
  static Map<String, String> get _headers => {
    if (AuthService.hasToken) 'Authorization': 'Bearer ${AuthService.token}',
  };

  static Future<String?> uploadFile(PlatformFile file) async {
    try {
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/upload');

      if (AppConfig.enableDebugPrints) {
        debugPrint('🔵 Uploading file: ${file.name}');
      }

      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(_headers)
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: file.name,
            contentType: MediaType.parse(_getMimeType(file.extension)),
          ),
        );

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final responseBody = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200 || streamed.statusCode == 201) {
        final jsonResponse = json.decode(responseBody);
        if (jsonResponse is Map &&
            jsonResponse['success'] == true &&
            jsonResponse['url'] != null) {
          if (AppConfig.enableDebugPrints) {
            debugPrint('✅ File uploaded successfully: ${jsonResponse['url']}');
          }
          return jsonResponse['url'] as String;
        }
      }

      debugPrint('❌ File upload failed (${streamed.statusCode}): $responseBody');
      return null;
    } catch (e) {
      debugPrint('❌ Error uploading file: $e');
      return null;
    }
  }

  static Future<List<String>> uploadMultipleFiles(List<PlatformFile> files) async {
    final uploadedUrls = <String>[];

    for (final file in files) {
      final url = await uploadFile(file);
      if (url != null) {
        uploadedUrls.add(url);
      }
    }

    return uploadedUrls;
  }

  static String _getMimeType(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/mp4';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      default:
        return 'application/octet-stream';
    }
  }

  static bool isValidFileType(String? extension, List<String> allowedTypes) {
    if (extension == null) return false;
    return allowedTypes.contains(extension.toLowerCase());
  }

  static bool isImageFile(String? extension) {
    return isValidFileType(extension, ['jpg', 'jpeg', 'png', 'webp', 'gif']);
  }

  static bool isDocumentFile(String? extension) {
    return isValidFileType(extension, ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt']);
  }

  static bool isAudioFile(String? extension) {
    return isValidFileType(extension, ['mp3', 'wav', 'aac', 'm4a']);
  }

  static bool isVideoFile(String? extension) {
    return isValidFileType(extension, ['mp4', 'mov', 'avi']);
  }
}