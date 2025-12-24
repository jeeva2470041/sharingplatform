enum ItemStatus { available, requested, approved, returned }

class Item {
  final String id;
  final String name;
  final String category;
  final String deposit;
  final String ownerId;
  ItemStatus status;
  String? requestedBy;
  double? rating;
  int? ratingCount;

  Item({
    required this.id,
    required this.name,
    required this.category,
    required this.deposit,
    required this.ownerId,
    this.status = ItemStatus.available,
    this.requestedBy,
    this.rating,
    this.ratingCount,
  });

  String get statusText {
    switch (status) {
      case ItemStatus.available:
        return 'Available';
      case ItemStatus.requested:
        return 'Requested';
      case ItemStatus.approved:
        return 'Approved';
      case ItemStatus.returned:
        return 'Returned';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'deposit': deposit,
      'ownerId': ownerId,
      'status': status.index,
      'requestedBy': requestedBy,
      'rating': rating,
      'ratingCount': ratingCount,
    };
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      deposit: json['deposit'],
      ownerId: json['ownerId'],
      status: ItemStatus.values[json['status']],
      requestedBy: json['requestedBy'],
      rating: json['rating']?.toDouble(),
      ratingCount: json['ratingCount'],
    );
  }
}
