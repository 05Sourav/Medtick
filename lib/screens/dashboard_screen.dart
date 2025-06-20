import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/medication_reminder.dart';
import '../widgets/medication_list.dart';
import '../widgets/sidebar_widget.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final NotificationService _notificationService = NotificationService();
  final StorageService _storageService = StorageService();
  bool _isSidebarOpen = false;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<MedicationReminder> _medications = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadMedications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initializeNotifications();
    } catch (e) {
      debugPrint('Notification initialization error: $e');
      // Continue even if notifications fail to initialize
    }
  }

  Future<void> _loadMedications() async {
    try {
      final medications = await _storageService.loadMedications();
      setState(() {
        _medications = medications;
      });
    } catch (e) {
      debugPrint('Error loading medications: $e');
    }
  }

  void _showAddMedicationDialog(BuildContext context) {
    String name = '';
    String dosage = '';
    TimeOfDay? selectedTime;
    bool isTimeSelected = false;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Medication'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Medication Name',
                  errorText: null,
                ),
                onChanged: (value) => name = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Dosage',
                  errorText: null,
                ),
                onChanged: (value) => dosage = value,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final TimeOfDay? time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    setDialogState(() {
                      selectedTime = time;
                      isTimeSelected = true;
                    });
                  }
                },
                child: Text(isTimeSelected
                    ? 'Selected Time: ${selectedTime?.format(context)}'
                    : 'Set Reminder Time'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            isSaving
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : TextButton(
              onPressed: () async {
                if (name.isEmpty || dosage.isEmpty || selectedTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setDialogState(() => isSaving = true);

                try {
                  final medication = MedicationReminder(
                    name: name,
                    dosage: dosage,
                    time: selectedTime!,
                  );

                  // First save the medication to the list
                  setState(() {
                    _medications = [..._medications, medication];
                  });
                  await _storageService.saveMedications(_medications);

                  // Then try to schedule notification
                  try {
                    await _notificationService.scheduleMedicationReminder(medication);
                    debugPrint('Notification scheduled for ${medication.name}');
                  } catch (notificationError) {
                    debugPrint('Notification scheduling failed: $notificationError');
                    // Show warning but don't prevent saving
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Medication saved but notifications may not work. Please check your settings.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Medication "$name" added successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error saving medication: $e');
                  if (context.mounted) {
                    setDialogState(() => isSaving = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error saving medication. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: Icon(_isSidebarOpen ? Icons.menu_open : Icons.menu),
            onPressed: () {
              setState(() {
                _isSidebarOpen = !_isSidebarOpen;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2025, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Today\'s Medications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: MedicationList(
                  medications: _medications,
                  onDelete: (index) async {
                    final medication = _medications[index];
                    try {
                      await _notificationService.cancelMedicationReminder(medication.name);
                    } catch (e) {
                      debugPrint('Error canceling notification: $e');
                    }
                    setState(() {
                      _medications.removeAt(index);
                    });
                    await _storageService.saveMedications(_medications);
                  },
                  onUndoDelete: (index, medication) async {
                    setState(() {
                      _medications.insert(index, medication);
                    });
                    await _storageService.saveMedications(_medications);
                    try {
                      await _notificationService.scheduleMedicationReminder(medication);
                    } catch (e) {
                      debugPrint('Error rescheduling notification: $e');
                    }
                  },
                ),
              ),
            ],
          ),
          if (_isSidebarOpen)
            SidebarWidget(
              onClose: () {
                setState(() {
                  _isSidebarOpen = false;
                });
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMedicationDialog(context),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication),
            label: 'My Medications',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}