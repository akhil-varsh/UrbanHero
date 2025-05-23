import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/worker_profile.dart';
import '../../screens/flutter-login.dart';

class Profilew extends StatefulWidget {
  const Profilew({super.key});

  @override
  State<Profilew> createState() => _ProfileState();
}

class _ProfileState extends State<Profilew> {
  // User basic data
  String username = 'User';
  String email = 'Email';
  String role = 'Role';
  String? profileImageBase64;
  bool isLoading = false;
  bool isProfileComplete = false;

  // Worker profile specific fields
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _specializationController = TextEditingController();
  final _experienceController = TextEditingController();
  String _selectedAvailability = 'Available';
  List<String> _selectedSkills = [];
  WorkerProfile? _workerProfile;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // Available skills for selection
  final List<String> _availableSkills = [
    'Waste Collection',
    'Recycling',
    'Hazardous Waste',
    'E-waste',
    'Organic Waste',
    'Cleaning',
    'Maintenance'
  ];

  // Available availability options
  final List<String> _availabilityOptions = [
    'Available',
    'Busy',
    'On Leave',
    'Part-time',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _locationController.dispose();
    _specializationController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      isLoading = true;
    });

    User? user = _auth.currentUser;

    if (user != null) {
      try {
        // Load basic user data
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          setState(() {
            username = userDoc['username'] ?? 'Unknown User';
            email = userDoc['email'] ?? 'Unknown Email';
            role = userDoc['role'] ?? 'Unknown Role';
            profileImageBase64 = userDoc['profileImageBase64'];
          });
        }

        // Check if worker profile exists
        QuerySnapshot profileSnapshot = await _firestore
            .collection('worker_profiles')
            .where('userId', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (profileSnapshot.docs.isNotEmpty) {
          DocumentSnapshot profileDoc = profileSnapshot.docs.first;
          
          // Create worker profile from document
          _workerProfile = WorkerProfile.fromMap(
            profileDoc.data() as Map<String, dynamic>,
            profileDoc.id
          );

          // Set values to controllers
          setState(() {
            isProfileComplete = _workerProfile!.isProfileComplete;
            _phoneController.text = _workerProfile?.phone ?? '';
            _locationController.text = _workerProfile?.location ?? '';
            _specializationController.text = _workerProfile?.specialization ?? '';
            _experienceController.text = _workerProfile?.experienceYears.toString() ?? '';
            _selectedAvailability = _workerProfile?.availability ?? 'Available';
            _selectedSkills = _workerProfile?.skills ?? [];
          });
        }
      } catch (e) {
        debugPrint("Error fetching user data: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _uploadImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() {
        isLoading = true;
      });

      final User? user = _auth.currentUser;
      if (user == null) return;

      // Convert image to base64
      final File imgFile = File(image.path);
      final List<int> imageBytes = await imgFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      // Update Firestore with base64 image
      await _firestore.collection('users').doc(user.uid).update({
        'profileImageBase64': base64Image,
      });

      setState(() {
        profileImageBase64 = base64Image;
      });

      // If worker profile exists, update the profile image there too
      if (_workerProfile != null) {
        await _firestore.collection('worker_profiles').doc(_workerProfile!.id).update({
          'profileImageBase64': base64Image,
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
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
                  _uploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final User? user = _auth.currentUser;
      if (user == null) return;

      // Prepare data for worker profile
      final Map<String, dynamic> profileData = {
        'userId': user.uid,
        'username': username,
        'email': email,
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'profileImageBase64': profileImageBase64,
        'isProfileComplete': true,
        'skills': _selectedSkills,
        'availability': _selectedAvailability,
        'experienceYears': int.tryParse(_experienceController.text) ?? 0,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (_workerProfile != null) {
        // Update existing profile
        await _firestore.collection('worker_profiles').doc(_workerProfile!.id).update(profileData);
      } else {
        // Create new profile
        await _firestore.collection('worker_profiles').add(profileData);
      }

      setState(() {
        isProfileComplete = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildSkillsSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Skills',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableSkills.map((skill) {
            final isSelected = _selectedSkills.contains(skill);
            return FilterChip(
              label: Text(skill),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedSkills.add(skill);
                  } else {
                    _selectedSkills.remove(skill);
                  }
                });
              },
              backgroundColor: Colors.grey[200],
              selectedColor: Colors.blue[100],
              checkmarkColor: Colors.blue,
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Profile'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _showImagePickerModal,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: profileImageBase64 != null
                              ? MemoryImage(base64Decode(profileImageBase64!))
                              : null,
                          child: profileImageBase64 == null
                              ? const Icon(Icons.person, size: 60, color: Colors.grey)
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
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Profile completion status
                  if (!isProfileComplete)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_rounded, color: Colors.amber[800]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Please complete your profile to receive task assignments',
                              style: TextStyle(color: Colors.amber[800]),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Text(
                    'Profile Details',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Basic info (non-editable)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Basic Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: const Icon(Icons.person),
                            title: const Text('Username'),
                            subtitle: Text(username),
                          ),
                          ListTile(
                            leading: const Icon(Icons.email),
                            title: const Text('Email'),
                            subtitle: Text(email),
                          ),
                          ListTile(
                            leading: const Icon(Icons.badge),
                            title: const Text('Role'),
                            subtitle: Text(role),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Professional info (editable)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Professional Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: Icon(Icons.phone),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a phone number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _locationController,
                              decoration: const InputDecoration(
                                labelText: 'Location/Address',
                                prefixIcon: Icon(Icons.location_on),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your location';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _specializationController,
                              decoration: const InputDecoration(
                                labelText: 'Specialization',
                                prefixIcon: Icon(Icons.work),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your specialization';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _experienceController,
                              decoration: const InputDecoration(
                                labelText: 'Years of Experience',
                                prefixIcon: Icon(Icons.timeline),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your years of experience';
                                }
                                if (int.tryParse(value) == null) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Availability',
                                prefixIcon: Icon(Icons.event_available),
                                border: OutlineInputBorder(),
                              ),
                              value: _selectedAvailability,
                              items: _availabilityOptions.map((option) {
                                return DropdownMenuItem(
                                  value: option,
                                  child: Text(option),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedAvailability = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildSkillsSelection(),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                ),
                                child: Text(
                                  isProfileComplete ? 'Update Profile' : 'Complete Profile',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _auth.signOut();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding:
                      const EdgeInsets.symmetric(horizontal: 75, vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
