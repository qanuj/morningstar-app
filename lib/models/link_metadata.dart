class LinkMetadata {
  final String url;
  final String? title;
  final String? description;
  final String? image;
  final String? siteName;
  final String? favicon;

  LinkMetadata({
    required this.url,
    this.title,
    this.description,
    this.image,
    this.siteName,
    this.favicon,
  });

  factory LinkMetadata.fromJson(Map<String, dynamic> json) {
    return LinkMetadata(
      url: json['url'] ?? '',
      title: json['title'],
      description: json['description'],
      image: json['image'],
      siteName: json['siteName'],
      favicon: json['favicon'],
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    if (title != null) 'title': title,
    if (description != null) 'description': description,
    if (image != null) 'image': image,
    if (siteName != null) 'siteName': siteName,
    if (favicon != null) 'favicon': favicon,
  };
}
