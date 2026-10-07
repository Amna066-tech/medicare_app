class MeasurementModel {
  final String id;
  final String userId;
  final String type; // e.g., "Weight", "Blood Pressure", "Blood Sugar"
  final String value; // e.g., "75", "120/80", "110"
  final String unit; // e.g., "kg", "mmHg", "mg/dL"
  final String frequency;
  final String startDate;
  final List<dynamic> reminderTimes;

  MeasurementModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.value,
    required this.unit,
    required this.frequency,
    required this.startDate,
    required this.reminderTimes,
  });

  // From Firebase to Dart
  factory MeasurementModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MeasurementModel(
      id: documentId,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      value: map['value'] ?? '',
      unit: map['unit'] ?? '',
      frequency: map['frequency'] ?? 'Once a day',
      startDate: map['startDate'] ?? map['date'] ?? '', // Fallback to 'date' for older docs
      reminderTimes: map['reminderTimes'] != null 
          ? List<dynamic>.from(map['reminderTimes']) 
          : (map['time'] != null ? [map['time']] : []), // Fallback to 'time' for older docs
    );
  }

  // From Dart to Firebase
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'value': value,
      'unit': unit,
      'frequency': frequency,
      'startDate': startDate,
      'reminderTimes': reminderTimes,
    };
  }
}