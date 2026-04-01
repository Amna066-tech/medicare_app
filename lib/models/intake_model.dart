class IntakeModel {
  final String id;
  final String userId;
  final String medicationId;
  final String medicationName;
  final String date; // e.g., "2026-03-08"
  final String status; // "Taken" or "Missed"

  IntakeModel({
    required this.id,
    required this.userId,
    required this.medicationId,
    required this.medicationName,
    required this.date,
    required this.status,
  });

  factory IntakeModel.fromMap(Map<String, dynamic> map, String documentId) {
    return IntakeModel(
      id: documentId,
      userId: map['userId'] ?? '',
      medicationId: map['medicationId'] ?? '',
      medicationName: map['medicationName'] ?? '',
      date: map['date'] ?? '',
      status: map['status'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'medicationId': medicationId,
      'medicationName': medicationName,
      'date': date,
      'status': status,
    };
  }
}