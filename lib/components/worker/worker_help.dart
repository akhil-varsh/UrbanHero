import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkerHelpScreen extends StatelessWidget {
  const WorkerHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          
          // Support options
          _buildSupportCard(context),
          const SizedBox(height: 24),
          
          // FAQs section
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // FAQ items
          _buildFaqItem(
            'How do I start a task?',
            'From your dashboard, tap on any task with "Assigned" status, then tap the "Start Task" button. This will update the task to "Started" status, and the system will record when you began working on it.',
          ),
          _buildFaqItem(
            'How do I mark a task as complete?',
            'When you finish cleaning an area, tap on the task card and select "Complete". You\'ll be prompted to take a photo of the cleaned area as proof of completion. This photo and timestamp are recorded in the system.',
          ),
          _buildFaqItem(
            'What if I can\'t complete a task?',
            'If you encounter any issues that prevent you from completing a task, please contact your manager immediately. You can use the "Request Support" button at the top of this page.',
          ),
          _buildFaqItem(
            'How are my performance metrics calculated?',
            'Your performance dashboard shows statistics based on tasks completed, response times (how quickly you start tasks after assignment), and ratings from citizens. The system automatically calculates these metrics based on your activity.',
          ),
          _buildFaqItem(
            'How do I submit a daily report?',
            'Tap the "+" button on your dashboard to create a new daily report. Include a summary of your work, hours worked, any challenges faced, and photos of your work areas.',
          ),
          _buildFaqItem(
            'How do I view my schedule?',
            'Your assigned tasks are shown on your dashboard. You can also view them on the map view by tapping "Task Map" from the menu. Future scheduling features will be added soon.',
          ),
          _buildFaqItem(
            'What if an area is inaccessible?',
            'If you cannot access a reported waste area due to safety concerns or other obstacles, document the issue with photos and notes in a daily report and contact your manager.',
          ),
          _buildFaqItem(
            'How do I update my profile information?',
            'Tap your profile icon or open the menu and select "Profile". From there you can edit your information and update your profile picture.',
          ),
          
          const SizedBox(height: 24),
          
          // App guide section
          const Text(
            'App Guide',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildGuideCard(
            'Task Management',
            'Learn how to manage waste cleanup tasks efficiently.',
            Icons.task_alt,
            Colors.blue,
            () {
              _showGuideSheet(context, 'Task Management', [
                'View tasks on your dashboard',
                'Tap on a task to see details',
                'Use "Start Task" to begin working',
                'Take photos of the area before and after cleaning',
                'Mark as completed when done',
                'Tasks with issues can be flagged for support'
              ]);
            },
          ),
          
          _buildGuideCard(
            'Daily Reports',
            'How to submit effective daily reports.',
            Icons.summarize,
            Colors.green,
            () {
              _showGuideSheet(context, 'Daily Reports', [
                'Tap the "+" button on the dashboard',
                'Enter hours worked and area covered',
                'Provide a detailed summary of work completed',
                'Note any challenges or issues faced',
                'Add multiple photos as evidence of work',
                'Submit the report once complete',
                'View past reports in your history'
              ]);
            },
          ),
          
          _buildGuideCard(
            'Using the Map',
            'Navigate and locate tasks efficiently.',
            Icons.map,
            Colors.deepPurple,
            () {
              _showGuideSheet(context, 'Using the Map', [
                'Access the map from the menu',
                'Orange markers = Assigned tasks',
                'Blue markers = Started tasks',
                'Green markers = Completed tasks',
                'Tap a marker to see task details',
                'Use the "Get Directions" button to navigate to the location',
                'Your location is shown with a blue dot'
              ]);
            },
          ),
          
          _buildGuideCard(
            'Performance Stats',
            'Understanding your performance metrics.',
            Icons.bar_chart,
            Colors.amber,
            () {
              _showGuideSheet(context, 'Performance Stats', [
                'Access your stats from the "My Performance" menu',
                'Tasks Completed: Total number of completed tasks',
                'Average Response Time: How quickly you start assigned tasks',
                'User Rating: Feedback score from citizens and managers',
                'Weekly chart shows your task completion patterns',
                'Filter by different time periods to track progress'
              ]);
            },
          ),
          
          const SizedBox(height: 32),
          
          // Version info
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'UrbanHero Worker App',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
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

  Widget _buildSupportCard(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.support_agent,
                    color: Colors.blue,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need Assistance?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Our support team is ready to help',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSupportButton(
                  'Call Support',
                  Icons.call,
                  Colors.green,
                  () => _launchPhone('tel:+911234567890'),
                ),
                _buildSupportButton(
                  'Send Email',
                  Icons.email,
                  Colors.blue,
                  () => _launchEmail('support@urbanhero.com'),
                ),
                _buildSupportButton(
                  'Live Chat',
                  Icons.chat_bubble,
                  Colors.orange,
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Live chat feature coming soon!'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        childrenPadding: const EdgeInsets.all(16).copyWith(top: 0),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          Text(
            answer,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard(String title, String description, IconData icon,
      Color color, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGuideSheet(BuildContext context, String title, List<String> steps) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: steps.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                steps[index],
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _launchPhone(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: encodeQueryParameters(<String, String>{
        'subject': 'UrbanHero Worker Support Request',
      }),
    );
    
    if (await canLaunch(emailLaunchUri.toString())) {
      await launch(emailLaunchUri.toString());
    }
  }
  
  String encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}