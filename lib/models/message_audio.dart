class MessageAudio {
  final String url;
  final String filename;
  final int? duration; // Duration in seconds
  final int? size; // File size in bytes

  const MessageAudio({
    required this.url,
    required this.filename,
    this.duration,
    this.size,
  });

  factory MessageAudio.fromJson(Map<String, dynamic> json) {
    return MessageAudio(
      url: json['url'] ?? '',
      filename: json['filename'] ?? json['name'] ?? 'audio',
      duration: json['duration'] != null ? int.tryParse(json['duration'].toString()) : null,
      size: json['size'] != null ? int.tryParse(json['size'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'filename': filename,
      if (duration != null) 'duration': duration,
      if (size != null) 'size': size,
    };
  }
}