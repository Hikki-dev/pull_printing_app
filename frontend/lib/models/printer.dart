/// A printer people can collect their documents from.
class Printer {
  final String id;
  final String name;
  final String location;
  final bool enabled;

  const Printer({
    required this.id,
    required this.name,
    this.location = '',
    this.enabled = true,
  });

  factory Printer.fromJson(Map<String, dynamic> j) => Printer(
        id: j['id'] as String,
        name: j['name'] as String,
        location: j['location'] as String? ?? '',
        enabled: j['enabled'] as bool? ?? true,
      );
}
