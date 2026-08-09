class DoctorRequestModel {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorName;
  final String doctorEmail;
  final String doctorPhone;
  final String website;
  final String specialty;
  final String street;
  final String postcode;
  final String city;
  final String status; // "Pending", "Accepted", "Declined"
  final String timestamp;

  DoctorRequestModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorName,
    required this.doctorEmail,
    required this.doctorPhone,
    required this.website,
    required this.specialty,
    required this.street,
    required this.postcode,
    required this.city,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'doctorName': doctorName,
      'doctorEmail': doctorEmail,
      'doctorPhone': doctorPhone,
      'website': website,
      'specialty': specialty,
      'street': street,
      'postcode': postcode,
      'city': city,
      'status': status,
      'timestamp': timestamp,
    };
  }

  factory DoctorRequestModel.fromMap(Map<String, dynamic> map, String documentId) {
    return DoctorRequestModel(
      id: documentId,
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      doctorName: map['doctorName'] ?? '',
      doctorEmail: map['doctorEmail'] ?? '',
      doctorPhone: map['doctorPhone'] ?? '',
      website: map['website'] ?? '',
      specialty: map['specialty'] ?? '',
      street: map['street'] ?? '',
      postcode: map['postcode'] ?? '',
      city: map['city'] ?? '',
      status: map['status'] ?? 'Pending',
      timestamp: map['timestamp'] ?? '',
    );
  }
}