import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; // <-- THE REAL AI BRAIN!

class CustomerChatbotTab extends StatefulWidget {
  const CustomerChatbotTab({super.key});

  @override
  State<CustomerChatbotTab> createState() => _CustomerChatbotTabState();
}

class _CustomerChatbotTabState extends State<CustomerChatbotTab> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [
    {
      'sender': 'ai',
      'text': 'Hi! I am your Culinae AI Chef 🧑‍🍳\nTell me what you are craving, and I will figure out the recipe and find the closest stores with the ingredients!'
    }
  ];

  bool _isTyping = false;

  static const Color culinaeBrown = Color(0xFF4A1F1F);
  static const Color culinaeCream = Color(0xFFFFF3E3);

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    await _analyzeWithGeminiAndSearch(text);
  }

  // --- 🤖 THE GEMINI AI ENGINE ---
  Future<void> _analyzeWithGeminiAndSearch(String userQuery) async {
    // ⚠️ TODO: For industry standard security, move this key to a .env file before launching!
    const apiKey = 'AIzaSyBr48QiS3hoVFUvgXJWF1xGJm8BaBt1Nv4';

    if (apiKey == 'AIzaSyBr48QiS3hoVFUvgXJWF1xGJm8BaBt1Nv4') {
      _addAiMessage("Please put your Gemini API Key in the code first!");
      return;
    }

    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

    // This is "Prompt Engineering". We are giving the AI strict instructions on how to reply!
    final prompt = '''
      You are a helpful AI Chef for a food delivery app.
      The user says: "$userQuery"
      
      Identify the dish they want to make. 
      Return EXACTLY two lines. Do not use markdown, bolding, or bullet points.
      Line 1: A friendly, short sentence acknowledging the dish.
      Line 2: A comma-separated list of 3 to 6 main raw ingredients needed (e.g., Tomato, Cheese, Pasta, Basil).
      
      If the user is not asking about food, return:
      Line 1: I am your AI Chef, I can only help you cook and find food!
      Line 2: none
    ''';

    List<String> requiredIngredients = [];
    String aiChatResponse = "";

    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      final rawText = response.text?.trim() ?? "";

      // Split the AI's response into the Chat Text and the Data Array
      final lines = rawText.split('\n').where((line) => line.trim().isNotEmpty).toList();

      if (lines.isNotEmpty) {
        aiChatResponse = lines[0]; // Line 1: The friendly message

        if (lines.length > 1 && lines[1].toLowerCase() != 'none') {
          // Line 2: The ingredients! Split by comma and clean up spaces.
          requiredIngredients = lines[1].split(',').map((e) => e.trim().toLowerCase()).toList();
        }
      }

    } catch (e) {
      debugPrint("Gemini API Error: $e");
      _addAiMessage("My AI brain is a little disconnected right now. Try again in a moment!");
      return;
    }

    // Add the AI's conversational response to the chat
    setState(() => _messages.add({'sender': 'ai', 'text': aiChatResponse}));
    _scrollToBottom();

    if (requiredIngredients.isEmpty) {
      setState(() => _isTyping = false);
      return; // Stop here if it wasn't a food question
    }

    // --- GPS & FIREBASE SEARCH ENGINE ---
    Position? currentPos;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
          currentPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        }
      }
    } catch (e) {
      debugPrint("Location error: $e");
    }

    if (currentPos == null) {
      _addAiMessage("I know the ingredients, but I can't access your GPS to find nearby stores!");
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'owner').get();
      List<Map<String, dynamic>> recommendedStores = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final GeoPoint? storeGeo = data['storeLocation'] as GeoPoint?;
        final List<dynamic>? menu = data['menu'];

        if (storeGeo != null && menu != null) {
          List<String> foundIngredients = [];

          for (var item in menu) {
            final String itemName = (item['name'] ?? '').toString().toLowerCase();
            for (var req in requiredIngredients) {
              if (itemName.contains(req) && !foundIngredients.contains(req)) {
                foundIngredients.add(req); // Match found!
              }
            }
          }

          if (foundIngredients.isNotEmpty) {
            double distanceInMeters = Geolocator.distanceBetween(
              currentPos.latitude, currentPos.longitude,
              storeGeo.latitude, storeGeo.longitude,
            );
            recommendedStores.add({
              'storeName': data['storeName'] ?? 'A Store',
              'distance': distanceInMeters / 1000, // Convert to km
              'found': foundIngredients,
            });
          }
        }
      }

      // --- Sort & Output Results ---
      if (recommendedStores.isEmpty) {
        _addAiMessage("I couldn't find any nearby stores selling those specific ingredients right now. 😔");
      } else {
        recommendedStores.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

        String finalMessage = "Here are the best nearby options:\n\n";
        for (var store in recommendedStores) {
          finalMessage += "🏪 **${store['storeName']}** (${store['distance'].toStringAsFixed(1)} km away)\n";
          // Capitalize the ingredients for display
          final List<String> displayIngredients = (store['found'] as List<String>).map((e) => e[0].toUpperCase() + e.substring(1)).toList();
          finalMessage += "Has: ${displayIngredients.join(', ')}\n\n";
        }
        _addAiMessage(finalMessage);
      }
    } catch (e) {
      _addAiMessage("Oops! I had trouble connecting to the store databases.");
    }
  }

  void _addAiMessage(String text) {
    setState(() {
      _messages.add({'sender': 'ai', 'text': text});
      _isTyping = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: culinaeCream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.smart_toy, color: culinaeBrown),
            SizedBox(width: 8),
            Text('Culinae AI', style: TextStyle(color: culinaeBrown, fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isAi = msg['sender'] == 'ai';

                return Align(
                  alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isAi ? Colors.white : culinaeBrown,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isAi ? const Radius.circular(4) : const Radius.circular(16),
                        bottomRight: isAi ? const Radius.circular(16) : const Radius.circular(4),
                      ),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: Text(
                      msg['text'],
                      style: TextStyle(color: isAi ? Colors.black87 : Colors.white, fontSize: 15),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isTyping)
            const Padding(
              padding: EdgeInsets.only(left: 24, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('AI Chef is thinking...', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              ),
            ),

          // --- Input Area ---
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))]),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Ask for a recipe...',
                        filled: true,
                        fillColor: culinaeCream,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(color: culinaeBrown, shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}