import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medication_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class AddMedicationScreen extends StatefulWidget {
  final String? patientId;

  const AddMedicationScreen({super.key, this.patientId});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();

  String _selectedFrequency = "Once a day";
  int _timesPerDay = 1;
  List<DateTime> _selectedDates = [DateTime.now()];
  List<TimeOfDay?> _selectedTimes = [null];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    NotificationService().requestPermission();
  }

  void _onFrequencyChanged(String? val) {
    if (val == null) return;
    setState(() {
      _selectedFrequency = val;
      if (val == "Once a day") {
        _selectedTimes = [null];
      } else if (val == "Twice a day") {
        _selectedTimes = [null, null];
      } else if (val == "3 times a day") {
        _selectedTimes = [null, null, null];
      } else if (val == "Everyday" || val == "Specific Dates") {
        _selectedTimes = List.generate(_timesPerDay, (index) => null);
      }
      
      if (val != "Specific Dates") {
        _selectedDates = [_selectedDates.isNotEmpty ? _selectedDates.first : DateTime.now()];
      }
    });
  }

  void _onTimesPerDayChanged(int? val) {
    if (val == null) return;
    setState(() {
      _timesPerDay = val;
      _selectedTimes = List.generate(_timesPerDay, (index) => null);
    });
  }

  Future<DateTime?> _pickDate(BuildContext context, DateTime initialDate) async {
    return await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1550A6),
              onPrimary: Colors.white,
              onSurface: Color(0xFF2C3E50),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context, int index) async {
    final DateTime? picked = await _pickDate(context, _selectedDates[index]);
    if (picked != null) {
      setState(() {
        _selectedDates[index] = picked;
      });
    }
  }

  Future<void> _addSpecificDate(BuildContext context) async {
    final DateTime? picked = await _pickDate(context, DateTime.now());
    if (picked != null) {
      setState(() {
        _selectedDates.add(picked);
      });
    }
  }

  Future<void> _selectTime(BuildContext context, int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1550A6),
              onPrimary: Colors.white,
              onSurface: Color(0xFF2C3E50),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTimes[index] = picked;
      });
    }
  }

  void saveMedication() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Medicine Name is required!")));
      return;
    }
    if (_selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("At least one date is required!")));
      return;
    }
    if (_selectedTimes.any((t) => t == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All reminder times must be set!")));
      return;
    }

    setState(() => _isLoading = true);

    List<String> formattedDates = _selectedDates.map((d) => d.toString().substring(0, 10)).toList();
    List<String> formattedTimes = _selectedTimes.map((t) => t!.format(context)).toList();
    
    final String targetUid = widget.patientId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    MedicationModel newMed = MedicationModel(
      id: '',
      userId: targetUid,
      name: _nameController.text,
      dosage: _dosageController.text.isEmpty ? "1 pill" : _dosageController.text,
      diseaseName: "N/A",
      frequency: _selectedFrequency,
      startDate: formattedDates.first,
      endDate: _selectedFrequency == "Specific Dates" ? formattedDates.last : "Ongoing",
      reminderTimes: formattedTimes,
      selectedDates: formattedDates,
      stock: int.tryParse(_stockController.text),
    );

    String res = await DatabaseService().addMedication(newMed);

    if (res != "Some error occurred" && res.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('medical_history').add({
          'userId': targetUid,
          'title': 'New Medication: ${_nameController.text} (${_dosageController.text})',
          'category': 'Medication',
          'status': 'Scheduled',
          'timestamp': FieldValue.serverTimestamp(),
        });

        final now = DateTime.now();
        bool repeatDaily = _selectedFrequency != "Specific Dates";

        for (var date in _selectedDates) {
          for (var time in _selectedTimes) {
             DateTime scheduledDate = DateTime(
                date.year, date.month, date.day, time!.hour, time.minute);

             if (scheduledDate.isBefore(now) && !repeatDaily) {
                // Skip scheduling alarms that are strictly in the past for non-repeating alarms
                continue;
             } else if (scheduledDate.isBefore(now) && repeatDaily) {
                scheduledDate = scheduledDate.add(const Duration(days: 1));
             }

             int notificationId = scheduledDate.millisecondsSinceEpoch.remainder(100000);

             await NotificationService().scheduleReminderNotification(
               id: notificationId,
               itemTitle: _nameController.text,
               category: "Medication",
               subtitle: "Please take ${_dosageController.text}.",
               medicationId: res, // The generated document ID
               scheduledTime: scheduledDate,
               repeatDaily: repeatDaily,
             );
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Medication saved successfully!")));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved to DB, but Alarm/History failed: $e")));
          Navigator.pop(context);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res)));
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFFF2F4F7),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Add Medication",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 24),
              _buildInputField(
                controller: _nameController,
                hint: "Medicine Name",
                icon: Icons.medical_services,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                controller: _dosageController,
                hint: "Dosage (e.g. 1 pill)",
                icon: Icons.science,
              ),
              const SizedBox(height: 16),
              _buildDropdownField(),
              if (_selectedFrequency == 'Everyday' || _selectedFrequency == 'Specific Dates') ...[
                const SizedBox(height: 16),
                _buildTimesPerDayDropdown(),
              ],
              const SizedBox(height: 16),
              if (_selectedFrequency == 'Specific Dates')
                _buildSpecificDatesSection(context)
              else
                _buildSingleDatePickerField(context),
              const SizedBox(height: 16),
              ...List.generate(_selectedTimes.length, (index) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildTimePickerField(context, index),
              )),
              _buildInputField(
                controller: _stockController,
                hint: "Stock (Optional)",
                icon: Icons.inventory_2,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel", style: TextStyle(color: Color(0xFF1550A6), fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : saveMedication,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1550A6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Save", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String hint, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: const Color(0xFF1550A6)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedFrequency,
              icon: const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Icon(Icons.arrow_drop_down, color: Colors.grey),
              ),
              items: ['Once a day', 'Twice a day', '3 times a day', 'Everyday', 'Specific Dates']
                  .map((freq) => DropdownMenuItem(
                value: freq,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.repeat, color: Color(0xFF1550A6)),
                    const SizedBox(width: 12),
                    Text(freq, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ))
                  .toList(),
              onChanged: _onFrequencyChanged,
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: 0,
          child: Container(
            color: const Color(0xFFF2F4F7),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              "Frequency",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimesPerDayDropdown() {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: _timesPerDay,
              icon: const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Icon(Icons.arrow_drop_down, color: Colors.grey),
              ),
              items: [1, 2, 3]
                  .map((val) => DropdownMenuItem(
                value: val,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time, color: Color(0xFF1550A6)),
                    const SizedBox(width: 12),
                    Text("$val time${val > 1 ? 's' : ''} a day", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ))
                  .toList(),
              onChanged: _onTimesPerDayChanged,
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: 0,
          child: Container(
            color: const Color(0xFFF2F4F7),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              "Times per day",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleDatePickerField(BuildContext context) {
    return InkWell(
      onTap: () => _selectDate(context, 0),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFF1550A6)),
            const SizedBox(width: 12),
            Text(
              _selectedDates.isNotEmpty ? _selectedDates[0].toString().substring(0, 10) : "",
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecificDatesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _selectedDates.asMap().entries.map((entry) {
            int idx = entry.key;
            DateTime date = entry.value;
            return Chip(
              label: Text(date.toString().substring(0, 10)),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () {
                setState(() {
                  _selectedDates.removeAt(idx);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _addSpecificDate(context),
          icon: const Icon(Icons.add, color: Color(0xFF1550A6)),
          label: const Text("Add Date", style: TextStyle(color: Color(0xFF1550A6), fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildTimePickerField(BuildContext context, int index) {
    return InkWell(
      onTap: () => _selectTime(context, index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Color(0xFF1550A6)),
            const SizedBox(width: 12),
            Text(
              _selectedTimes.length > index && _selectedTimes[index] != null 
                  ? _selectedTimes[index]!.format(context) 
                  : "Reminder Time ${index + 1}",
              style: TextStyle(
                fontSize: 16,
                color: _selectedTimes.length > index && _selectedTimes[index] != null ? Colors.black87 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}