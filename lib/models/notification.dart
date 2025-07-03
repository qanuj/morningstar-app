class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String? type;
  final String? actionUrl;
  final bool isRead;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ClubModel? club;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.type,
    this.actionUrl,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
    this.club,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      type: json['type'],
      actionUrl: json['actionUrl'],
      isRead: json['isRead'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      club: json['club'] != null ? ClubModel.fromJson(json['club']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'actionUrl': actionUrl,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'club': club?.toJson(),
    };
  }
}

class ClubModel {
  final String id;
  final String name;
  final String? logo;

  ClubModel({
    required this.id,
    required this.name,
    this.logo,
  });

  factory ClubModel.fromJson(Map<String, dynamic> json) {
    return ClubModel(
      id: json['id'],
      name: json['name'],
      logo: json['logo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo': logo,
    };
  }
}