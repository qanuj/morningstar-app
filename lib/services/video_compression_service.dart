import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';

class VideoCompressionService {
  static const int maxVideoDurationSeconds = 60; // 1 minute max
  static const int maxVideoSizeMB = 50; // 50MB max
  static const int targetBitrate = 1000; // 1Mbps target bitrate

  /// Compress and convert video to MP4 format using FFmpeg
  static Future<String?> compressVideo({
    required String inputPath,
    bool deleteOriginal = false,
    Function(double)? onProgress,
    int? maxDurationSeconds,
    int? targetSizeMB,
  }) async {
    try {
      print('🎬 VideoCompressionService: Starting compression for $inputPath');

      // Check if input file exists
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        print('❌ VideoCompressionService: Input file does not exist');
        return null;
      }

      final originalSize = await inputFile.length();
      print('📊 Original file size: ${(originalSize / (1024 * 1024)).toStringAsFixed(2)} MB');

      // Generate output path
      final outputPath = await _generateOutputPath(inputPath);

      // Get video info first
      final videoInfo = await _getVideoInfo(inputPath);
      if (videoInfo == null) {
        print('❌ VideoCompressionService: Could not get video info');
        return null;
      }

      print('🔍 Video info: ${videoInfo['duration']}s, ${videoInfo['bitrate']}kb/s');

      // Build FFmpeg command for compression
      final command = _buildCompressionCommand(
        inputPath: inputPath,
        outputPath: outputPath,
        videoInfo: videoInfo,
        maxDurationSeconds: maxDurationSeconds ?? maxVideoDurationSeconds,
        targetSizeMB: targetSizeMB ?? maxVideoSizeMB,
      );

      print('🔧 FFmpeg command: $command');

      // Execute FFmpeg with progress tracking
      late FFmpegSession session;
      final completer = Completer<String?>();

      session = await FFmpegKit.executeAsync(
        command,
        (session) async {
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            final outputFile = File(outputPath);
            if (await outputFile.exists()) {
              final compressedSize = await outputFile.length();
              print('✅ VideoCompressionService: Compression successful');
              print('📊 Compressed size: ${(compressedSize / (1024 * 1024)).toStringAsFixed(2)} MB');
              print('📊 Compression ratio: ${((compressedSize / originalSize) * 100).toStringAsFixed(1)}%');

              // Delete original if requested
              if (deleteOriginal && inputPath != outputPath) {
                await inputFile.delete();
              }

              completer.complete(outputPath);
            } else {
              print('❌ VideoCompressionService: Output file not found');
              completer.complete(null);
            }
          } else {
            print('❌ VideoCompressionService: FFmpeg failed with return code: $returnCode');
            final logs = await session.getLogs();
            for (final log in logs) {
              print('FFmpeg log: ${log.getMessage()}');
            }
            completer.complete(null);
          }
        },
        null, // Log callback
        (statistics) {
          // Progress callback
          if (videoInfo['duration'] != null && statistics.getTime() > 0) {
            final progress = (statistics.getTime() / (videoInfo['duration'] * 1000)) * 100;
            if (progress <= 100) {
              onProgress?.call(progress);
              print('🔄 Compression progress: ${progress.toStringAsFixed(1)}%');
            }
          }
        },
      );

      return completer.future;

    } catch (e, stackTrace) {
      print('❌ VideoCompressionService: Error during compression: $e');
      print('📍 Stack trace: $stackTrace');
      return null;
    }
  }

  /// Convert any video format to MP4 (format conversion only, minimal compression)
  static Future<String?> convertToMp4({
    required String inputPath,
    bool deleteOriginal = false,
  }) async {
    try {
      print('🔄 VideoCompressionService: Converting to MP4: $inputPath');

      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        print('❌ VideoCompressionService: Input file does not exist');
        return null;
      }

      // If already MP4, just return the path
      if (inputPath.toLowerCase().endsWith('.mp4')) {
        print('✅ VideoCompressionService: File is already MP4');
        return inputPath;
      }

      final outputPath = await _generateOutputPath(inputPath, suffix: '_converted');

      // Simple format conversion with minimal re-encoding
      final command = '-i "$inputPath" -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k -movflags +faststart "$outputPath"';

      print('🔧 FFmpeg conversion command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print('✅ VideoCompressionService: Format conversion successful');

        // Delete original if requested
        if (deleteOriginal) {
          await inputFile.delete();
        }

        return outputPath;
      } else {
        print('❌ VideoCompressionService: Format conversion failed');
        final logs = await session.getLogs();
        for (final log in logs) {
          print('FFmpeg log: ${log.getMessage()}');
        }
        return null;
      }

    } catch (e, stackTrace) {
      print('❌ VideoCompressionService: Error during format conversion: $e');
      print('📍 Stack trace: $stackTrace');
      return null;
    }
  }

  /// Generate thumbnail from video center frame using FFmpeg
  static Future<String?> generateThumbnail(String videoPath) async {
    try {
      print('🖼️ VideoCompressionService: Generating thumbnail for $videoPath');

      final outputPath = await _generateThumbnailPath(videoPath);

      // First, get video duration to calculate center frame
      final videoInfo = await _getVideoInfo(videoPath);
      final duration = videoInfo?['duration'] as double?;

      // Calculate center frame time (middle of video)
      String timeSeek = '00:00:01'; // Default to 1 second if duration unknown
      if (duration != null && duration > 2) {
        final centerTime = duration / 2;
        final hours = (centerTime / 3600).floor();
        final minutes = ((centerTime % 3600) / 60).floor();
        final seconds = (centerTime % 60).floor();
        timeSeek = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      }

      print('🖼️ VideoCompressionService: Extracting thumbnail at $timeSeek (duration: ${duration}s)');

      // Extract thumbnail from center frame with high quality
      final command = '-i "$videoPath" -ss $timeSeek -vframes 1 -q:v 2 -vf "scale=320:240:force_original_aspect_ratio=decrease" "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print('✅ VideoCompressionService: Thumbnail generated successfully: $outputPath');
        return outputPath;
      } else {
        print('❌ VideoCompressionService: Thumbnail generation failed');
        final logs = await session.getLogs();
        for (final log in logs) {
          print('FFmpeg thumbnail log: ${log.getMessage()}');
        }
        return null;
      }
    } catch (e) {
      print('❌ VideoCompressionService: Error generating thumbnail: $e');
      return null;
    }
  }

  /// Generate thumbnail with custom size
  static Future<String?> generateThumbnailWithSize(
    String videoPath, {
    int width = 320,
    int height = 240,
    double? timeSeconds,
  }) async {
    try {
      print('🖼️ VideoCompressionService: Generating custom thumbnail ${width}x${height} for $videoPath');

      final outputPath = await _generateThumbnailPath(videoPath);

      // Use provided time or calculate center frame
      String timeSeek = '00:00:01';
      if (timeSeconds != null) {
        final hours = (timeSeconds / 3600).floor();
        final minutes = ((timeSeconds % 3600) / 60).floor();
        final seconds = (timeSeconds % 60).floor();
        timeSeek = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      } else {
        // Calculate center frame
        final videoInfo = await _getVideoInfo(videoPath);
        final duration = videoInfo?['duration'] as double?;
        if (duration != null && duration > 2) {
          final centerTime = duration / 2;
          final hours = (centerTime / 3600).floor();
          final minutes = ((centerTime % 3600) / 60).floor();
          final secs = (centerTime % 60).floor();
          timeSeek = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
        }
      }

      // Extract thumbnail with custom size
      final command = '-i "$videoPath" -ss $timeSeek -vframes 1 -q:v 2 -vf "scale=$width:$height:force_original_aspect_ratio=decrease" "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print('✅ VideoCompressionService: Custom thumbnail generated: $outputPath');
        return outputPath;
      } else {
        print('❌ VideoCompressionService: Custom thumbnail generation failed');
        return null;
      }
    } catch (e) {
      print('❌ VideoCompressionService: Error generating custom thumbnail: $e');
      return null;
    }
  }

  /// Check if video needs compression
  static Future<bool> needsCompression(String videoPath) async {
    try {
      final file = File(videoPath);
      final fileSize = await file.length();

      // Check file size (50MB max)
      if (fileSize > maxVideoSizeMB * 1024 * 1024) {
        print('🔍 VideoCompressionService: Video needs compression - file too large: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');
        return true;
      }

      // Check if format is not MP4
      if (!videoPath.toLowerCase().endsWith('.mp4')) {
        print('🔍 VideoCompressionService: Video needs compression - format conversion required');
        return true;
      }

      // Get video duration
      final videoInfo = await _getVideoInfo(videoPath);
      if (videoInfo != null && videoInfo['duration'] != null) {
        final duration = videoInfo['duration'] as double;
        if (duration > maxVideoDurationSeconds) {
          print('🔍 VideoCompressionService: Video needs compression - too long: ${duration}s');
          return true;
        }
      }

      return false;
    } catch (e) {
      print('❌ VideoCompressionService: Error checking compression need: $e');
      return true; // Err on the side of caution
    }
  }

  /// Clean up temporary video files
  static Future<void> cleanup() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final videoTempDir = Directory('${tempDir.path}/compressed_videos');
      if (await videoTempDir.exists()) {
        await videoTempDir.delete(recursive: true);
        print('🧹 VideoCompressionService: Cleaned up temporary files');
      }
    } catch (e) {
      print('⚠️ VideoCompressionService: Error during cleanup: $e');
    }
  }

  // Private helper methods

  static Future<String> _generateOutputPath(String inputPath, {String suffix = '_compressed'}) async {
    final tempDir = await getTemporaryDirectory();
    final videoTempDir = Directory('${tempDir.path}/compressed_videos');

    // Create temp directory if it doesn't exist
    if (!await videoTempDir.exists()) {
      await videoTempDir.create(recursive: true);
    }

    final inputFile = File(inputPath);
    final fileName = inputFile.path.split('/').last;
    final nameWithoutExt = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    return '${videoTempDir.path}/${nameWithoutExt}${suffix}.mp4';
  }

  static Future<String> _generateThumbnailPath(String videoPath) async {
    final tempDir = await getTemporaryDirectory();
    final videoTempDir = Directory('${tempDir.path}/compressed_videos');

    if (!await videoTempDir.exists()) {
      await videoTempDir.create(recursive: true);
    }

    final inputFile = File(videoPath);
    final fileName = inputFile.path.split('/').last;
    final nameWithoutExt = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    return '${videoTempDir.path}/${nameWithoutExt}_thumb.jpg';
  }

  static Future<Map<String, dynamic>?> _getVideoInfo(String videoPath) async {
    try {
      // Use FFprobeKit to get media information
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final mediaInformation = session.getMediaInformation();

      if (mediaInformation != null) {
        final duration = mediaInformation.getDuration();
        final bitrate = mediaInformation.getBitrate();

        return {
          'duration': duration != null ? double.tryParse(duration) : null,
          'bitrate': bitrate != null ? (int.tryParse(bitrate)! / 1000).round() : null,
        };
      }

      // Fallback: try to estimate from file size (rough approximation)
      final file = File(videoPath);
      final fileSize = await file.length();

      return {
        'duration': 30.0, // Default estimate
        'bitrate': null,
        'fileSize': fileSize,
      };
    } catch (e) {
      print('⚠️ VideoCompressionService: Error getting video info: $e');

      // Final fallback
      final file = File(videoPath);
      final fileSize = await file.length();

      return {
        'duration': 30.0, // Default estimate
        'bitrate': null,
        'fileSize': fileSize,
      };
    }
  }

  static String _buildCompressionCommand({
    required String inputPath,
    required String outputPath,
    required Map<String, dynamic> videoInfo,
    required int maxDurationSeconds,
    required int targetSizeMB,
  }) {
    final List<String> params = ['-i', '"$inputPath"'];

    // Limit duration if too long
    final duration = videoInfo['duration'] as double?;
    if (duration != null && duration > maxDurationSeconds) {
      params.addAll(['-t', maxDurationSeconds.toString()]);
    }

    // Video encoding settings
    params.addAll([
      '-c:v', 'libx264',        // H.264 codec
      '-preset', 'medium',       // Encoding speed vs compression
      '-crf', '26',             // Constant rate factor (quality)
      '-maxrate', '${targetBitrate}k',  // Maximum bitrate
      '-bufsize', '${targetBitrate * 2}k', // Buffer size
    ]);

    // Audio encoding settings
    params.addAll([
      '-c:a', 'aac',            // AAC audio codec
      '-b:a', '128k',           // Audio bitrate
    ]);

    // Mobile optimization
    params.addAll([
      '-movflags', '+faststart', // Enable fast start for web playback
      '-pix_fmt', 'yuv420p',    // Pixel format for compatibility
    ]);

    // Output file
    params.add('"$outputPath"');

    return params.join(' ');
  }
}