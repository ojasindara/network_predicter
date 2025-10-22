import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  // 🧾 Sign up
  Future<User?> signUp(String email, String password) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
    );
    return response.user; // Returns the newly created user
  }

  // 🔑 Sign in
  Future<User?> signIn(String email, String password) async {
    final response = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.user; // Returns signed-in user
  }

  // 🚪 Sign out
  Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}
