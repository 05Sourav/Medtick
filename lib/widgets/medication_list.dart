import 'package:flutter/material.dart';
import '../models/medication_reminder.dart';

class MedicationList extends StatelessWidget {
  final List<MedicationReminder> medications;
  final Function(int) onDelete;
  final Function(int, MedicationReminder) onUndoDelete;

  const MedicationList({
    super.key,
    required this.medications,
    required this.onDelete,
    required this.onUndoDelete,
  });

  @override
  Widget build(BuildContext context) {
    return medications.isEmpty
        ? const Center(
      child: Text('No medications added yet'),
    )
        : ListView.builder(
      itemCount: medications.length,
      itemBuilder: (context, index) {
        final medication = medications[index];
        return Dismissible(
          key: Key(medication.name + index.toString()),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
            ),
          ),
          onDismissed: (direction) {
            onDelete(index);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${medication.name} removed'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () => onUndoDelete(index, medication),
                ),
              ),
            );
          },
          child: Card(
            margin: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.medication),
              ),
              title: Text(medication.name),
              subtitle: Text(medication.dosage),
              trailing: Text(
                '${medication.time.hour}:${medication.time.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}