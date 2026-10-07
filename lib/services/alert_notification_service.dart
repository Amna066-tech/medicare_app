import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'dart:async';

class AlertNotificationService {
  static final AlertNotificationService _instance = AlertNotificationService._internal();
  factory AlertNotificationService() => _instance;
  AlertNotificationService._internal();

  StreamSubscription<QuerySnapshot>? _alertSubscription;
  DateTime? _listenerStartTime;

  final Set<String> _processedAlertIds = {};

  Future<void> checkUnreadOnLogin() async {
    // We can leave this empty or remove it, but since it's called in initState
    // we'll just let it be a no-op because startListening now handles both
    // initial unread load and real-time updates robustly!
  }

  void startListening() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _alertSubscription?.cancel();
    
    // Listen to dismiss_alerts where caregiverId matches and the caregiver hasn't read it
    _alertSubscription = FirebaseFirestore.instance
        .collection('dismiss_alerts')
        .where('caregiverId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          final readBy = List<String>.from(data?['readBy'] ?? []);
          
          // If the caregiver hasn't read it and we haven't processed it
          if (data != null && !readBy.contains(user.uid) && !_processedAlertIds.contains(change.doc.id)) {
            _processedAlertIds.add(change.doc.id);
            
            final patientName = data['patientName'] ?? 'Unknown';
            final category = data['category'] ?? 'TASK';
            final itemTitle = data['itemTitle'] ?? '';
            final patientId = data['patientId'] ?? '';

            final title = 'Alert: Task Dismissed';
            final message = '$patientName has dismissed their ${category.toLowerCase()}: $itemTitle';

            NotificationService().showInstantNotification(
              id: change.doc.id.hashCode.abs().remainder(100000),
              title: title,
              body: message,
              payload: '{"type": "alert", "alertId": "${change.doc.id}", "patientId": "$patientId"}'
            );
          }
        }
      }
    });
  }

  void stopListening() {
    _alertSubscription?.cancel();
    _alertSubscription = null;
    _processedAlertIds.clear();
  }
}
