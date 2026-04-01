class MeasurementModel {
  final String id;
  final String userId;
  final String type; // e.g., "Weight", "Blood Pressure", "Blood Sugar"
  final String value; // e.g., "75", "120/80", "110"
  final String unit; // e.g., "kg", "mmHg", "mg/dL"
  final String date;
  final String time;

  MeasurementModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.value,
    required this.unit,
    required this.date,
    required this.time,
  });

  // From Firebase to Dart
  factory MeasurementModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MeasurementModel(
      id: documentId,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      value: map['value'] ?? '',
      unit: map['unit'] ?? '',
      date: map['date'] ?? '',
      time: map['time'] ?? '',
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
      'time': time,
    };
  }
}