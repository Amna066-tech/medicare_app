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
  List<String> selectedDates;
  int? stock; // Added field for tracking stock
  bool lowStockNotified;
  bool outOfStockNotified;

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
    required this.selectedDates,
    this.stock,
    this.lowStockNotified = false,
    this.outOfStockNotified = false,
  });

  // Converts Firestore data into our Model
  factory MedicationModel.fromMap(Map<String, dynamic> map, String documentId) {
    List<String> parsedDates = [];
    if (map['selectedDates'] != null) {
      parsedDates = List<String>.from(map['selectedDates']);
    } else if (map['startDate'] != null) {
      parsedDates = [map['startDate']];
    }

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
      selectedDates: parsedDates,
      stock: map['stock'],
      lowStockNotified: map['lowStockNotified'] ?? false,
      outOfStockNotified: map['outOfStockNotified'] ?? false,
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
      'selectedDates': selectedDates,
      'stock': stock,
      'lowStockNotified': lowStockNotified,
      'outOfStockNotified': outOfStockNotified,
    };
  }
}