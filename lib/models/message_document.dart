class MessageDocument {
  final String url;
  final String filename;
  final String type; // 'pdf', 'txt', 'doc', etc.
  final String? size; // File size like "2MB"
  
  MessageDocument({
    required this.url, 
    required this.filename, 
    required this.type,
    this.size,
  });
  
  factory MessageDocument.fromJson(Map<String, dynamic> json) {
    return MessageDocument(
      url: json['url'] ?? '',
      filename: json['filename'] ?? json['name'] ?? '',
      type: json['type'] ?? '',
      size: json['size'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'url': url,
    'filename': filename,
    'type': type,
    if (size != null) 'size': size,
  };
}