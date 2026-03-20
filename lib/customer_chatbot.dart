import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

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
      'text': 'Hi! I am your Culinae AI Chef 🧑‍🍳\nAsk me for a recipe, search for a specific food like "Ice Cream", or ask me where a specific store is located!'
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

  // --- 🤖 THE INTENT-DRIVEN AI ENGINE ---
  Future<void> _analyzeWithGeminiAndSearch(String userQuery) async {
    const apiKey = 'AIzaSyBr48QiS3hoVFUvgXJWF1xGJm8BaBt1Nv4';
    final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

    // NEW: We are teaching the AI to categorize the user's intent!
    final prompt = '''
      You are an AI Assistant for a food delivery app.
      The user says: "$userQuery"
      
      Categorize the request into one of three types:
      1. RECIPE (The user wants to cook something)
      2. ITEM_SEARCH (The user is looking to buy a specific ready-made food, e.g., "ice cream", "pizza")
      3. STORE_LOCATION (The user is asking where a specific store is located)
      4. OTHER (Not related to food or stores)
      
      Return EXACTLY three lines. Do not use markdown.
      Line 1: A friendly, short sentence acknowledging the request.
      Line 2: The category (RECIPE, ITEM_SEARCH, STORE_LOCATION, or OTHER).
      Line 3: 
      - If RECIPE: Comma-separated list of raw ingredients needed.
      - If ITEM_SEARCH: Comma-separated list of the main food keywords.
      - If STORE_LOCATION: The exact name of the store they are asking about.
      - If OTHER: none
    ''';

    String aiChatResponse = "";
    String intent = "";
    List<String> keywords = [];

    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      final rawText = response.text?.trim() ?? "";

      final lines = rawText.split('\n').where((line) => line.trim().isNotEmpty).toList();

      if (lines.length >= 2) {
        aiChatResponse = lines[0];
        intent = lines[1].trim().toUpperCase();

        if (lines.length >= 3 && lines[2].toLowerCase() != 'none') {
          keywords = lines[2].split(',').map((e) => e.trim().toLowerCase()).toList();
        }
      }
    } catch (e) {
      debugPrint("Gemini API Error: $e");
      _addAiMessage("My AI brain is a little disconnected right now. Try again in a moment!");
      return;
    }

    // Immediately show the AI's conversational response
    setState(() => _messages.add({'sender': 'ai', 'text': aiChatResponse}));
    _scrollToBottom();

    if (intent == 'OTHER' || keywords.isEmpty) {
      setState(() => _isTyping = false);
      return;
    }

    // --- 📍 GPS LOCATION FETCH ---
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
      _addAiMessage("I know what you are looking for, but I can't access your GPS to find it nearby!");
      return;
    }

    // ==========================================================
    // 🧠 DYNAMIC FIREBASE SEARCHING BASED ON INTENT
    // ==========================================================

    try {
      // --------------------------------------------------------
      // INTENT: STORE LOCATION (Find a specific store by name)
      // --------------------------------------------------------
      if (intent == 'STORE_LOCATION') {
        final storeNameToFind = keywords.first; // e.g., "burger king"
        final userSnapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'owner').get();

        bool storeFound = false;

        for (var doc in userSnapshot.docs) {
          final data = doc.data();
          final String dbStoreName = (data['storeName'] ?? '').toString().toLowerCase();

          if (dbStoreName.contains(storeNameToFind)) {
            final GeoPoint? storeGeo = data['storeLocation'] as GeoPoint?;
            if (storeGeo != null) {
              double distanceInKm = Geolocator.distanceBetween(
                currentPos.latitude, currentPos.longitude,
                storeGeo.latitude, storeGeo.longitude,
              ) / 1000;

              _addAiMessage("📍 **${data['storeName']}** is located ${distanceInKm.toStringAsFixed(1)} km away from you!");
              storeFound = true;
            }
          }
        }

        if (!storeFound) {
          _addAiMessage("I couldn't find a store named '${keywords.first}' on the map. 😔");
        }
      }

      // --------------------------------------------------------
      // INTENT: RECIPE or ITEM SEARCH (Scan Posts for Food)
      // --------------------------------------------------------
      else if (intent == 'RECIPE' || intent == 'ITEM_SEARCH') {
        final postsSnapshot = await FirebaseFirestore.instance.collection('posts').get();

        Map<String, List<String>> storeFoundItems = {};
        Map<String, String> storeNames = {};

        for (var doc in postsSnapshot.docs) {
          final data = doc.data();
          final String caption = (data['caption'] ?? '').toString().toLowerCase();
          final List<String> tags = List<String>.from(data['tags'] ?? []).map((e) => e.toLowerCase()).toList();
          final String ownerId = data['ownerId'] ?? '';
          final String storeName = data['storeName'] ?? 'Unknown Store';

          if (ownerId.isEmpty) continue;

          storeNames[ownerId] = storeName;
          if (!storeFoundItems.containsKey(ownerId)) storeFoundItems[ownerId] = [];

          for (var req in keywords) {
            if ((caption.contains(req) || tags.contains(req)) && !storeFoundItems[ownerId]!.contains(req)) {
              storeFoundItems[ownerId]!.add(req);
            }
          }
        }

        storeFoundItems.removeWhere((key, value) => value.isEmpty);

        List<Map<String, dynamic>> recommendedStores = [];

        for (String ownerId in storeFoundItems.keys) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
          if (userDoc.exists) {
            final storeGeo = userDoc.data()?['storeLocation'] as GeoPoint?;
            final storeType = userDoc.data()?['storeType'] ?? 'Store';

            if (storeGeo != null) {
              double distanceInMeters = Geolocator.distanceBetween(
                currentPos.latitude, currentPos.longitude,
                storeGeo.latitude, storeGeo.longitude,
              );
              recommendedStores.add({
                'storeName': storeNames[ownerId],
                'storeType': storeType,
                'distance': distanceInMeters / 1000,
                'found': storeFoundItems[ownerId],
              });
            }
          }
        }

        if (recommendedStores.isEmpty) {
          _addAiMessage("I couldn't find any nearby stores mentioning those items right now. 😔");
        } else {
          recommendedStores.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

          String finalMessage = "Here are the best nearby options:\n\n";
          for (var store in recommendedStores) {
            finalMessage += "🏪 **${store['storeName']}** (${store['storeType']}) - ${store['distance'].toStringAsFixed(1)} km away\n";
            final List<String> displayIngredients = (store['found'] as List<String>).map((e) => e[0].toUpperCase() + e.substring(1)).toList();
            finalMessage += "Has: ${displayIngredients.join(', ')}\n\n";
          }
          _addAiMessage(finalMessage);
        }
      }
    } catch (e) {
      debugPrint("DB Search Error: $e");
      _addAiMessage("Oops! I had trouble scanning the store database. Try again in a minute.");
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
                child: Text('AI Chef is scanning the network...', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              ),
            ),

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
                        hintText: 'Ask anything...',
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