import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddScheduleScreen extends StatefulWidget {
  const AddScheduleScreen({super.key});

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  final TextEditingController _workoutNameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _workoutNameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showWorkoutSelectionDialog() async {
    final String? selectedWorkout = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Workout Menu'),
          content: WorkoutSelectionDialog(
            onSelectWorkout: (workoutName) {
              Navigator.of(context).pop(workoutName);
            },
          ),
        );
      },
    );

    if (selectedWorkout != null) {
      _workoutNameController.text = selectedWorkout;
    }
  }

  void _saveSchedule() {
    // Implement save logic here
    if (_workoutNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a workout menu.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Schedule saved: ${_workoutNameController.text} on ${DateFormat('yyyy-MM-dd').format(_selectedDate)}'),
      ),
    );
    Navigator.pop(context); // Go back after saving
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Schedule'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _showWorkoutSelectionDialog,
              child: AbsorbPointer( // Prevents the TextField from gaining focus
                child: TextField(
                  controller: _workoutNameController,
                  decoration: const InputDecoration(
                    labelText: 'Selected Workout',
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  readOnly: true, // Make it read-only
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: () => _selectDate(context),
                  child: const Text('Select Date'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveSchedule,
              child: const Text('Save Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget to select workout from a dialog
class WorkoutSelectionDialog extends StatelessWidget {
  final ValueChanged<String> onSelectWorkout;

  const WorkoutSelectionDialog({super.key, required this.onSelectWorkout});

  final List<String> _workoutMenus = const ['Smolov Jr.', '10x10'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.maxFinite,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _workoutMenus.length,
        itemBuilder: (context, index) {
          final menuName = _workoutMenus[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 5), // Consistent spacing
            child: GestureDetector(
              onTap: () => onSelectWorkout(menuName),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          menuName,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
