class MedicationModel {
  String id;
  String userId;
  String name;
  String dosage;
  String diseaseName; // UPDATED: Added field for health condition
  String frequency;
  String startDate;
  String endDate;
  List<dynamic> reminderTimes;

  MedicationModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.dosage,
    required this.diseaseName, // UPDATED
    required this.frequency,
    required this.startDate,
    required this.endDate,
    required this.reminderTimes,
  });

  // Converts Firestore data into our Model
  factory MedicationModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MedicationModel(
      id: documentId,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      diseaseName: map['diseaseName'] ?? 'General Care', // UPDATED
      frequency: map['frequency'] ?? 'Once a day',
      startDate: map['startDate'] ?? '',
      endDate: map['endDate'] ?? '',
      reminderTimes: map['reminderTimes'] ?? [],
    );
  }

  // Converts our Model into Firestore data
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'dosage': dosage,
      'diseaseName': diseaseName, // UPDATED
      'frequency': frequency,
      'startDate': startDate,
      'endDate': endDate,
      'reminderTimes': reminderTimes,
    };
  }
}