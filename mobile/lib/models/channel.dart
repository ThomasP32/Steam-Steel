class Channel {
  Channel({required this.name, required this.creator, this.id, this.createdAt});

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['_id'] as String?,
      name: json['name'] as String,
      creator: json['creator'] as String,
      createdAt:
          json['createdAt'] != null
              ? DateTime.parse(json['createdAt'] as String)
              : null,
    );
  }

  final String? id;
  final String name;
  final String creator;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'name': name,
      'creator': creator,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}
