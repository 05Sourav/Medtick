// lib/services/storage_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../models/medication_reminder.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

class StorageService {
  static const String _medicationsKey = 'medications';

  // Save medications to storage
  Future<void> saveMedications(List<MedicationReminder> medications) async {
    final prefs = await SharedPreferences.getInstance();
    final medicationList = medications.map((med) => med.toJson()).toList();
    await prefs.setString(_medicationsKey, jsonEncode(medicationList));
  }

  // Load medications from storage
  Future<List<MedicationReminder>> loadMedications() async {
    final prefs = await SharedPreferences.getInstance();
    final medicationsString = prefs.getString(_medicationsKey);

    if (medicationsString == null) {
      return [];
    }

    try {
      final medicationsList = jsonDecode(medicationsString) as List;
      return medicationsList
          .map((med) => MedicationReminder.fromJson(med as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading medications: $e');
      return [];
    }
  }

  // Clear all medications from storage
  Future<void> clearMedications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_medicationsKey);
  }
}