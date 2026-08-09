import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // SIGN UP LOGIC
  Future<String> signUpUser({
    required String email,
    required String password,
    required String name,
    required String dateOfBirth,
    required String gender,
    required String role, // ADDED: Role is now required during signup
  }) async {
    String res = "Some error occurred";
    try {
      if (email.isNotEmpty && password.isNotEmpty && name.isNotEmpty) {
        // 1. Register the user in Firebase Authentication
        UserCredential cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // 2. Create our UserModel using the data they provided
        UserModel userModel = UserModel(
          uid: cred.user!.uid,
          name: name,
          email: email,
          dateOfBirth: dateOfBirth,
          gender: gender,
          role: role, // PASSED: Role to the model
        );

        // 3. Save the extra user details to Firestore database
        await _firestore
            .collection('users')
            .doc(cred.user!.uid)
            .set(userModel.toMap());

        res = "success";
      } else {
        res = "Please enter all the fields";
      }
    } on FirebaseAuthException catch (err) {
      res = err.message ?? "Authentication Error";
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  // LOGIN LOGIC
  Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    String res = "Some error occurred";
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        await _auth.signInWithEmailAndPassword(email: email, password: password);
        res = "success";
      } else {
        res = "Please enter all the fields";
      }
    } on FirebaseAuthException catch (err) {
      res = err.message ?? "Authentication Error";
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  // LOGOUT LOGIC
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
