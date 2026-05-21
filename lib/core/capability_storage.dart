import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CapabilityStorage {
  static final CapabilityStorage _instance = CapabilityStorage._internal();
  factory CapabilityStorage() => _instance;
  CapabilityStorage._internal();

  static const String _prefix = 'cap_';

  Future<void> storeData(String capabilityId, String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$_prefix$capabilityId';
    final raw = prefs.getString(storageKey);
    final Map<String, dynamic> data = raw != null
        ? jsonDecode(raw) as Map<String, dynamic>
        : {};
    data[key] = value;
    await prefs.setString(storageKey, jsonEncode(data));
  }

  Future<dynamic> retrieveData(String capabilityId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$_prefix$capabilityId';
    final raw = prefs.getString(storageKey);
    if (raw == null) return null;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return data[key];
  }

  Future<Map<String, dynamic>> retrieveAllData(String capabilityId) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$_prefix$capabilityId';
    final raw = prefs.getString(storageKey);
    if (raw == null) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<bool> removeData(String capabilityId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$_prefix$capabilityId';
    final raw = prefs.getString(storageKey);
    if (raw == null) return false;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (!data.containsKey(key)) return false;
    data.remove(key);
    await prefs.setString(storageKey, jsonEncode(data));
    return true;
  }

  Future<bool> clearData(String capabilityId) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$_prefix$capabilityId';
    return prefs.remove(storageKey);
  }

  Future<List<String>> getStoredCapabilityIds() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    return keys
        .where((k) => k.startsWith(_prefix))
        .map((k) => k.substring(_prefix.length))
        .toList();
  }
}
