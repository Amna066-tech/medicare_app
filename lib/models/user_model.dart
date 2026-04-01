class UserModel {
  final String uid;
  final String name;
  final String email;
  final String dateOfBirth;
  final String gender;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.dateOfBirth,
    required this.gender,
  });

  // This factory method takes data FROM Firebase and turns it into a Dart Object
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      dateOfBirth: map['dateOfBirth'] ?? '',
      gender: map['gender'] ?? '',
    );
  }

  // This method takes our Dart Object and turns it into a Map to send TO Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
    };
  }
}