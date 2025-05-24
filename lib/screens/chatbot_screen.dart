// lib/screens/chatbot_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:UrbanHero/models/chat_message.dart'; // Ensure this path is correct

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // IMPORTANT: REPLACE 'YOUR_GEMINI_API_KEY' WITH YOUR ACTUAL API KEY
  final String _apiKey = 'YOUR_GEMINI_API_KEY'; // User has already placed their key here
  final String _apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent'; // Corrected to a valid model

  // System prompt for UrbanHero context
  final String _systemPrompt = '''You are Uero, a helpful assistant for the UrbanHero platform.

Platform Overview:
Urban Hero is a community-driven waste management platform that helps users responsibly dispose of waste and earn rewards. Users can report, track, and submit various types of waste including plastic, paper, metal, e-waste, and general trash. They can choose between using their current GPS location or selecting a location via Google Maps to schedule pickups. Every successful submission earns points, which can be redeemed for rewards such as gift cards or vouchers. A community leaderboard encourages participation by ranking users based on their contribution to sustainable practices.

- Urban Hero helps users report and dispose of waste responsibly.
- Users can earn points by submitting recyclable items.
- Points can be redeemed for rewards like coupons and vouchers.
- A community leaderboard ranks users by points earned.
- Users can select locations for waste pickup via Google Maps.
- Real-time location can be fetched using GPS.
- Waste categories include plastic, metal, paper, e-waste, and general trash.

Please elaborate somewhat on your answers and be a helpful assistant for the UrbanHero platform.
''';

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUserMessage: true, timestamp: DateTime.now()));
      _isLoading = true;
    });

    _controller.clear();

    // Combine system prompt with user message
    final String fullPrompt = '$_systemPrompt\\n\\nUser: $text\\nUero:';

    try {
      final response = await http.post(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': fullPrompt} // Send the combined prompt
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String botResponse = data['candidates'][0]['content']['parts'][0]['text'];
        setState(() {
          _messages.add(ChatMessage(text: botResponse, isUserMessage: false, timestamp: DateTime.now()));
        });
      } else {
        // Handle API error
        String errorMessage = 'Failed to get response from Gemini.';
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            if (errorData['error'] != null && errorData['error']['message'] != null) {
              errorMessage += ' Details: ${errorData['error']['message']}';
            }
          } catch (e) {
            // If parsing error body fails, use the raw body
            errorMessage += ' Raw error: ${response.body}';
          }
        }
         setState(() {
          _messages.add(ChatMessage(text: errorMessage, isUserMessage: false, timestamp: DateTime.now()));
        });
        print('Error: ${response.statusCode}');
        print('Error body: ${response.body}');
      }
    } catch (e) {
      // Handle network or other errors
      setState(() {
        _messages.add(ChatMessage(text: 'Error: ${e.toString()}', isUserMessage: false, timestamp: DateTime.now()));
      });
      print('Error sending message: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text('About Uero'),
          ],
        ),
        content: const Text(
          'Uero is your helpful assistant for the UrbanHero platform. Ask me anything about waste management, earning points, or how to use the platform!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it!', style: TextStyle(color: Theme.of(context).primaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to Uero Chat!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'I\'m here to help you with UrbanHero.\nAsk me about waste management, points,\nor how to use the platform!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSuggestedChip('How do I earn points?', Icons.stars),
              _buildSuggestedChip('What waste types are accepted?', Icons.recycling),
              _buildSuggestedChip('How to schedule pickup?', Icons.schedule),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedChip(String text, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: Theme.of(context).primaryColor),
      label: Text(text, style: TextStyle(color: Theme.of(context).primaryColor)),
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
      onPressed: () => _sendMessage(text),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.smart_toy, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                const Text('Uero is typing', style: TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Ask Uero anything...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: Icon(Icons.message, color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onSubmitted: _sendMessage,
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: () => _sendMessage(_controller.text),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Uero'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),
          if (_isLoading) _buildTypingIndicator(),
          _buildInputArea(),
        ],
      ),
    );
  }
  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: message.isUserMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!message.isUserMessage) ...[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.smart_toy,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                decoration: BoxDecoration(
                  color: message.isUserMessage 
                      ? Theme.of(context).primaryColor
                      : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(message.isUserMessage ? 18 : 4),
                    bottomRight: Radius.circular(message.isUserMessage ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUserMessage ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: message.isUserMessage ? Colors.white70 : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: message.isUserMessage ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (message.isUserMessage) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.grey,
                  size: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
