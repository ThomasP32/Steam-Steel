class ShopItem {
  ShopItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.imagePath,
    required this.description,
    this.owned = false,
    this.equipped = false,
    this.levelRequired,
    this.canPurchase = true,
    this.challengeRequired,
    this.userChallengesCompleted,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toInt(),
      category: json['category'] as String,
      imagePath: json['imagePath'] as String,
      description: json['description'] as String,
      owned: json['owned'] as bool? ?? false,
      equipped: json['equipped'] as bool? ?? false,
      levelRequired: json['levelRequired'] as int?,
      canPurchase: json['canPurchase'] as bool? ?? true,
      challengeRequired: json['ChallengeRequired'] as int?,
      userChallengesCompleted: json['userChallengesCompleted'] as int?,
    );
  }
  final String id;
  final String name;
  final int price;
  final String category;
  final String imagePath;
  final String description;
  final int? levelRequired;
  final int? challengeRequired;
  final int? userChallengesCompleted;
  final bool canPurchase;
  bool owned;
  bool equipped;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'category': category,
      'imagePath': imagePath,
      'description': description,
      'owned': owned,
      'equipped': equipped,
      'levelRequired': levelRequired,
      'canPurchase': canPurchase,
    };
  }

  ShopItem copyWith({
    String? id,
    String? name,
    int? price,
    String? category,
    String? imagePath,
    String? description,
    bool? owned,
    bool? equipped,
  }) {
    return ShopItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
      description: description ?? this.description,
      owned: owned ?? this.owned,
      equipped: equipped ?? this.equipped,
    );
  }
}
