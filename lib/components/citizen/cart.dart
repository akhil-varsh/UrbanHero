import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:UrbanHero/screens/citizen/select_location_screen.dart'; // Added import

class Cart extends StatefulWidget {
  const Cart({super.key});

  @override
  _CartState createState() => _CartState();
}

class _CartState extends State<Cart> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int userCredits = 0;
  Stream<DocumentSnapshot>? _creditsStream;

  @override
  void initState() {
    super.initState();
    _initializeCreditsStream();
    _initializeReportListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Initialize the credits stream to get real-time updates
  void _initializeCreditsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // First, ensure the user document exists with a credits field
    _firestore.collection('users').doc(currentUser.uid).get().then((docSnapshot) {
      if (!docSnapshot.exists) {
        // Create user document if it doesn't exist
        _firestore.collection('users').doc(currentUser.uid).set({
          'credits': 0,
          'email': currentUser.email,
          'role': 'user', // Default role
        });
      } else if (docSnapshot.data() != null && !docSnapshot.data()!.containsKey('credits')) {
        // Add credits field if it doesn't exist
        _firestore.collection('users').doc(currentUser.uid).update({
          'credits': 0,
        });
      }

      // Now set up the stream
      _creditsStream = _firestore.collection('users').doc(currentUser.uid).snapshots();

      // Listen to the stream
      _creditsStream!.listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final userData = snapshot.data() as Map<String, dynamic>;
          setState(() {
            userCredits = userData['credits'] ?? 0;
          });
        }
      }, onError: (error) {
        print("Error fetching credits: $error");
      });
    }).catchError((error) {
      print("Error initializing user document: $error");
    });
  }

  /// Set up listeners for different report events
  void _initializeReportListeners() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Listen for newly created reports
    _listenForNewReports(currentUser.uid);

    // Listen for completed reports - note lowercase 'c' in "completed"
    _listenForCompletedReports(currentUser.uid);
  }

  /// Listen for new reports and award initial points
  void _listenForNewReports(String userId) {
    _firestore
        .collection('waste_reports')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Safely access nested properties with null checks
        final bool pointsAwarded = data['initialPointsAwarded'] == true;
        if (!pointsAwarded) {
          _awardInitialPoints(doc.id, userId);
        }
      }
    }, onError: (error) {
      print("Error listening for new reports: $error");
    });
  }

  /// Listen for completed reports and award completion points
  void _listenForCompletedReports(String userId) {
    _firestore
        .collection('waste_reports')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Note the lowercase 'c' in "completed" and proper null-safe access
        final String status = data['status'] as String? ?? '';
        final bool pointsAwarded = data['completionPointsAwarded'] == true;

        if (status == 'completed' && !pointsAwarded) {
          _awardCompletionPoints(doc.id, userId);
        }
      }
    }, onError: (error) {
      print("Error listening for completed reports: $error");
    });
  }

  /// Award initial points for new report submission
  Future<void> _awardInitialPoints(String reportId, String userId) async {
    try {
      // Use a transaction to ensure data consistency
      await _firestore.runTransaction((transaction) async {
        // Get the latest user document
        DocumentReference userRef = _firestore.collection('users').doc(userId);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        // Get the report reference
        DocumentReference reportRef = _firestore.collection('waste_reports').doc(reportId);

        // Calculate new credits value
        int currentCredits = 0;
        if (userSnapshot.exists && userSnapshot.data() != null) {
          final userData = userSnapshot.data() as Map<String, dynamic>;
          currentCredits = userData['credits'] as int? ?? 0;
        }

        int newCredits = currentCredits + 10;

        // Update the user's credits
        transaction.update(userRef, {'credits': newCredits});

        // Mark report as awarded
        transaction.update(reportRef, {'initialPointsAwarded': true});
      });

      print("✅ 10 points awarded for new report: $reportId");
    } catch (e) {
      print("Error awarding initial points: $e");
    }
  }

  /// Award completion points for completed reports
  Future<void> _awardCompletionPoints(String reportId, String userId) async {
    try {
      // Use a transaction to ensure data consistency
      await _firestore.runTransaction((transaction) async {
        // Get the latest user document
        DocumentReference userRef = _firestore.collection('users').doc(userId);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        // Get the report reference
        DocumentReference reportRef = _firestore.collection('waste_reports').doc(reportId);

        // Calculate new credits value
        int currentCredits = 0;
        if (userSnapshot.exists && userSnapshot.data() != null) {
          final userData = userSnapshot.data() as Map<String, dynamic>;
          currentCredits = userData['credits'] as int? ?? 0;
        }

        int newCredits = currentCredits + 20;

        // Update the user's credits
        transaction.update(userRef, {'credits': newCredits});

        // Mark report as awarded completion points
        transaction.update(reportRef, {'completionPointsAwarded': true});
      });

      print("✅ 20 points awarded for completed report: $reportId");
    } catch (e) {
      print("Error awarding completion points: $e");
    }
  }

  /// Deduct credits when user buys an item
  Future<void> buyProduct(Product product) async { // Changed to accept Product object
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You need to be logged in to make a purchase.")),
      );
      return;
    }

    // Show dialog to collect address, phone, and location, and then perform purchase
    await _showOrderDetailsDialog(context, product);
  }

  Future<void> _showOrderDetailsDialog(BuildContext context, Product product) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to make a purchase.')),
      );
      return;
    }

    // Check if user has enough credits
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    final userCredits = userDoc.data()?['credits'] ?? 0;

    if (userCredits < product.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You do not have enough credits to buy ${product.name}.')),
      );
      return;
    }

    final TextEditingController addressController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    Position? fetchedPosition; // To store fetched GPS location
    final _formKey = GlobalKey<FormState>(); // Form key for validation

    // Pre-fill username and email if available
    final String userName = currentUser.displayName ?? 'N/A';
    final String userEmail = currentUser.email ?? 'N/A';

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext dialogContext) {
        return StatefulBuilder( // Use StatefulBuilder to update dialog state
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Confirm Purchase: ${product.name}'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: ListBody(
                    children: <Widget>[
                      Text('Product: ${product.name}'),
                      Text('Price: ${product.price} Pts'),
                      const SizedBox(height: 10),
                      Text('Username: $userName'),
                      Text('Email: $userEmail'),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: 'Delivery Address',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your delivery address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          // Basic phone number validation (optional)
                          if (!RegExp(r'^\+?[0-9]{10,}$').hasMatch(value)) {
                            return 'Please enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      if (fetchedPosition != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Selected Location: Lat: ${fetchedPosition!.latitude.toStringAsFixed(5)}, Lng: ${fetchedPosition!.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.my_location),
                        label: const Text('Get Current Location'),
                        onPressed: () async {
                          bool serviceEnabled;
                          LocationPermission permission;

                          serviceEnabled = await Geolocator.isLocationServiceEnabled();
                          if (!serviceEnabled) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(
                                content: Text(
                                    'Location services are disabled. Please enable the services')));
                            return;
                          }

                          permission = await Geolocator.checkPermission();
                          if (permission == LocationPermission.denied) {
                            permission = await Geolocator.requestPermission();
                            if (permission == LocationPermission.denied) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(content: Text('Location permissions are denied')));
                              return;
                            }
                          }

                          if (permission == LocationPermission.deniedForever) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(
                                content: Text(
                                    'Location permissions are permanently denied, we cannot request permissions.')));
                            return;
                          }
                          try {
                            Position position = await Geolocator.getCurrentPosition(
                                desiredAccuracy: LocationAccuracy.high);
                            setStateDialog(() { // Update dialog state
                              fetchedPosition = position;
                            });
                          } catch (e) {
                             ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(content: Text('Failed to get location: $e')));
                          }
                        },
                      ),
                      ElevatedButton.icon( // "Select on Map" button
                        icon: const Icon(Icons.map),
                        label: const Text('Select on Map'),
                        onPressed: () async {
                          // Navigate to map screen and get result
                          final LatLng? selectedLocation = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SelectLocationScreen(
                                initialPosition: fetchedPosition != null
                                    ? LatLng(fetchedPosition!.latitude, fetchedPosition!.longitude)
                                    : const LatLng(0, 0), // Default or last known
                              ),
                            ),
                          );

                          if (selectedLocation != null) {
                            setStateDialog(() {
                              fetchedPosition = Position(
                                latitude: selectedLocation.latitude,
                                longitude: selectedLocation.longitude,
                                timestamp: DateTime.now(),
                                accuracy: 0.0, // Accuracy is not directly from map selection
                                altitude: 0.0,
                                altitudeAccuracy: 0.0,
                                heading: 0.0,
                                headingAccuracy: 0.0,
                                speed: 0.0,
                                speedAccuracy: 0.0,
                              );
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Confirm Purchase'),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) { // Validate form
                      if (fetchedPosition == null) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('Please select a location.')),
                        );
                        return;
                      }
                      // Proceed with purchase
                      Navigator.of(dialogContext).pop(); // Close dialog first
                      // Call _performPurchase with all details including the product itself
                      await _performPurchase(product, currentUser.uid, userCredits, addressController.text, phoneController.text, fetchedPosition!);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performPurchase(Product product, String userId, int currentCredits, String address, String phone, Position location) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    if (currentCredits < product.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Not enough points to buy ${product.name}!")),
      );
      return;
    }

    try {
      bool success = await _firestore.runTransaction<bool>((transaction) async {
        DocumentReference userRef = _firestore.collection('users').doc(userId);
        DocumentSnapshot freshUserSnapshot = await transaction.get(userRef);
        final freshUserData = freshUserSnapshot.data() as Map<String, dynamic>; // Ensure data is Map
        int freshCurrentCredits = (freshUserData['credits'] ?? 0) as int; // Cast to int

        if (freshCurrentCredits < product.price) {
          return false; 
        }

        int newCredits = freshCurrentCredits - product.price; // price is int, so this is fine
        transaction.update(userRef, {'credits': newCredits});

        DocumentReference purchaseRef = _firestore.collection('purchases').doc();
        transaction.set(purchaseRef, {
          'userId': userId,
          'userName': currentUser.displayName ?? 'N/A',
          'userEmail': currentUser.email ?? 'N/A',
          'userAddress': address,
          'userPhone': phone,
          'userLocation': GeoPoint(location.latitude, location.longitude),
          'productName': product.name,
          'productPrice': product.price,
          'timestamp': FieldValue.serverTimestamp(),
          'orderStatus': 'Pending', 
        });
        return true;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Successfully purchased ${product.name}!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Not enough points to buy ${product.name} or error during transaction!")),
        );
      }
    } catch (e) {
      print("Error performing purchase: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error completing purchase for ${product.name}. Please try again.")),
      );
    }
  }

  final List<Product> products = [
    Product(
      name: 'Plant',
      price: 200,
      description: 'A beautiful indoor plant to brighten up your space.',
      rating: 4.5,
      imageUrl:
      'https://cdn.pixabay.com/photo/2014/12/11/11/14/blumenstock-564132_960_720.jpg',
    ),
    Product(
      name: 'Glass',
      price: 50,
      description: 'A high-quality glass for everyday use.',
      rating: 4.0,
      imageUrl:
      'https://media.istockphoto.com/id/467521964/photo/isolated-shot-of-disposable-coffee-cup-on-white-background.jpg?s=2048x2048&w=is&k=20&c=CpgJrxWRGtA7ID1IBqAv21o6GTAa1EJOmA2v39rgMq0=',
    ),
    Product(
      name: 'Paper',
      price: 25,
      description: 'Recycled paper for all your writing needs.',
      rating: 4.8,
      imageUrl:
      'https://cdn.pixabay.com/photo/2024/01/15/20/51/plate-8510868_1280.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              "Cart",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.white),
                const SizedBox(width: 8.0),
                Text(
                  "$userCredits Pts",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.green,
        elevation: 5,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // Number of columns
            crossAxisSpacing: 12.0, // Horizontal space between cards
            mainAxisSpacing: 12.0, // Vertical space between cards
            childAspectRatio: 0.65, // Aspect ratio of the cards (width / height) - adjust as needed
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              // Removed margin here as GridView.builder handles spacing
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column( // Changed to Column for vertical layout within the card
                  crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children horizontally
                  children: [
                    // Product Image
                    Expanded( // Allow image to take available vertical space
                      flex: 3, // Adjust flex factor as needed
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover, // Cover ensures the image fills the space
                          width: double.infinity, // Take full width of the card
                        ),
                      ),
                    ),
                    const SizedBox(height: 8), // Spacing
                    // Product Details
                    Expanded( // Allow text details to take available space
                      flex: 2, // Adjust flex factor as needed
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Distribute space
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 16, // Adjusted for smaller card
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            product.description,
                            style: TextStyle(
                              fontSize: 12, // Adjusted for smaller card
                              color: Colors.grey[700],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "${product.price} Pts",
                            style: const TextStyle(
                              fontSize: 14, // Adjusted
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Buy Now Button
                    ElevatedButton(
                      onPressed: () => buyProduct(product), // Pass the whole product object
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8), // Adjusted padding
                        elevation: 3,
                      ),
                      child: const Text(
                        "Buy",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold), // Adjusted
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Product Model - Moved to top level or its own file if preferred.
class Product {
  final String name;
  final int price;
  final String description;
  final double rating;
  final String imageUrl;

  Product({
    required this.name,
    required this.price,
    required this.description,
    required this.rating,
    required this.imageUrl,
  });
}