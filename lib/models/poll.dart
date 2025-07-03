class Poll {
  final String id;
  final String question;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final List<PollOption> options;
  final CreatedBy createdBy;
  final ClubModel club;
  final int totalVotes;
  final UserVote? userVote;

  Poll({
    required this.id,
    required this.question,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
    required this.options,
    required this.createdBy,
    required this.club,
    required this.totalVotes,
    this.userVote,
  });

  bool get hasVoted => userVote != null;

  factory Poll.fromJson(Map<String, dynamic> json) {
    return Poll(
      id: json['id'],
      question: json['question'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
      options: (json['options'] as List).map((o) => PollOption.fromJson(o)).toList(),
      createdBy: CreatedBy.fromJson(json['createdBy']),
      club: ClubModel.fromJson(json['club']),
      totalVotes: json['_count']['votes'] ?? 0,
      userVote: json['userVote'] != null ? UserVote.fromJson(json['userVote']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'options': options.map((o) => o.toJson()).toList(),
      'createdBy': createdBy.toJson(),
      'club': club.toJson(),
      '_count': {'votes': totalVotes},
      'userVote': userVote?.toJson(),
    };
  }
}

class PollOption {
  final String id;
  final String pollId;
  final String text;
  final int voteCount;

  PollOption({
    required this.id,
    required this.pollId,
    required this.text,
    required this.voteCount,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'],
      pollId: json['pollId'],
      text: json['text'],
      voteCount: json['_count']['votes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pollId': pollId,
      'text': text,
      '_count': {'votes': voteCount},
    };
  }
}

class CreatedBy {
  final String id;
  final String name;

  CreatedBy({
    required this.id,
    required this.name,
  });

  factory CreatedBy.fromJson(Map<String, dynamic> json) {
    return CreatedBy(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class UserVote {
  final String id;
  final String pollOptionId;
  final DateTime createdAt;

  UserVote({
    required this.id,
    required this.pollOptionId,
    required this.createdAt,
  });

  factory UserVote.fromJson(Map<String, dynamic> json) {
    return UserVote(
      id: json['id'],
      pollOptionId: json['pollOptionId'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pollOptionId': pollOptionId,
      'createdAt': createdAt.toIso8601String(),
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