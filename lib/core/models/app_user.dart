import '../utils/parse.dart';

enum UserRole { customer, admin }

enum AccountStatus { active, suspended }

class Address {
  const Address({
    required this.id,
    required this.label,
    required this.line,
    this.city = '',
    this.notes = '',
    this.isDefault = false,
    this.latitude,
    this.longitude,
  });

  final String id;

  /// "Home", "Work", "Dorm" — shown as a chip in the address list.
  final String label;
  final String line;
  final String city;
  final String notes;
  final bool isDefault;
  final double? latitude;
  final double? longitude;

  String get oneLine => [line, if (city.isNotEmpty) city].join(', ');

  factory Address.fromMap(Map<String, dynamic> m) => Address(
        id: Parse.str(m['id']),
        label: Parse.str(m['label'], 'Address'),
        line: Parse.str(m['line']),
        city: Parse.str(m['city']),
        notes: Parse.str(m['notes']),
        isDefault: Parse.boolean(m['isDefault']),
        latitude: m['latitude'] == null ? null : Parse.number(m['latitude']),
        longitude: m['longitude'] == null ? null : Parse.number(m['longitude']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'line': line,
        'city': city,
        'notes': notes,
        'isDefault': isDefault,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  Address copyWith({String? label, String? line, String? city, String? notes, bool? isDefault}) => Address(
        id: id,
        label: label ?? this.label,
        line: line ?? this.line,
        city: city ?? this.city,
        notes: notes ?? this.notes,
        isDefault: isDefault ?? this.isDefault,
        latitude: latitude,
        longitude: longitude,
      );
}

/// User-controlled preferences (FR28).
class UserSettings {
  const UserSettings({
    this.language = 'en',
    this.pushNotifications = true,
    this.orderUpdates = true,
    this.groupInvites = true,
    this.promotions = true,
    this.shareProfileWithGroup = true,
    this.discoverableByUsername = true,
    this.discoverableByPhone = true,
  });

  final String language;
  final bool pushNotifications;
  final bool orderUpdates;
  final bool groupInvites;
  final bool promotions;

  /// Privacy (FR28): controls how much of a profile other members can see and
  /// whether this account can be found when a host invites by username/phone.
  final bool shareProfileWithGroup;
  final bool discoverableByUsername;
  final bool discoverableByPhone;

  factory UserSettings.fromMap(Map<String, dynamic> m) => UserSettings(
        language: Parse.str(m['language'], 'en'),
        pushNotifications: Parse.boolean(m['pushNotifications'], true),
        orderUpdates: Parse.boolean(m['orderUpdates'], true),
        groupInvites: Parse.boolean(m['groupInvites'], true),
        promotions: Parse.boolean(m['promotions'], true),
        shareProfileWithGroup: Parse.boolean(m['shareProfileWithGroup'], true),
        discoverableByUsername: Parse.boolean(m['discoverableByUsername'], true),
        discoverableByPhone: Parse.boolean(m['discoverableByPhone'], true),
      );

  Map<String, dynamic> toMap() => {
        'language': language,
        'pushNotifications': pushNotifications,
        'orderUpdates': orderUpdates,
        'groupInvites': groupInvites,
        'promotions': promotions,
        'shareProfileWithGroup': shareProfileWithGroup,
        'discoverableByUsername': discoverableByUsername,
        'discoverableByPhone': discoverableByPhone,
      };

  UserSettings copyWith({
    String? language,
    bool? pushNotifications,
    bool? orderUpdates,
    bool? groupInvites,
    bool? promotions,
    bool? shareProfileWithGroup,
    bool? discoverableByUsername,
    bool? discoverableByPhone,
  }) =>
      UserSettings(
        language: language ?? this.language,
        pushNotifications: pushNotifications ?? this.pushNotifications,
        orderUpdates: orderUpdates ?? this.orderUpdates,
        groupInvites: groupInvites ?? this.groupInvites,
        promotions: promotions ?? this.promotions,
        shareProfileWithGroup: shareProfileWithGroup ?? this.shareProfileWithGroup,
        discoverableByUsername: discoverableByUsername ?? this.discoverableByUsername,
        discoverableByPhone: discoverableByPhone ?? this.discoverableByPhone,
      );
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.username,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.photoUrl,
    this.addresses = const [],
    this.favoriteRestaurantIds = const [],
    this.favoriteItemIds = const [],
    this.role = UserRole.customer,
    this.status = AccountStatus.active,
    this.settings = const UserSettings(),
    this.lastSpinAt,
    this.createdAt,
  });

  final String uid;

  /// Lowercase handle. Unique, and the key hosts use to invite (FR7).
  final String username;
  final String fullName;
  final String email;
  final String phone;
  final String? photoUrl;
  final List<Address> addresses;
  final List<String> favoriteRestaurantIds;
  final List<String> favoriteItemIds;
  final UserRole role;
  final AccountStatus status;
  final UserSettings settings;

  /// Gates Spin & Win to one spin per calendar day (FR25).
  final DateTime? lastSpinAt;
  final DateTime? createdAt;

  bool get isAdmin => role == UserRole.admin;
  bool get isSuspended => status == AccountStatus.suspended;

  Address? get defaultAddress {
    if (addresses.isEmpty) return null;
    for (final a in addresses) {
      if (a.isDefault) return a;
    }
    return addresses.first;
  }

  String get initials {
    final source = fullName.trim().isNotEmpty ? fullName.trim() : username;
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  /// True when the user has not spun the reward wheel yet today.
  bool get canSpinToday {
    final last = lastSpinAt;
    if (last == null) return true;
    final now = DateTime.now();
    return !(last.year == now.year && last.month == now.month && last.day == now.day);
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
        uid: uid,
        username: Parse.str(m['username']),
        fullName: Parse.str(m['fullName']),
        email: Parse.str(m['email']),
        phone: Parse.str(m['phone']),
        photoUrl: Parse.strOrNull(m['photoUrl']),
        addresses: Parse.mapList(m['addresses']).map(Address.fromMap).toList(),
        favoriteRestaurantIds: Parse.strList(m['favoriteRestaurantIds']),
        favoriteItemIds: Parse.strList(m['favoriteItemIds']),
        role: Parse.enumOf(UserRole.values, m['role'], UserRole.customer),
        status: Parse.enumOf(AccountStatus.values, m['status'], AccountStatus.active),
        settings: UserSettings.fromMap(Parse.map(m['settings'])),
        lastSpinAt: Parse.dateOrNull(m['lastSpinAt']),
        createdAt: Parse.dateOrNull(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'username': username,
        'usernameLower': username.toLowerCase(),
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'photoUrl': photoUrl,
        'addresses': addresses.map((a) => a.toMap()).toList(),
        'favoriteRestaurantIds': favoriteRestaurantIds,
        'favoriteItemIds': favoriteItemIds,
        'role': role.name,
        'status': status.name,
        'settings': settings.toMap(),
        'lastSpinAt': lastSpinAt,
        'createdAt': createdAt,
      };

  AppUser copyWith({
    String? username,
    String? fullName,
    String? email,
    String? phone,
    String? photoUrl,
    List<Address>? addresses,
    List<String>? favoriteRestaurantIds,
    List<String>? favoriteItemIds,
    UserRole? role,
    AccountStatus? status,
    UserSettings? settings,
    DateTime? lastSpinAt,
  }) =>
      AppUser(
        uid: uid,
        username: username ?? this.username,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        photoUrl: photoUrl ?? this.photoUrl,
        addresses: addresses ?? this.addresses,
        favoriteRestaurantIds: favoriteRestaurantIds ?? this.favoriteRestaurantIds,
        favoriteItemIds: favoriteItemIds ?? this.favoriteItemIds,
        role: role ?? this.role,
        status: status ?? this.status,
        settings: settings ?? this.settings,
        lastSpinAt: lastSpinAt ?? this.lastSpinAt,
        createdAt: createdAt,
      );
}
