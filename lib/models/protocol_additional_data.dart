class ProtocolAdditionalData {
  final String id;
  final String title;
  final String description;
  final String link;
  final List<String> photoPaths;

  ProtocolAdditionalData({
    required this.id,
    required this.title,
    this.description = '',
    this.link = '',
    this.photoPaths = const [],
  });

  ProtocolAdditionalData copyWith({
    String? id,
    String? title,
    String? description,
    String? link,
    List<String>? photoPaths,
  }) {
    return ProtocolAdditionalData(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      link: link ?? this.link,
      photoPaths: List<String>.from(photoPaths ?? this.photoPaths),
    );
  }

  ProtocolAdditionalData deepCopy() {
    return copyWith();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'link': link,
      'photoPaths': photoPaths,
    };
  }

  factory ProtocolAdditionalData.fromJson(Map<String, dynamic> json) {
    return ProtocolAdditionalData(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      link: json['link'] ?? '',
      photoPaths: List<String>.from(json['photoPaths'] ?? []),
    );
  }
}
