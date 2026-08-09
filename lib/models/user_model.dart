class UserModel {
  final String uid;
  final String name;
  final String email;
  final String dateOfBirth;
  final String gender;
  final String role;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.dateOfBirth,
    required this.gender,
    required this.role,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      dateOfBirth: map['dateOfBirth'] ?? '',
      gender: map['gender'] ?? '',
      role: map['role'] ?? 'Patient',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'role': role,
    };
  }
}
