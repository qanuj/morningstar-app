class MediaItem {
  final String url;           // Local path or remote URL
  final String contentType;   // 'image' or 'video'
  final String? caption;      // Individual caption for this item
  final double? duration;     // For videos (in seconds)
  final String? thumbnailPath; // Local thumbnail path for videos
  final String? thumbnailUrl;  // Remote thumbnail URL after upload
  final String? originalPath; // Original path before compression
  final double? uploadProgress;    // 0.0 to 1.0
  final double? compressionProgress; // 0.0 to 1.0
  final String? processingStatus;  // "Compressing...", "Uploading...", etc.
  final bool isLocal;         // True if file is local, false if remote

  const MediaItem({
    required this.url,
    required this.contentType,
    this.caption,
    this.duration,
    this.thumbnailPath,
    this.thumbnailUrl,
    this.originalPath,
    this.uploadProgress,
    this.compressionProgress,
    this.processingStatus,
    this.isLocal = false,
  });

  bool get isVideo => contentType == 'video';
  bool get isImage => contentType == 'image';

  /// Get the best available thumbnail (remote URL first, then local path)
  String? get bestThumbnail => thumbnailUrl ?? thumbnailPath;

  /// Check if this item has any thumbnail
  bool get hasThumbnail => thumbnailUrl != null || thumbnailPath != null;

  /// Helper to detect content type from file extension
  static String detectContentType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    const videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp', 'flv'];
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif'];

    if (videoExtensions.contains(extension)) {
      return 'video';
    } else if (imageExtensions.contains(extension)) {
      return 'image';
    }
    return 'image'; // Default fallback
  }

  /// Factory constructor from file path
  factory MediaItem.fromPath(String path, {String? caption}) {
    return MediaItem(
      url: path,
      contentType: detectContentType(path),
      caption: caption,
      isLocal: true,
    );
  }

  /// Factory constructor for remote URL
  factory MediaItem.fromUrl(String url, {String? caption, double? duration}) {
    return MediaItem(
      url: url,
      contentType: detectContentType(url),
      caption: caption,
      duration: duration,
      isLocal: false,
    );
  }

  MediaItem copyWith({
    String? url,
    String? contentType,
    String? caption,
    double? duration,
    String? thumbnailPath,
    String? thumbnailUrl,
    String? originalPath,
    double? uploadProgress,
    double? compressionProgress,
    String? processingStatus,
    bool? isLocal,
  }) {
    return MediaItem(
      url: url ?? this.url,
      contentType: contentType ?? this.contentType,
      caption: caption ?? this.caption,
      duration: duration ?? this.duration,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      originalPath: originalPath ?? this.originalPath,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      compressionProgress: compressionProgress ?? this.compressionProgress,
      processingStatus: processingStatus ?? this.processingStatus,
      isLocal: isLocal ?? this.isLocal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'contentType': contentType,
      'caption': caption,
      'duration': duration,
      'thumbnailPath': thumbnailPath,
      'thumbnailUrl': thumbnailUrl,
      'originalPath': originalPath,
      'uploadProgress': uploadProgress,
      'compressionProgress': compressionProgress,
      'processingStatus': processingStatus,
      'isLocal': isLocal,
    };
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      url: json['url'] ?? '',
      contentType: json['contentType'] ?? 'image',
      caption: json['caption'],
      duration: json['duration']?.toDouble(),
      thumbnailPath: json['thumbnailPath'],
      thumbnailUrl: json['thumbnailUrl'],
      originalPath: json['originalPath'],
      uploadProgress: json['uploadProgress']?.toDouble(),
      compressionProgress: json['compressionProgress']?.toDouble(),
      processingStatus: json['processingStatus'],
      isLocal: json['isLocal'] ?? false,
    );
  }

  @override
  String toString() => 'MediaItem(url: $url, type: $contentType, caption: $caption)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaItem &&
           other.url == url &&
           other.contentType == contentType;
  }

  @override
  int get hashCode => url.hashCode ^ contentType.hashCode;
}