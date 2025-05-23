import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class WorkerDailyReportScreen extends StatefulWidget {
  const WorkerDailyReportScreen({super.key});

  @override
  State<WorkerDailyReportScreen> createState() => _WorkerDailyReportScreenState();
}

class _WorkerDailyReportScreenState extends State<WorkerDailyReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  // Form fields
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _challengesController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  
  String _selectedArea = 'Select Area';
  final List<String> _areas = ['Select Area', 'North Zone', 'South Zone', 'East Zone', 'West Zone', 'Central Zone'];
  
  final List<String> _imagesBase64 = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _summaryController.dispose();
    _challengesController.dispose();
    _notesController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedArea == 'Select Area') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an area')),
      );
      return;
    }

    if (_imagesBase64.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String? uid = _auth.currentUser?.uid;
      
      if (uid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get worker info
      DocumentSnapshot workerDoc = await _firestore.collection('users').doc(uid).get();
      String workerName = workerDoc['username'] ?? 'Unknown Worker';

      // Submit report
      await _firestore.collection('worker_reports').add({
        'workerId': uid,
        'workerName': workerName,
        'summary': _summaryController.text,
        'challenges': _challengesController.text,
        'notes': _notesController.text,
        'hoursWorked': double.parse(_hoursController.text),
        'area': _selectedArea,
        'images': _imagesBase64,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });

      setState(() {
        _isLoading = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily report submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      Navigator.pop(context);
    } catch (e) {
      print('Error submitting report: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );

      if (image == null) return;

      final File imgFile = File(image.path);
      final List<int> imageBytes = await imgFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      setState(() {
        _imagesBase64.add(base64Image);
      });
    } catch (e) {
      print('Error adding image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding image: $e')),
      );
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _addImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _addImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeImage(int index) {
    setState(() {
      _imagesBase64.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Report'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date display
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  'Today: ${DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now())}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Hours worked
                    _buildTextField(
                      controller: _hoursController,
                      label: 'Hours Worked',
                      hint: 'Enter number of hours worked',
                      prefixIcon: Icons.access_time,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter hours worked';
                        }
                        try {
                          double hours = double.parse(value);
                          if (hours <= 0 || hours > 24) {
                            return 'Please enter a valid number of hours (1-24)';
                          }
                        } catch (e) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Area dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.location_on),
                          labelText: 'Area Worked',
                        ),
                        value: _selectedArea,
                        icon: const Icon(Icons.arrow_drop_down),
                        isExpanded: true,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedArea = newValue!;
                          });
                        },
                        items: _areas.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Summary
                    _buildTextField(
                      controller: _summaryController,
                      label: 'Summary of Work Done',
                      hint: 'Briefly describe the tasks completed today',
                      prefixIcon: Icons.summarize,
                      minLines: 3,
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a summary of work done';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Challenges
                    _buildTextField(
                      controller: _challengesController,
                      label: 'Challenges Faced',
                      hint: 'Describe any challenges or issues encountered',
                      prefixIcon: Icons.warning,
                      minLines: 2,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),

                    // Additional notes
                    _buildTextField(
                      controller: _notesController,
                      label: 'Additional Notes',
                      hint: 'Any other comments or observations',
                      prefixIcon: Icons.note,
                      minLines: 2,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),

                    // Images section
                    const Text(
                      'Photos from Today',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please add photos of work areas, completed tasks, or any issues.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Image grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _imagesBase64.length + 1, // +1 for add button
                      itemBuilder: (context, index) {
                        if (index == _imagesBase64.length) {
                          // Add button
                          return GestureDetector(
                            onTap: _showImagePickerModal,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.add_a_photo,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          );
                        } else {
                          // Existing image
                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: Image.memory(
                                    base64Decode(_imagesBase64[index]),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 32),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Submit Daily Report',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    int minLines = 1,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      validator: validator,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
    );
  }
}