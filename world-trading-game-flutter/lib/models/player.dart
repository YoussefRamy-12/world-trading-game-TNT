class Player {
  final String id;
  final String? userId;
  final String displayName;
  final String? avatarUrl;
  final bool isAdmin;

  const Player({
    required this.id,
    this.userId,
    this.displayName = '',
    this.avatarUrl,
    this.isAdmin = false,
  });

  factory Player.fromMap(Map<String, dynamic> map) => Player(
        id: map['id'].toString(),
        userId: map['user_id']?.toString(),
        displayName: (map['display_name'] ?? '').toString(),
        avatarUrl: map['avatar_url']?.toString(),
        isAdmin: map['is_admin'] == true,
      );
}
