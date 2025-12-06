import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  FirebaseAuth? _auth;
  
  // Check if Firebase is initialized
  bool get isFirebaseInitialized {
    try {
      Firebase.app();
      return true;
    } catch (e) {
      return false;
    }
  }
  
  FirebaseAuth? get _firebaseAuth {
    if (!isFirebaseInitialized) {
      return null;
    }
    try {
      _auth ??= FirebaseAuth.instance;
      return _auth;
    } catch (e) {
      print('Error accessing FirebaseAuth: $e');
      return null;
    }
  }

  // Get current user
  User? get currentUser {
    final auth = _firebaseAuth;
    if (auth == null) {
      return null;
    }
    return auth.currentUser;
  }

  // Auth state stream
  Stream<User?> get authStateChanges {
    final auth = _firebaseAuth;
    if (auth == null) {
      return Stream.value(null);
    }
    return auth.authStateChanges();
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final auth = _firebaseAuth;
    if (auth == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      print('Sign in error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Unexpected sign in error: $e');
      rethrow;
    }
  }

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final auth = _firebaseAuth;
    if (auth == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      print('Sign up error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Unexpected sign up error: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    final auth = _firebaseAuth;
    if (auth == null) {
      return;
    }
    try {
      await auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
      rethrow;
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    final auth = _firebaseAuth;
    if (auth == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      await auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      print('Password reset error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Unexpected password reset error: $e');
      rethrow;
    }
  }

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;
}

