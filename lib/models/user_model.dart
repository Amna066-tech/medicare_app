class UserModel {
  final String uid;
  final String name;
  final String email;
  final String dateOfBirth;
  final String gender;
  final String role;
  
  final String verificationStatus;

  // Role-specific optional fields
  final String? speciality;
  final String? licenseNumber;
  final String? caregiverType;
  final String? nursingLicenseNumber;
  final String? pharmacyName;
  final String? pharmacyAddress;
  final String? drugLicenseNumber;
  final String? certificateImageUrl;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.dateOfBirth,
    required this.gender,
    required this.role,
    this.verificationStatus = 'NOT_SUBMITTED',
    this.speciality,
    this.licenseNumber,
    this.caregiverType,
    this.nursingLicenseNumber,
    this.pharmacyName,
    this.pharmacyAddress,
    this.drugLicenseNumber,
    this.certificateImageUrl,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      dateOfBirth: map['dateOfBirth'] ?? '',
      gender: map['gender'] ?? '',
      role: map['role'] ?? 'Patient',
      verificationStatus: map['verificationStatus'] ?? 'NOT_SUBMITTED',
      speciality: map['speciality'],
      licenseNumber: map['licenseNumber'],
      caregiverType: map['caregiverType'],
      nursingLicenseNumber: map['nursingLicenseNumber'],
      pharmacyName: map['pharmacyName'],
      pharmacyAddress: map['pharmacyAddress'],
      drugLicenseNumber: map['drugLicenseNumber'],
      certificateImageUrl: map['certificateImageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'role': role,
      'verificationStatus': verificationStatus,
      'speciality': speciality,
      'licenseNumber': licenseNumber,
      'caregiverType': caregiverType,
      'nursingLicenseNumber': nursingLicenseNumber,
      'pharmacyName': pharmacyName,
      'pharmacyAddress': pharmacyAddress,
      'drugLicenseNumber': drugLicenseNumber,
      'certificateImageUrl': certificateImageUrl,
    };
  }
}
