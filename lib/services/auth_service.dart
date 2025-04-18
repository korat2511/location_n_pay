import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get user role
  Future<String> getUserRole() async {
    if (_auth.currentUser == null) return '';
    
    try {
      final doc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
      
      return doc.data()?['role'] ?? 'delivery_boy';
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return '';
    }
  }

  // Create user document in Firestore
  Future<void> _createUserDocument(User user, String role) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'role': role,
        'created_at': FieldValue.serverTimestamp(),
      });
      debugPrint('User document created successfully for ${user.email}');
    } catch (e) {
      debugPrint('Error creating user document: $e');
      // If we can't create the user document, delete the auth user
      await user.delete();
      throw Exception('Failed to create user profile. Please try again.');
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Check if user document exists
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
      
      if (!userDoc.exists) {
        debugPrint('User document not found, creating one...');
        await _createUserDocument(userCredential.user!, 'delivery_boy');
      }
      
      return userCredential;
    } catch (e) {
      debugPrint('Error in signInWithEmailAndPassword: $e');
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password, {String role = 'delivery_boy'}) async {
    try {
      debugPrint('Starting user registration for $email with role: $role');
      
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      debugPrint('Auth user created, creating Firestore document...');
      
      // Create user document
      await _createUserDocument(userCredential.user!, role);
      
      debugPrint('Registration completed successfully');
      return userCredential;
    } catch (e) {
      debugPrint('Error in registerWithEmailAndPassword: $e');
      // If the user was created in Auth but not in Firestore, clean up
      if (_auth.currentUser != null) {
        await _auth.currentUser!.delete();
      }
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Check if user is logged in
  bool isLoggedIn() {
    return _auth.currentUser != null;
  }

  // Check if user is admin
  Future<bool> isAdmin() async {
    return await getUserRole() == 'admin';
  }
} 