class PublicChallengeView {
  const PublicChallengeView({
    required this.title,
    required this.description,
    required this.reward,
    required this.progress,
    required this.completed,
  });

  factory PublicChallengeView.fromJson(Map<String, dynamic> json) {
    return PublicChallengeView(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      reward: json['reward'] as int? ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      completed: json['completed'] as bool? ?? false,
    );
  }

  final String title;
  final String description;
  final int reward;
  final double progress;
  final bool completed;
}

enum ChallengeType {
  visitTiles25('visit_tiles_25'),
  deal5Damage('deal_5_damage'),
  escape5Attacks('no_hp_loss'),
  open2Doors('open_2_doors'),
  collect2Items('collect_2_items');

  const ChallengeType(this.value);
  final String value;
}
