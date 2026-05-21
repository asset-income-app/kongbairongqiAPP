enum PluginPermission {
  clipboard('clipboard'),
  vibration('vibration'),
  camera('camera'),
  storage('storage'),
  network('network'),
  notification('notification'),
  events('events');

  final String value;
  const PluginPermission(this.value);

  static PluginPermission? fromString(String value) {
    return PluginPermission.values.where((p) => p.value == value).firstOrNull;
  }
}

class CapabilityDependency {
  final String id;
  final String? minVersion;

  const CapabilityDependency({required this.id, this.minVersion});

  factory CapabilityDependency.fromJson(Map<String, dynamic> json) {
    return CapabilityDependency(
      id: json['id'] as String? ?? '',
      minVersion: json['min_version'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (minVersion != null) 'min_version': minVersion,
      };

  @override
  String toString() => 'Dependency($id${minVersion != null ? ' >= $minVersion' : ''})';
}

class PluginManifest {
  final String id;
  final String name;
  final String description;
  final String version;
  final String entry;
  final String icon;
  final List<PluginPermission> permissions;
  final String author;
  final double price;
  final String? paymentAddress;
  final int minSdkVersion;
  final List<CapabilityDependency> dependencies;
  final List<String> provides;
  final List<String> tags;
  final String? updateUrl;
  final String? changelog;

  PluginManifest({
    required this.id,
    required this.name,
    this.description = '',
    required this.version,
    this.entry = 'index.html',
    this.icon = '',
    this.permissions = const [],
    required this.author,
    this.price = 0.0,
    this.paymentAddress,
    this.minSdkVersion = 1,
    this.dependencies = const [],
    this.provides = const [],
    this.tags = const [],
    this.updateUrl,
    this.changelog,
  });

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    final perms = (json['permissions'] as List<dynamic>?)
            ?.map((e) => PluginPermission.fromString(e.toString()))
            .whereType<PluginPermission>()
            .toList() ??
        [];

    final deps = (json['dependencies'] as List<dynamic>?)
            ?.map((e) => CapabilityDependency.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final provides = (json['provides'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    final tags = (json['tags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    return PluginManifest(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      entry: json['entry'] as String? ?? 'index.html',
      icon: json['icon'] as String? ?? '',
      permissions: perms,
      author: json['author'] as String? ?? 'Unknown',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      paymentAddress: json['payment_address'] as String?,
      minSdkVersion: (json['min_sdk_version'] as num?)?.toInt() ?? 1,
      dependencies: deps,
      provides: provides,
      tags: tags,
      updateUrl: json['update_url'] as String?,
      changelog: json['changelog'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'version': version,
      'entry': entry,
      'icon': icon,
      'permissions': permissions.map((p) => p.value).toList(),
      'author': author,
      'price': price,
      'payment_address': paymentAddress,
      'min_sdk_version': minSdkVersion,
      'dependencies': dependencies.map((d) => d.toJson()).toList(),
      'provides': provides,
      'tags': tags,
      'update_url': updateUrl,
      'changelog': changelog,
    };
  }

  bool get isValid => id.isNotEmpty && name.isNotEmpty && author.isNotEmpty;

  bool get isFree => price <= 0;

  bool get hasPayment => paymentAddress != null && paymentAddress!.isNotEmpty;

  bool hasPermission(PluginPermission permission) {
    return permissions.contains(permission);
  }

  bool get hasDependencies => dependencies.isNotEmpty;

  bool get hasEvents => hasPermission(PluginPermission.events);

  bool get hasUpdateUrl => updateUrl != null && updateUrl!.isNotEmpty;

  static const int currentSdkVersion = 2;

  bool get isCompatible => minSdkVersion <= currentSdkVersion;

  @override
  String toString() => 'PluginManifest($id, $name v$version)';
}
