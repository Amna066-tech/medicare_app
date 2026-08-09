class DoctorModel {
  final String id;
  final String name;
  final String email;
  final String specialty;
  final String diseaseSpecialty; // e.g. "Fever, Flu, Covid"
  final String phone;
  final String hospital;

  DoctorModel({
    required this.id,
    required this.name,
    required this.email,
    required this.specialty,
    required this.diseaseSpecialty,
    required this.phone,
    required this.hospital,
  });

  factory DoctorModel.fromMap(Map<String, dynamic> map, String documentId) {
    return DoctorModel(
      id: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      specialty: map['specialty'] ?? '',
      diseaseSpecialty: map['diseaseSpecialty'] ?? '',
      phone: map['phone'] ?? '',
      hospital: map['hospital'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'specialty': specialty,
      'diseaseSpecialty': diseaseSpecialty,
      'phone': phone,
      'hospital': hospital,
    };
  }
}
