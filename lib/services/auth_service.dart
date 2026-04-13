import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign Up
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String regNumber,
    required String course,
  }) async {
    try {
      // 1. Create User
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // 2. Send Verification Email
      await userCredential.user?.sendEmailVerification();

      // 3. Store User Details in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'registrationNumber': regNumber.trim(),
        'course': course.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } catch (e) {
      rethrow; // Pass error to UI
    }
  }

  // Sign In
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // 4. Check if verified
      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message: 'Please verify your email address before logging in. Check your inbox.',
        );
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }
}
