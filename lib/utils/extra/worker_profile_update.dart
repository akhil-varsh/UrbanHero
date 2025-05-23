import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:UrbanHero/models/worker_profile.dart';

class WorkerProfileUpdateScreen extends StatefulWidget {
  final String userId;
  final bool isFirstTime;

  const WorkerProfileUpdateScreen({
    super.key,
    required this.userId,
    this.isFirstTime = false,
  });

  @override
  _WorkerProfileUpdateScreenState createState() => _WorkerProfileUpdateScreenState();
}

class _WorkerProfileUpdateScreenState extends State<WorkerProfileUpdateScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _specializationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  
  String _availability = 'Available';
  final List<String> _availabilityOptions = ['Available', 'Busy', 'Unavailable'];
  List<String> _skills = [];
  String _newSkill = '';
  
  File? _profileImage;
  String? _profileImageBase64;
  bool _isLoading = true;
  WorkerProfile? _currentProfile;

  @override
  void initState() {
    super.initState();
    _loadWorkerProfile();
  }

  Future<void> _loadWorkerProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if profile exists
      final profileSnapshot = await _firestore
          .collection('worker_profiles')
          .where('userId', isEqualTo: widget.userId)
          .get();

      if (profileSnapshot.docs.isNotEmpty) {
        // Profile exists, load data
        final profileData = profileSnapshot.docs.first.data();
        _currentProfile = WorkerProfile.fromMap(
            profileData, profileSnapshot.docs.first.id);

        _nameController.text = _currentProfile!.username;
        _phoneController.text = _currentProfile!.phone ?? '';
        _locationController.text = _currentProfile!.location ?? '';
        _specializationController.text = _currentProfile!.specialization;
        _experienceController.text = _currentProfile!.experienceYears.toString();
        _availability = _currentProfile!.availability;
        _skills = List.from(_currentProfile!.skills);
        _profileImageBase64 = _currentProfile!.profileImageBase64;
      } else {
        // No profile yet, try to get basic info from auth
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          _nameController.text = user.displayName ?? '';
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error loading profile: ${e.toString()}");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });

      // Convert to base64 for storage
      final bytes = await _profileImage!.readAsBytes();
      _profileImageBase64 = base64Encode(bytes);
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty || 
        _specializationController.text.isEmpty || 
        _experienceController.text.isEmpty) {
      Fluttertoast.showToast(
          msg: "Please fill all required fields (name, specialization, experience)");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      int experienceYears = int.tryParse(_experienceController.text) ?? 0;
      
      final profileData = {
        'userId': widget.userId,
        'username': _nameController.text,
        'email': FirebaseAuth.instance.currentUser?.email ?? '',
        'phone': _phoneController.text,
        'location': _locationController.text,
        'profileImageBase64': _profileImageBase64,
        'availability': _availability,
        'specialization': _specializationController.text,
        'skills': _skills,
        'experienceYears': experienceYears,
        'isProfileComplete': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (_currentProfile != null) {
        // Update existing profile
        await _firestore
            .collection('worker_profiles')
            .doc(_currentProfile!.id)
            .update(profileData);
      } else {
        // Create new profile
        await _firestore.collection('worker_profiles').add(profileData);
      }

      Fluttertoast.showToast(msg: "Profile updated successfully!");
      
      if (widget.isFirstTime) {
        // Navigate to worker home screen if this is first time setup
        Navigator.of(context).pushReplacementNamed('/worker_home');
      } else {
        Navigator.of(context).pop(true); // Return true to indicate update was successful
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error saving profile: ${e.toString()}");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addSkill() {
    if (_newSkill.isNotEmpty && !_skills.contains(_newSkill)) {
      setState(() {
        _skills.add(_newSkill);
        _newSkill = '';
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      _skills.remove(skill);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFirstTime ? 'Complete Your Profile' : 'Update Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isFirstTime)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        'Please complete your profile before continuing. This information will be used to match you with appropriate tasks.',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  
                  // Profile Image
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!) as ImageProvider
                            : (_profileImageBase64 != null
                                ? MemoryImage(base64Decode(_profileImageBase64!)) as ImageProvider
                                : null),
                        child: (_profileImage == null && _profileImageBase64 == null)
                            ? const Icon(Icons.add_a_photo, size: 40)
                            : null,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Name
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Phone
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Location
                  TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Specialization
                  TextField(
                    controller: _specializationController,
                    decoration: const InputDecoration(
                      labelText: 'Specialization *',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. Plumber, Electrician, Cleaner'
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Experience
                  TextField(
                    controller: _experienceController,
                    decoration: const InputDecoration(
                      labelText: 'Years of Experience *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Availability
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Availability',
                      border: OutlineInputBorder(),
                    ),
                    value: _availability,
                    onChanged: (String? newValue) {
                      setState(() {
                        _availability = newValue!;
                      });
                    },
                    items: _availabilityOptions
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Skills
                  const Text(
                    'Skills',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Add a skill',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            _newSkill = value;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addSkill,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _skills.map((skill) {
                      return Chip(
                        label: Text(skill),
                        onDeleted: () => _removeSkill(skill),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Save Profile',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}