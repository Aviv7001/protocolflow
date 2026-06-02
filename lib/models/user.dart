class User {
  final String id;
  final String fullName;
  final String email;

  User({
    required this.id,
    required this.fullName,
    required this.email,
  });

  String get initials {
    final parts = fullName.trim().split(' ').where((part) => part.isNotEmpty);
    if (parts.isEmpty) {
      return '';
    }

    final characters = parts.take(2).map((part) => part[0].toUpperCase());
    return characters.join();
  }

  User copyWith({
    String? id,
    String? fullName,
    String? email,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
    );
  }
}
