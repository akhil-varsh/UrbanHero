import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';

import 'cart.dart';

class ChatBot {
  String getResponse(String userQuery) {
    String query = userQuery.toLowerCase();

    if (query.contains('recycle')) {
      return 'To recycle correctly, separate your waste into categories like plastic, paper, metal, and organic.';
    } else if (query.contains('points')) {
      return 'You earn points by uploading images of collected waste. These points can be redeemed for eco-friendly products!';
    } else if (query.contains('upload')) {
      return 'To upload an image, go to the “Upload Waste” section, select a photo, and submit!';
    } else if (query.contains('how to use')) {
      return 'This app helps you collect, report, and recycle waste. You can also track your points and redeem them for rewards.';
    } else if (query.contains("hi")) {
      return 'Hello, Welcome To Urban Hero!';
    } else {
      return 'Sorry, I did not understand. Try asking about recycling or points!';
    }
  }
}

class SecondPage extends StatefulWidget {
  const SecondPage({super.key});

  @override
  _SecondPageState createState() => _SecondPageState();
}

class _SecondPageState extends State<SecondPage> {
  XFile? _selectedImage;
  LocationData? _locationData;
  bool _isChatOpen = false;
  final ChatBot _chatBot = ChatBot();
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [];

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _selectedImage = image;
    });
  }

  Future<void> _captureImageWithCamera() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      } else {
        // Handle the case where the user cancels the camera
        print("No image captured.");
      }
    } catch (e) {
      print("Error accessing camera: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unable to access the camera on this device.")),
      );
    }
  }

  Future<void> _getLocation() async {
    final Location location = Location();
    LocationData locationData = await location.getLocation();
    setState(() {
      _locationData = locationData;
    });
  }

  void _toggleChat() {
    setState(() {
      _isChatOpen = !_isChatOpen;
      if (_messages.isEmpty) {
        _messages.add({
          "sender": "ChatBot",
          "text": _chatBot.getResponse("hello"),
        });
      }
    });
  }

  void _sendMessage(String message) {
    setState(() {
      _messages.add({
        "sender": "You",
        "text": message,
      });
      String response = _chatBot.getResponse(message);
      _messages.add({
        "sender": "ChatBot",
        "text": response,
      });
      _messageController.clear();
    });
  }

  void _trackYourIssues() {
    // Implement tracking functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Tracking your issues...")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text("Urban Hero"),
        backgroundColor: Colors.yellowAccent,
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Cart()),

              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.yellowAccent,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              title: Text('Track Your Issues'),
              onTap: () {
                Navigator.pushNamed(context, '/trackissues');
              },
            ),
            ListTile(
              title: Text('Profile'),
              onTap: () {
                Navigator.pushNamed(context, '/trackissues');
              },
            ),
            // Add more list tiles here for other features
          ],
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Report Waste Issue",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    items: ['Large', 'Medium', 'Small']
                        .map((String value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ))
                        .toList(),
                    onChanged: (value) {},
                    decoration: InputDecoration(
                      labelText: 'Select Waste Volume',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Describe the waste issue in your area',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: Icon(Icons.upload_file),
                          label: Text('Upload Image'),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _captureImageWithCamera,
                          icon: Icon(Icons.camera_alt),
                          label: Text('Capture Image'),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedImage != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.file(
                        File(_selectedImage!.path),
                        height: 100,
                      ),
                    ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _getLocation,
                    icon: Icon(Icons.location_on),
                    label: Text('Get Location'),
                  ),
                  if (_locationData != null)
                    Text(
                      'Location: Lat: ${_locationData!.latitude}, Lng: ${_locationData!.longitude}',
                      style: TextStyle(fontSize: 14),
                    ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Action for submit button
                    },
                    child: Text('Submit'),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: FloatingActionButton(
                onPressed: _toggleChat,
                backgroundColor: Colors.lightGreen,
                child: Icon(Icons.chat),
              ),
            ),
          ),
          if (_isChatOpen)
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: screenWidth * 0.5,
                height: screenHeight * 0.5,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return Container(
                            alignment: message["sender"] == "You"
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: message["sender"] == "You"
                                    ? Colors.blueAccent
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "${message["sender"]}: ${message["text"]}",
                                style: TextStyle(
                                  color: message["sender"] == "You"
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    TextField(
                      controller: _messageController,
                      onSubmitted: _sendMessage,
                      decoration: InputDecoration(
                        labelText: "Type your message",
                        border: OutlineInputBorder(),
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



// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:location/location.dart';
//
// class ChatBot {
//   String getResponse(String userQuery) {
//     String query = userQuery.toLowerCase();
//
//     if (query.contains('recycle')) {
//       return 'To recycle correctly, separate your waste into categories like plastic, paper, metal, and organic.';
//     } else if (query.contains('points')) {
//       return 'You earn points by uploading images of collected waste. These points can be redeemed for eco-friendly products!';
//     } else if (query.contains('upload')) {
//       return 'To upload an image, go to the “Upload Waste” section, select a photo, and submit!';
//     } else if (query.contains('how to use')) {
//       return 'This app helps you collect, report, and recycle waste. You can also track your points and redeem them for rewards.';
//     } else if (query.contains("hi")) {
//       return 'Hello, Welcome To Urban Hero!';
//     } else {
//       return 'Sorry, I did not understand. Try asking about recycling or points!';
//     }
//   }
// }
//
// class SecondPage extends StatefulWidget {
//   const SecondPage({super.key});
//
//   @override
//   _SecondPageState createState() => _SecondPageState();
// }
//
// class _SecondPageState extends State<SecondPage> {
//   XFile? _selectedImage;
//   LocationData? _locationData;
//   bool _isChatOpen = false;
//   final ChatBot _chatBot = ChatBot();
//   final TextEditingController _messageController = TextEditingController();
//   final List<Map<String, String>> _messages = [];
//
//   Future<void> _pickImage() async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? image = await picker.pickImage(source: ImageSource.gallery);
//     setState(() {
//       _selectedImage = image;
//     });
//   }
//
//   Future<void> _captureImageWithCamera() async {
//     final ImagePicker picker = ImagePicker();
//     try {
//       final XFile? image = await picker.pickImage(source: ImageSource.camera);
//       if (image != null) {
//         setState(() {
//           _selectedImage = image;
//         });
//       } else {
//         // Handle the case where the user cancels the camera
//         print("No image captured.");
//       }
//     } catch (e) {
//       print("Error accessing camera: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Unable to access the camera on this device.")),
//       );
//     }
//   }
//
//   Future<void> _getLocation() async {
//     final Location location = Location();
//     LocationData locationData = await location.getLocation();
//     setState(() {
//       _locationData = locationData;
//     });
//   }
//
//   void _toggleChat() {
//     setState(() {
//       _isChatOpen = !_isChatOpen;
//       if (_messages.isEmpty) {
//         _messages.add({
//           "sender": "ChatBot",
//           "text": _chatBot.getResponse("hello"),
//         });
//       }
//     });
//   }
//
//   void _sendMessage(String message) {
//     setState(() {
//       _messages.add({
//         "sender": "You",
//         "text": message,
//       });
//       String response = _chatBot.getResponse(message);
//       _messages.add({
//         "sender": "ChatBot",
//         "text": response,
//       });
//       _messageController.clear();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final screenHeight = MediaQuery.of(context).size.height;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Urban Hero"),
//         backgroundColor: Colors.yellowAccent,
//       ),
//       body: Stack(
//         children: [
//           Center(
//             child: SingleChildScrollView(
//               padding: EdgeInsets.all(16.0),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(
//                     "Report Waste Issue",
//                     style: Theme.of(context).textTheme.headlineSmall,
//                   ),
//                   SizedBox(height: 20),
//                   DropdownButtonFormField<String>(
//                     items: ['Large', 'Medium', 'Small']
//                         .map((String value) => DropdownMenuItem<String>(
//                       value: value,
//                       child: Text(value),
//                     ))
//                         .toList(),
//                     onChanged: (value) {},
//                     decoration: InputDecoration(
//                       labelText: 'Select Waste Volume',
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                   SizedBox(height: 20),
//                   TextField(
//                     maxLines: 3,
//                     decoration: InputDecoration(
//                       labelText: 'Describe the waste issue in your area',
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                   SizedBox(height: 20),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       Expanded(
//                         child: ElevatedButton.icon(
//                           onPressed: _pickImage,
//                           icon: Icon(Icons.upload_file),
//                           label: Text('Upload Image'),
//                         ),
//                       ),
//                       SizedBox(width: 10),
//                       Expanded(
//                         child: ElevatedButton.icon(
//                           onPressed: _captureImageWithCamera,
//                           icon: Icon(Icons.camera_alt),
//                           label: Text('Capture Image'),
//                         ),
//                       ),
//                     ],
//                   ),
//                   if (_selectedImage != null)
//                     Padding(
//                       padding: const EdgeInsets.all(8.0),
//                       child: Image.file(
//                         File(_selectedImage!.path),
//                         height: 100,
//                       ),
//                     ),
//                   SizedBox(height: 20),
//                   ElevatedButton.icon(
//                     onPressed: _getLocation,
//                     icon: Icon(Icons.location_on),
//                     label: Text('Get Location'),
//                   ),
//                   if (_locationData != null)
//                     Text(
//                       'Location: Lat: ${_locationData!.latitude}, Lng: ${_locationData!.longitude}',
//                       style: TextStyle(fontSize: 14),
//                     ),
//                   SizedBox(height: 20),
//                   ElevatedButton(
//                     onPressed: () {
//                       // Action for submit button
//                     },
//                     child: Text('Submit'),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           Align(
//             alignment: Alignment.bottomRight,
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: FloatingActionButton(
//                 onPressed: _toggleChat,
//                 backgroundColor: Colors.lightGreen,
//                 child: Icon(Icons.chat),
//               ),
//             ),
//           ),
//           if (_isChatOpen)
//             Align(
//               alignment: Alignment.bottomRight,
//               child: Container(
//                 width: screenWidth * 0.5,
//                 height: screenHeight * 0.5,
//                 margin: const EdgeInsets.all(16),
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(12),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black12,
//                       blurRadius: 8,
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   children: [
//                     Expanded(
//                       child: ListView.builder(
//                         itemCount: _messages.length,
//                         itemBuilder: (context, index) {
//                           final message = _messages[index];
//                           return Container(
//                             alignment: message["sender"] == "You"
//                                 ? Alignment.centerRight
//                                 : Alignment.centerLeft,
//                             child: Container(
//                               margin: const EdgeInsets.symmetric(vertical: 4),
//                               padding: const EdgeInsets.all(10),
//                               decoration: BoxDecoration(
//                                 color: message["sender"] == "You"
//                                     ? Colors.blueAccent
//                                     : Colors.grey.shade200,
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: Text(
//                                 "${message["sender"]}: ${message["text"]}",
//                                 style: TextStyle(
//                                   color: message["sender"] == "You"
//                                       ? Colors.white
//                                       : Colors.black87,
//                                 ),
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                     TextField(
//                       controller: _messageController,
//                       onSubmitted: _sendMessage,
//                       decoration: InputDecoration(
//                         labelText: "Type your message",
//                         border: OutlineInputBorder(),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
