class AppointmentModel {
  final String id;
  final String userId;
  final String doctorName;
  final String specialty; // e.g., "Cardiologist", "General Physician"
  final String date;
  final String time;
  final String notes;

  AppointmentModel({
    required this.id,
    required this.userId,
    required this.doctorName,
    required this.specialty,
    required this.date,
    required this.time,
    required this.notes,
  });

  factory AppointmentModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AppointmentModel(
      id: documentId,
      userId: map['userId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      specialty: map['specialty'] ?? '',
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      notes: map['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'doctorName': doctorName,
      'specialty': specialty,
      'date': date,
      'time': time,
      'notes': notes,
    };
  }
}