import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/media_storage_service.dart';

/// Widget that loads images from local cache first, falls back to network
class OfflineImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final BorderRadius? borderRadius;
  final String? clubId;

  const OfflineImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.clubId,
  });

  @override
  State<OfflineImage> createState() => _OfflineImageState();
}

class _OfflineImageState extends State<OfflineImage> {
  String? _localPath;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      // Check if image is available locally
      final localPath = await MediaStorageService.getLocalMediaPath(widget.imageUrl);
      
      if (localPath != null && await File(localPath).exists()) {
        // Use cached image
        setState(() {
          _localPath = localPath;
          _isLoading = false;
        });
      } else {
        // Try to download and cache the image
        final downloadedPath = await MediaStorageService.downloadMedia(
          widget.imageUrl, 
          clubId: widget.clubId,
        );
        
        if (downloadedPath != null && mounted) {
          setState(() {
            _localPath = downloadedPath;
            _isLoading = false;
          });
        } else if (mounted) {
          // Fall back to network image
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading offline image: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildImageContent() {
    if (_localPath != null) {
      // Use local file
      return Image.file(
        File(_localPath!),
        width: widget.width,
        height: widget.height,
        fit: widget.fit ?? BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error loading local image: $error');
          // Fall back to network image
          return _buildNetworkImage();
        },
      );
    } else {
      // Use network image
      return _buildNetworkImage();
    }
  }

  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit ?? BoxFit.cover,
      placeholder: widget.placeholder,
      errorWidget: widget.errorWidget ?? 
        (context, url, error) => Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[300],
          child: Icon(
            Icons.broken_image,
            color: Colors.grey[600],
            size: 24,
          ),
        ),
    );
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!(context, widget.imageUrl);
    }
    
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[300],
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    if (widget.errorWidget != null) {
      return widget.errorWidget!(context, widget.imageUrl, 'Failed to load image');
    }
    
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            color: Colors.grey[600],
            size: 24,
          ),
          SizedBox(height: 4),
          Text(
            'Failed to load',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (_isLoading) {
      imageWidget = _buildPlaceholder();
    } else if (_hasError) {
      imageWidget = _buildErrorWidget();
    } else {
      imageWidget = _buildImageContent();
    }

    if (widget.borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// Offline-aware audio player widget
class OfflineAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final String? clubId;
  final int? duration;

  const OfflineAudioPlayer({
    super.key,
    required this.audioUrl,
    this.clubId,
    this.duration,
  });

  @override
  State<OfflineAudioPlayer> createState() => _OfflineAudioPlayerState();
}

class _OfflineAudioPlayerState extends State<OfflineAudioPlayer> {
  String? _localPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    try {
      // Check if audio is available locally
      final localPath = await MediaStorageService.getLocalMediaPath(widget.audioUrl);
      
      if (localPath != null && await File(localPath).exists()) {
        setState(() {
          _localPath = localPath;
          _isLoading = false;
        });
      } else {
        // Download and cache the audio
        final downloadedPath = await MediaStorageService.downloadMedia(
          widget.audioUrl,
          clubId: widget.clubId,
        );
        
        if (downloadedPath != null && mounted) {
          setState(() {
            _localPath = downloadedPath;
            _isLoading = false;
          });
        } else if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading offline audio: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 60,
        child: Row(
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(width: 12),
            Text('Loading audio...'),
          ],
        ),
      );
    }

    // Use local path if available, otherwise network path
    final audioPath = _localPath ?? widget.audioUrl;
    
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.play_arrow),
            onPressed: () {
              // TODO: Implement audio playback
              print('Playing audio: $audioPath');
            },
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Audio Message'),
                if (widget.duration != null)
                  Text(
                    '${widget.duration}s',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          if (_localPath != null)
            Icon(
              Icons.offline_pin,
              color: Colors.green,
              size: 16,
            ),
        ],
      ),
    );
  }
}

/// Offline-aware document viewer widget  
class OfflineDocument extends StatefulWidget {
  final String documentUrl;
  final String filename;
  final String? clubId;

  const OfflineDocument({
    super.key,
    required this.documentUrl,
    required this.filename,
    this.clubId,
  });

  @override
  State<OfflineDocument> createState() => _OfflineDocumentState();
}

class _OfflineDocumentState extends State<OfflineDocument> {
  String? _localPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      // Check if document is available locally
      final localPath = await MediaStorageService.getLocalMediaPath(widget.documentUrl);
      
      if (localPath != null && await File(localPath).exists()) {
        setState(() {
          _localPath = localPath;
          _isLoading = false;
        });
      } else {
        // Download and cache the document
        final downloadedPath = await MediaStorageService.downloadMedia(
          widget.documentUrl,
          clubId: widget.clubId,
        );
        
        if (downloadedPath != null && mounted) {
          setState(() {
            _localPath = downloadedPath;
            _isLoading = false;
          });
        } else if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading offline document: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.description,
            color: Colors.blue,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.filename,
                  style: TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_isLoading)
                  Text(
                    'Downloading...',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  )
                else if (_localPath != null)
                  Text(
                    'Available offline',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  )
                else
                  Text(
                    'Tap to download',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          if (_localPath != null)
            Icon(
              Icons.offline_pin,
              color: Colors.green,
              size: 16,
            ),
        ],
      ),
    );
  }
}