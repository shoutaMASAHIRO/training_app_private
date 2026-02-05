class CustomProgram {
  final int? id;
  final String name;
  final String? description;
  final String? details;

  CustomProgram({
    this.id,
    required this.name,
    this.description,
    this.details,
  });

  factory CustomProgram.fromMap(Map<String, dynamic> map) {
    return CustomProgram(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      details: map['details'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'details': details,
    };
  }
}
