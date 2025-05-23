import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/worker_profile.dart';

class WorkerProfileScreen extends StatefulWidget {
  final bool isFirstLogin;

  const WorkerProfileScreen({
    super.key, 
    this.isFirstLogin = false,
  });

  @override
  _WorkerProfileScreenState createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _profileImageBase64;
  WorkerProfile? _currentProfile;
  
  // Form fields
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  String _availability = 'Available';
  String _specialization = 'General';
  final List<String> _skills = [];
  int _experienceYears = 0;
  
  // Available options
  final List<String> _availabilityOptions = ['Available', 'Busy', 'Unavailable'];
  final List<String> _specializationOptions = [
    'General',
    'Recycling',
    'Hazardous Waste',
    'Organic Waste',
    'Electronic Waste',
    'Construction Debris',
    'Medical Waste',
    'Other'
  ];
  final List<String> _skillOptions = [
    'Waste Segregation',
    'Recycling',
    'Hazardous Material Handling',
    'Heavy Lifting',
    'Equipment Operation',
    'Composting',
    'Waste Disposal',
    'Chemical Treatment',
    'Electronic Recycling',
    'Data Destruction',
    'Transport & Logistics',
    'Waste Reduction Consultation',
  ];

  @override
  void initState() {
    super.initState();
    _loadWorkerProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkerProfile() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        Fluttertoast.showToast(msg: 'User not authenticated');
        Navigator.of(context).pop();
        return;
      }
      
      // Initialize with basic user info
      _emailController.text = user.email ?? '';
      _usernameController.text = user.displayName ?? '';
      
      // Check if a profile already exists
      final profileSnapshot = await _firestore
          .collection('worker_profiles')
          .where('userId', isEqualTo: user.uid)
          .get();
          
      if (profileSnapshot.docs.isNotEmpty) {
        // Profile exists, load it
        final profileDoc = profileSnapshot.docs.first;
        final profileData = profileDoc.data();
        
        _currentProfile = WorkerProfile.fromMap(profileData, profileDoc.id);
        
        // Fill form fields with existing data
        _usernameController.text = _currentProfile!.username;
        _emailController.text = _currentProfile!.email;
        _phoneController.text = _currentProfile!.phone ?? '';
        _locationController.text = _currentProfile!.location ?? '';
        _profileImageBase64 = _currentProfile!.profileImageBase64;
        _availability = _currentProfile!.availability;
        _specialization = _currentProfile!.specialization;
        _experienceYears = _currentProfile!.experienceYears;
        
        // Load skills
        setState(() {
          _skills.clear();
          _skills.addAll(_currentProfile!.skills);
        });
      } else {
        // No profile yet, keep default values
        _profileImageBase64 = null;
        _currentProfile = null;
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading worker profile: $e');
      Fluttertoast.showToast(msg: 'Failed to load profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 85,
      );
      
      if (image != null) {
        final File imageFile = File(image.path);
        final bytes = await imageFile.readAsBytes();
        setState(() {
          _profileImageBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      Fluttertoast.showToast(msg: 'Failed to pick image');
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        Fluttertoast.showToast(msg: 'User not authenticated');
        setState(() {
          _isSaving = false;
        });
        return;
      }
      
      // Prepare profile data
      final Map<String, dynamic> profileData = {
        'userId': user.uid,
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'profileImageBase64': _profileImageBase64,
        'availability': _availability,
        'specialization': _specialization,
        'skills': _skills,
        'experienceYears': _experienceYears,
        'rating': _currentProfile?.rating ?? 0.0,
        'isProfileComplete': true, // Mark as complete since user is actively updating
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
        await _firestore
            .collection('worker_profiles')
            .add(profileData);
      }
      
      // Also update display name in Auth if needed
      if (user.displayName != _usernameController.text.trim()) {
        await user.updateDisplayName(_usernameController.text.trim());
      }
      
      setState(() {
        _isSaving = false;
      });
      
      Fluttertoast.showToast(
        msg: 'Profile updated successfully',
        backgroundColor: Colors.green,
      );
      
      if (widget.isFirstLogin) {
        // Navigate to worker home after first login
        Navigator.of(context).pushReplacementNamed('/worker/home');
      } else {
        // Just go back to previous screen
        Navigator.of(context).pop(true); // Return true to indicate profile was updated
      }
    } catch (e) {
      print('Error saving worker profile: $e');
      Fluttertoast.showToast(
        msg: 'Failed to save profile: $e',
        backgroundColor: Colors.red,
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _toggleSkill(String skill) {
    setState(() {
      if (_skills.contains(skill)) {
        _skills.remove(skill);
      } else {
        _skills.add(skill);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFirstLogin ? 'Complete Your Profile' : 'Edit Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.isFirstLogin)
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Welcome to Urban Hero!',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Please complete your profile to start receiving tasks. '
                                'This information helps managers assign appropriate tasks based on your skills and availability.',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      
                      // Profile Image Section
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage: _profileImageBase64 != null
                                        ? MemoryImage(base64Decode(_profileImageBase64!))
                                        : null,
                                    child: _profileImageBase64 == null
                                        ? const Icon(
                                            Icons.person,
                                            size: 50,
                                            color: Colors.grey,
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap to change profile photo',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Basic Information
                      const Text(
                        'Basic Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                        enabled: false, // Email is from auth, can't be changed here
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location/Area',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                          hintText: 'e.g., Downtown, North District',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your work location/area';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Professional Details
                      const Text(
                        'Professional Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Availability Dropdown
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Availability',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        value: _availability,
                        items: _availabilityOptions.map((String option) {
                          return DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _availability = newValue;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Specialization Dropdown
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Specialization',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.work),
                        ),
                        value: _specialization,
                        items: _specializationOptions.map((String option) {
                          return DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _specialization = newValue;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Experience Years
                      Row(
                        children: [
                          const Text(
                            'Experience (Years): ',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Slider(
                              value: _experienceYears.toDouble(),
                              min: 0,
                              max: 20,
                              divisions: 20,
                              label: _experienceYears.toString(),
                              onChanged: (double value) {
                                setState(() {
                                  _experienceYears = value.toInt();
                                });
                              },
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '$_experienceYears years',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Skills Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Skills',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(Select all that apply)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Selected skills
                          if (_skills.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _skills.map((skill) => Chip(
                                label: Text(skill),
                                onDeleted: () => _toggleSkill(skill),
                                backgroundColor: Colors.green.shade100,
                                deleteIconColor: Colors.green.shade800,
                              )).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          // Available skills
                          const Text(
                            'Available Skills:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _skillOptions
                                .where((skill) => !_skills.contains(skill))
                                .map((skill) => ActionChip(
                                  label: Text(skill),
                                  onPressed: () => _toggleSkill(skill),
                                  backgroundColor: Colors.grey.shade100,
                                )).toList(),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: _isSaving
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Save Profile',
                                  style: TextStyle(fontSize: 18),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Cancel Button
                      if (!widget.isFirstLogin)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}