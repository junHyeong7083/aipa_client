class PersonaData {
  final String name;
  final String gender;
  final int age;
  final String occupation;
  final String description;
  final String socialStatus; // "junior" or "senior"

  PersonaData({
    required this.name,
    required this.gender,
    required this.age,
    required this.occupation,
    required this.description,
    required this.socialStatus,
  });

  factory PersonaData.fromJson(Map<String, dynamic> json) {
    return PersonaData(
      name: json['name'] ?? '',
      gender: json['gender'] ?? '',
      age: json['age'] ?? 0,
      occupation: json['occupation'] ?? '',
      description: json['description'] ?? '',
      socialStatus: json['socialStatus'] ?? 'junior',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'gender': gender,
      'age': age,
      'occupation': occupation,
      'description': description,
      'socialStatus': socialStatus,
    };
  }

  @override
  String toString() {
    return 'PersonaData(name: $name, gender: $gender, age: $age, occupation: $occupation)';
  }
}
