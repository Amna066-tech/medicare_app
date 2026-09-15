import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MeasurementTrackerScreen extends StatefulWidget {
  const MeasurementTrackerScreen({super.key});

  @override
  State<MeasurementTrackerScreen> createState() => _MeasurementTrackerScreenState();
}

class _MeasurementTrackerScreenState extends State<MeasurementTrackerScreen> {
  String _selectedCategory = 'Blood Pressure';
  final List<String> _categories = ['Blood Pressure', 'Body Weight', 'Blood Sugar'];

  final TextEditingController _systolicController = TextEditingController();
  final TextEditingController _diastolicController = TextEditingController();
  final TextEditingController _singleValueController = TextEditingController();

  final List<Map<String, dynamic>> _history = [
    {
      'category': 'Body Weight',
      'value': '36 kg',
      'date': '2026-09-11',
      'isAbnormal': false,
    },
    {
      'category': 'Blood Pressure',
      'value': '3/45 mmHg',
      'date': '2026-09-11',
      'isAbnormal': true,
    },
    {
      'category': 'Blood Pressure',
      'value': '253/196 mmHg',
      'date': '2026-09-11',
      'isAbnormal': true,
    }
  ];

  bool _isAbnormal(String category, String val1, [String? val2]) {
    if (category == 'Blood Pressure' && val2 != null) {
      int? sys = int.tryParse(val1);
      int? dia = int.tryParse(val2);
      if (sys != null && dia != null) {
        // Only mark as red if it is HIGH
        if (sys > 120 || dia > 80) {
          return true;
        }
      }
      return false;
    } else if (category == 'Blood Sugar') {
      int? sugar = int.tryParse(val1);
      // Only mark as red if it is HIGH
      if (sugar != null && sugar > 140) return true;
      return false;
    }
    return false;
  }

  void _recordMeasurement() {
    String value = '';
    bool abnormal = false;

    if (_selectedCategory == 'Blood Pressure') {
      if (_systolicController.text.isEmpty || _diastolicController.text.isEmpty) return;
      value = '${_systolicController.text}/${_diastolicController.text} mmHg';
      abnormal = _isAbnormal(_selectedCategory, _systolicController.text, _diastolicController.text);
    } else {
      if (_singleValueController.text.isEmpty) return;
      String unit = _selectedCategory == 'Body Weight' ? 'kg' : 'mg/dL';
      value = '${_singleValueController.text} $unit';
      abnormal = _isAbnormal(_selectedCategory, _singleValueController.text);
    }

    setState(() {
      _history.insert(0, {
        'category': _selectedCategory,
        'value': value,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'isAbnormal': abnormal,
      });
      _systolicController.clear();
      _diastolicController.clear();
      _singleValueController.clear();
    });
  }

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _singleValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF1A65C4);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 24,
              right: 24,
              bottom: 30,
            ),
            decoration: const BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Health Tracker",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Category",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: primaryColor,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  underline: Container(
                    height: 1,
                    color: Colors.white38,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: _categories.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCategory = newValue;
                        _systolicController.clear();
                        _diastolicController.clear();
                        _singleValueController.clear();
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),
                if (_selectedCategory == 'Blood Pressure')
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _systolicController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Systolic',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: TextField(
                          controller: _diastolicController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Diastolic',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  TextField(
                    controller: _singleValueController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: _selectedCategory == 'Body Weight' ? 'Weight (kg)' : 'Blood Sugar (mg/dL)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                    ),
                  ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _recordMeasurement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Record Measurement",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    "History",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _history.isEmpty
                        ? const Center(
                            child: Text(
                              "No records found.",
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _history.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _history[index];
                              final isAbnormal = item['isAbnormal'] as bool;
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FB),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isAbnormal ? const Color(0xFFFFEBEE) : const Color(0xFFE3F2FD),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.show_chart,
                                        color: isAbnormal ? Colors.red : Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['value'],
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isAbnormal ? Colors.red : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item['category'],
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      item['date'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}