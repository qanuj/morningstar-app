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
      id: json['id']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
      options: (json['options'] as List? ?? [])
          .map((o) => PollOption.fromJson(o))
          .toList(),
      createdBy: CreatedBy.fromJson(json['createdBy'] ?? {}),
      club: ClubModel.fromJson(json['club'] ?? {}),
      totalVotes: json['_count']?['votes'] ?? 0,
      userVote: json['userVote'] != null
          ? UserVote.fromJson(json['userVote'])
          : null,
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
  final List<PollVoter> voters;

  PollOption({
    required this.id,
    required this.pollId,
    required this.text,
    required this.voteCount,
    this.voters = const [],
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id']?.toString() ?? '',
      pollId: json['pollId']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      voteCount: json['_count']?['votes'] ?? 0,
      voters:
          (json['voters'] as List?)
              ?.map((v) => PollVoter.fromJson(v))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pollId': pollId,
      'text': text,
      '_count': {'votes': voteCount},
      'voters': voters.map((v) => v.toJson()).toList(),
    };
  }
}

class CreatedBy {
  final String id;
  final String name;

  CreatedBy({required this.id, required this.name});

  factory CreatedBy.fromJson(Map<String, dynamic> json) {
    return CreatedBy(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown User',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
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
      id: json['id']?.toString() ?? '',
      pollOptionId: json['pollOptionId']?.toString() ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
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

class PollVoter {
  final String id;
  final String name;
  final String? profilePicture;
  final DateTime votedAt;

  PollVoter({
    required this.id,
    required this.name,
    this.profilePicture,
    required this.votedAt,
  });

  factory PollVoter.fromJson(Map<String, dynamic> json) {
    return PollVoter(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown User',
      profilePicture: json['profilePicture'],  // Can be null
      votedAt: DateTime.parse(json['votedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profilePicture': profilePicture,
      'votedAt': votedAt.toIso8601String(),
    };
  }
}

class ClubModel {
  final String id;
  final String name;
  final String? logo;

  ClubModel({required this.id, required this.name, this.logo});

  factory ClubModel.fromJson(Map<String, dynamic> json) {
    return ClubModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Club',
      logo: json['logo'],  // Can be null
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'logo': logo};
  }
}
