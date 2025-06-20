// lib/models/medication_reminder.dart

import 'package:flutter/material.dart';
import 'dart:convert';

class MedicationReminder {
  final String name;
  final String dosage;
  final TimeOfDay time;

  MedicationReminder({
    required this.name,
    required this.dosage,
    required this.time,
  });

  // Convert TimeOfDay to String for storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      'hour': time.hour,
      'minute': time.minute,
    };
  }

  // Create MedicationReminder from stored JSON
  factory MedicationReminder.fromJson(Map<String, dynamic> json) {
    return MedicationReminder(
      name: json['name'],
      dosage: json['dosage'],
      time: TimeOfDay(hour: json['hour'], minute: json['minute']),
    );
  }
}