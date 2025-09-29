// lib/models/shared_content.dart
enum SharedContentType { text, url, image, file, multipleImages, unknown }

class SharedContent {
  final SharedContentType type;
  final String? text;
  final String? subject;
  final List<String>? imagePaths;
  final List<String>? filePaths;
  final String? url;
  final Map<String, dynamic>? metadata;
  final DateTime receivedAt;

  SharedContent({
    required this.type,
    this.text,
    this.subject,
    this.imagePaths,
    this.filePaths,
    this.url,
    this.metadata,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory SharedContent.fromText(String text) {
    // Check if text is a URL
    final urlRegex = RegExp(r'https?://[^\s]+');
    final isUrl = urlRegex.hasMatch(text);

    return SharedContent(
      type: isUrl ? SharedContentType.url : SharedContentType.text,
      text: text,
      url: isUrl ? text : null,
    );
  }

  factory SharedContent.fromImages(List<String> imagePaths) {
    return SharedContent(
      type: imagePaths.length > 1
          ? SharedContentType.multipleImages
          : SharedContentType.image,
      imagePaths: imagePaths,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'text': text,
      'subject': subject,
      'imagePaths': imagePaths,
      'url': url,
      'metadata': metadata,
      'receivedAt': receivedAt.toIso8601String(),
    };
  }

  factory SharedContent.fromJson(Map<String, dynamic> json) {
    return SharedContent(
      type: SharedContentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SharedContentType.unknown,
      ),
      text: json['text'],
      subject: json['subject'],
      imagePaths: json['imagePaths']?.cast<String>(),
      url: json['url'],
      metadata: json['metadata']?.cast<String, dynamic>(),
      receivedAt: DateTime.parse(json['receivedAt']),
    );
  }

  String get displayText {
    switch (type) {
      case SharedContentType.text:
        return text ?? '';
      case SharedContentType.url:
        return url ?? text ?? '';
      case SharedContentType.image:
        return text ?? 'Image';
      case SharedContentType.multipleImages:
        return '${imagePaths?.length ?? 0} Images';
      default:
        return 'Shared content';
    }
  }

  bool get hasImages => imagePaths != null && imagePaths!.isNotEmpty;
  bool get hasText => text != null && text!.isNotEmpty;
  bool get isValid => hasImages || hasText || type == SharedContentType.image;
}
