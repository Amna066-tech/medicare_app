class MedicationModel {
  String id;
  String userId;
  String name;
  String dosage;
  String frequency;
  String startDate;
  String endDate;
  List<dynamic> reminderTimes; // UPGRADED: This is now a List to hold multiple alarms!

  MedicationModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.dosage,
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
      frequency: map['frequency'] ?? 'Once a day',
      startDate: map['startDate'] ?? '',
      endDate: map['endDate'] ?? '',
      reminderTimes: map['reminderTimes'] ?? [], // Safely grabs the list
    );
  }

  // Converts our Model into Firestore data
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'startDate': startDate,
      'endDate': endDate,
      'reminderTimes': reminderTimes, // Saves the list to the database
    };
  }
}