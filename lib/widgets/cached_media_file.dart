import 'dart:io';
import 'package:flutter/material.dart';
import '../services/media_storage_service.dart';
import '../models/message_document.dart';
import '../models/message_audio.dart';

/// Smart cached file widget for documents and audio files
/// Downloads and caches files when accessed, prevents re-downloading
class CachedMediaFile extends StatefulWidget {
  final String fileUrl;
  final String fileName;
  final String? fileType;
  final String? clubId;
  final VoidCallback? onTap;
  final Widget? customIcon;
  final bool isAudio;

  const CachedMediaFile({
    super.key,
    required this.fileUrl,
    required this.fileName,
    this.fileType,
    this.clubId,
    this.onTap,
    this.customIcon,
    this.isAudio = false,
  });

  @override
  State<CachedMediaFile> createState() => _CachedMediaFileState();
}

class _CachedMediaFileState extends State<CachedMediaFile> {
  String? _localPath;
  bool _isDownloading = false;
  bool _isAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkCacheStatus();
  }

  Future<void> _checkCacheStatus() async {
    try {
      // Check if file is already cached
      final localPath = await MediaStorageService.getLocalMediaPath(widget.fileUrl);
      if (localPath != null && await File(localPath).exists()) {
        setState(() {
          _localPath = localPath;
          _isAvailable = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Error checking cache status: $e');
    }
  }

  Future<void> _downloadFile() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      final localPath = await MediaStorageService.getCachedMediaPath(
        widget.fileUrl,
        clubId: widget.clubId,
      );

      if (localPath != null && await File(localPath).exists()) {
        setState(() {
          _localPath = localPath;
          _isAvailable = true;
          _isDownloading = false;
        });

        // Call onTap if provided (to open the file)
        if (widget.onTap != null) {
          widget.onTap!();
        }
      } else {
        setState(() {
          _isDownloading = false;
        });

        // Show error snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to download ${widget.fileName}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error downloading file: $e');
      setState(() {
        _isDownloading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  IconData _getFileIcon() {
    if (widget.customIcon != null) return Icons.description;

    if (widget.isAudio) return Icons.audiotrack;

    final extension = widget.fileType?.toLowerCase() ??
        widget.fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
        return Icons.archive;
      case 'mp3':
      case 'wav':
      case 'm4a':
      case 'aac':
        return Icons.audiotrack;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      default:
        return Icons.description;
    }
  }

  Color _getFileColor() {
    if (widget.isAudio) return Colors.purple;

    final extension = widget.fileType?.toLowerCase() ??
        widget.fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'zip':
      case 'rar':
        return Colors.grey;
      case 'mp3':
      case 'wav':
      case 'm4a':
      case 'aac':
        return Colors.purple;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Colors.indigo;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _getFileSize() {
    // This would need to be passed from the message data
    // For now, return empty string
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _isAvailable ? widget.onTap : _downloadFile,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // File icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getFileColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: widget.customIcon ?? Icon(
                    _getFileIcon(),
                    color: _getFileColor(),
                    size: 24,
                  ),
                ),

                const SizedBox(width: 12),

                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_getFileSize().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _getFileSize(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Status indicator
                if (_isDownloading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_isAvailable)
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  )
                else
                  Icon(
                    Icons.download,
                    color: Colors.grey[600],
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Specialized widget for audio messages with caching
class CachedAudioFile extends StatelessWidget {
  final MessageAudio audio;
  final String? clubId;
  final VoidCallback? onPlay;

  const CachedAudioFile({
    super.key,
    required this.audio,
    this.clubId,
    this.onPlay,
  });

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return CachedMediaFile(
      fileUrl: audio.url,
      fileName: '${audio.filename} • ${_formatDuration(audio.duration)}',
      clubId: clubId,
      isAudio: true,
      onTap: onPlay,
      customIcon: const Icon(Icons.play_arrow, color: Colors.purple),
    );
  }
}

/// Specialized widget for document messages with caching
class CachedDocumentFile extends StatelessWidget {
  final MessageDocument document;
  final String? clubId;
  final VoidCallback? onOpen;

  const CachedDocumentFile({
    super.key,
    required this.document,
    this.clubId,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return CachedMediaFile(
      fileUrl: document.url,
      fileName: document.filename,
      fileType: document.type,
      clubId: clubId,
      onTap: onOpen,
    );
  }
}