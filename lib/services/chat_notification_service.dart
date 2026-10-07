import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'dart:async';

class ChatNotificationService {
  static final ChatNotificationService _instance = ChatNotificationService._internal();
  factory ChatNotificationService() => _instance;
  ChatNotificationService._internal();

  StreamSubscription<QuerySnapshot>? _chatSubscription;
  final Map<String, Timestamp> _lastSeenMessageTimestamps = {};
  DateTime? _listenerStartTime;

  Future<void> checkUnreadOnLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final chatsQuery = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: user.uid)
        .get();

    for (var chatDoc in chatsQuery.docs) {
      final messagesQuery = await chatDoc.reference.collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      int unreadCount = 0;
      String lastUnreadMessage = '';
      String lastUnreadSenderRole = '';
      String lastSenderName = chatDoc.data()['lastSenderName'] ?? 'Someone';

      for (var msgDoc in messagesQuery.docs) {
        final data = msgDoc.data();
        final readBy = List<String>.from(data['readBy'] ?? []);
        if (data['senderId'] != user.uid && !readBy.contains(user.uid)) {
          unreadCount++;
          if (unreadCount == 1) {
            lastUnreadMessage = data['message'] ?? '';
            lastUnreadSenderRole = data['senderRole'] ?? '';
          }
        }
      }

      if (unreadCount > 0) {
        String title = unreadCount == 1 ? "New message from $lastSenderName" : "$unreadCount new messages from $lastSenderName";
        
        NotificationService().showInstantNotification(
          id: chatDoc.id.hashCode.abs(),
          title: title,
          body: unreadCount == 1 ? lastUnreadMessage : "You have $unreadCount unread messages in this chat.",
          payload: '{"type": "chat", "chatId": "${chatDoc.id}", "peerName": "$lastSenderName"}'
        );
      }
    }
  }

  void startListening() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _listenerStartTime = DateTime.now();
    _chatSubscription?.cancel();
    
    _chatSubscription = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: user.uid)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified || change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final lastSenderId = data['lastSenderId'];
            final lastMessage = data['lastMessage'] ?? 'New Message';
            final lastSenderName = data['lastSenderName'] ?? 'Someone';
            final Timestamp? timestamp = data['timestamp'] as Timestamp?;

            // Only notify for messages that arrive AFTER we started listening (real-time).
            // The checkUnreadOnLogin method handles messages that arrived while we were offline.
            if (lastSenderId != user.uid && timestamp != null && timestamp.toDate().isAfter(_listenerStartTime!)) {
              final previousTimestamp = _lastSeenMessageTimestamps[change.doc.id];
              if (previousTimestamp == null || timestamp.compareTo(previousTimestamp) > 0) {
                _lastSeenMessageTimestamps[change.doc.id] = timestamp;
                
                NotificationService().showInstantNotification(
                  id: change.doc.id.hashCode.abs(),
                  title: "New Message from $lastSenderName",
                  body: lastMessage,
                  payload: '{"type": "chat", "chatId": "${change.doc.id}", "peerName": "$lastSenderName"}'
                );
              }
            }
          }
        }
      }
    });
  }

  void stopListening() {
    _chatSubscription?.cancel();
    _chatSubscription = null;
  }
}
