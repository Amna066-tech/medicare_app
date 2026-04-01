class ActivityModel {
  final String id;
  final String userId;
  final String type; // e.g., "Water", "Walking", "Exercise"
  final String value; // e.g., "4", "5000", "30"
  final String unit; // e.g., "glasses", "steps", "mins"
  final String date;

  ActivityModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.value,
    required this.unit,
    required this.date,
  });

  // From Firebase to Dart
  factory ActivityModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ActivityModel(
      id: documentId,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      value: map['value'] ?? '',
      unit: map['unit'] ?? '',
      date: map['date'] ?? '',
    );
  }

  // From Dart to Firebase
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'value': value,
      'unit': unit,
      'date': date,
    };
  }
}