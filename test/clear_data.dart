import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:medicare_app/services/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final snapshot = await FirebaseFirestore.instance.collection('users')
    .where('role', isEqualTo: 'Pharmacist')
    .get();
    
  for (var doc in snapshot.docs) {
    print('Resetting user: ${doc.id}');
    await doc.reference.update({
      'verificationStatus': 'NOT_SUBMITTED',
      'certificateImageUrl': FieldValue.delete(),
    });
  }
  print('Done resetting pharmacists.');
}
