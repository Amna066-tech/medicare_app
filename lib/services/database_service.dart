import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medication_model.dart';
import '../models/measurement_model.dart';
import '../models/activity_model.dart';
import '../models/appointment_model.dart';
import '../models/intake_model.dart';
import '../services/notification_service.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get the current user's ID
  String get currentUserId => _auth.currentUser!.uid;

  // ADD MEDICATION
  Future<String> addMedication(MedicationModel medication) async {
    String res = "Some error occurred";
    try {
      // Create a new document in the 'medications' collection
      DocumentReference docRef = await _firestore.collection('medications').add(medication.toMap());
      res = docRef.id; // Return the generated ID instead of just "success"
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  // FETCH MEDICATIONS (Real-time Stream)
  Stream<List<MedicationModel>> getMedications() {
    return _firestore
        .collection('medications')
        .where('userId', isEqualTo: currentUserId) // Only get THIS user's meds
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return MedicationModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }
  // UPDATE MEDICATION
  Future<String> updateMedication(MedicationModel medication) async {
    String res = "Some error occurred";
    try {
      // Find the specific document by its ID and update it
      await _firestore.collection('medications').doc(medication.id).update(medication.toMap());
      res = "success";
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  // DELETE MEDICATION
  Future<String> deleteMedication(String medicationId) async {
    String res = "Some error occurred";
    try {
      // Find the specific document by its ID and delete it completely
      await _firestore.collection('medications').doc(medicationId).delete();
      res = "success";
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  // PROCESS MEDICATION INTAKE (Atomic Decrement)
  Future<void> processMedicationIntake(String medicationId) async {
    final docRef = _firestore.collection('medications').doc(medicationId);

    try {
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          return; // Medication doesn't exist anymore
        }

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        
        if (data['stock'] != null && data['stock'] > 0) {
          int currentStock = data['stock'];
          int newStock = currentStock - 1;
          bool currentLowStockNotified = data['lowStockNotified'] ?? false;
          bool currentOutOfStockNotified = data['outOfStockNotified'] ?? false;
          
          bool shouldNotifyLow = newStock <= 3 && newStock > 0 && !currentLowStockNotified;
          bool shouldNotifyOut = newStock == 0 && !currentOutOfStockNotified;

          // Perform atomic update
          transaction.update(docRef, {
            'stock': FieldValue.increment(-1),
            if (shouldNotifyLow) 'lowStockNotified': true,
            if (shouldNotifyOut) 'outOfStockNotified': true,
          });

          // Fire local notifications after transaction completes
          String medName = data['name'] ?? 'Unknown Medication';
          
          if (shouldNotifyOut) {
            await NotificationService().showInstantNotification(
              id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
              title: "Out of Stock: $medName",
              body: "You have no doses left. Please refill immediately.",
            );
          } else if (shouldNotifyLow) {
            await NotificationService().showInstantNotification(
              id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
              title: "Refill Reminder: $medName",
              body: "Low stock alert! Only $newStock doses left. Please refill your medicine.",
            );
          }
        }
      });
    } catch (e) {
      print("Error processing medication intake: $e");
    }
  }
  // ADD MEASUREMENT
  Future<String> addMeasurement(MeasurementModel measurement) async {
    String res = "Some error occurred";
    try {
      await _firestore.collection('measurements').add(measurement.toMap());
      res = "success";
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  // FETCH MEASUREMENTS
  Stream<List<MeasurementModel>> getMeasurements() {
    return _firestore
        .collection('measurements')
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return MeasurementModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }
  // ADD ACTIVITY
  Future<String> addActivity(ActivityModel activity) async {
    String res = "Some error occurred";
    try {
      await _firestore.collection('activities').add(activity.toMap());
      res = "success";
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  // FETCH ACTIVITIES
  Stream<List<ActivityModel>> getActivities() {
    return _firestore
        .collection('activities')
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ActivityModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // ADD APPOINTMENT
  Future<String> addAppointment(AppointmentModel appointment) async {
    String res = "Some error occurred";
    try {
      await _firestore.collection('appointments').add(appointment.toMap());
      res = "success";
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  // FETCH APPOINTMENTS
  Stream<List<AppointmentModel>> getAppointments() {
    return _firestore
        .collection('appointments')
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return AppointmentModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // LOG MEDICATION INTAKE
  Future<String> logIntake(IntakeModel intake) async {
    String res = "Some error occurred";
    try {
      // Create a unique ID for this specific medicine on this specific date
      String uniqueDocId = "${intake.medicationId}_${intake.date}";

      // We use .set() instead of .add() so it overwrites if they change their mind
      await _firestore.collection('intakes').doc(uniqueDocId).set(intake.toMap());
      res = "success";
    } catch (err) {
      res = err.toString();
    }
    return res;
  }
}