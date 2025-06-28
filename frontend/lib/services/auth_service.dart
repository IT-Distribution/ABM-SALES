import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'http://localhost:8000'; // Ajustez selon votre configuration
  static const String tokenKey = 'auth_token';
  static const String userTypeKey = 'user_type';
  static const String userEmailKey = 'user_email';
  
  // Identifiants admin par défaut
  static const String adminEmail = 'Abm2025@gmail.com';
  static const String adminPassword = 'Abm2025@';

  Future<bool> login(String username, String password, {bool isAdmin = false}) async {
    try {
      // Vérification des identifiants admin
      if (isAdmin) {
        if (username == adminEmail && password == adminPassword) {
          await _saveToken('admin_token');
          await _saveUserType(true);
          await _saveUserEmail(username);
          return true;
        }
        return false;
      }

      // Pour les utilisateurs normaux, utiliser l'API
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': username,
          'password': password,
        },
      );

      print('Réponse du serveur: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['access_token'];
        await _saveToken(token);
        await _saveUserType(isAdmin);
        await _saveUserEmail(username);
        return true;
      }
      return false;
    } catch (e) {
      print('Erreur de connexion: $e');
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(userTypeKey);
    await prefs.remove(userEmailKey);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(userEmailKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Future<bool> isAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(userTypeKey) ?? false;
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
  }

  Future<void> _saveUserType(bool isAdmin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(userTypeKey, isAdmin);
  }

  Future<void> _saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userEmailKey, email);
  }
} 