import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'public_store_profile.dart'; // Needed for the buttons!

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

  // --- 🤖 THE INTENT-DRIVEN AI ENGINE (UPGRADED) ---
  Future<void> _analyzeWithGeminiAndSearch(String userQuery) async {
    final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

    // NEW: We use '|||' so the AI can safely write multi-line recipes!
    final prompt = '''
      You are an AI Assistant for a food delivery app.
      The user says: "$userQuery"
      
      Categorize the request and extract information. 
      Return your response EXACTLY in this format, using "|||" to separate the three sections. 
      
      [SECTION 1]
      If it is a RECIPE, provide the complete recipe here including a list of ingredients and step-by-step instructions. 
      If it is an ITEM_SEARCH or STORE_LOCATION, provide a friendly, helpful conversational response.
      |||
      [SECTION 2]
      Must be exactly one of: RECIPE, ITEM_SEARCH, STORE_LOCATION, OTHER
      |||
      [SECTION 3]
      If RECIPE: Comma-separated list of raw ingredients.
      If ITEM_SEARCH: Comma-separated list of food items.
      If STORE_LOCATION: The exact name of the store.
      If OTHER: none
    ''';

    String aiChatResponse = "";
    String intent = "";
    List<String> keywords = [];

    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      final rawText = response.text?.trim() ?? "";

      final parts = rawText.split('|||');

      if (parts.length >= 3) {
        aiChatResponse = parts[0].replaceAll('[SECTION 1]', '').trim();
        intent = parts[1].replaceAll('[SECTION 2]', '').trim().toUpperCase();
        String rawKeywords = parts[2].replaceAll('[SECTION 3]', '').trim();

        if (rawKeywords.toLowerCase() != 'none') {
          keywords = rawKeywords.split(',').map((e) => e.trim().toLowerCase()).toList();
        }
      }
    } catch (e) {
      debugPrint("Gemini API Error: $e");
      _addAiMessage("My AI brain is a little disconnected right now. Try again in a moment!");
      return;
    }

    // 1️⃣ IMMEDIATELY show the AI's response (This guarantees the user ALWAYS gets the recipe!)
    if (aiChatResponse.isNotEmpty) {
      setState(() => _messages.add({'sender': 'ai', 'text': aiChatResponse}));
      _scrollToBottom();
    }

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
      if (intent == 'STORE_LOCATION') {
        final storeNameToFind = keywords.first;
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

              // Pass the store data so we can generate a button!
              _addAiMessage(
                  "📍 **${data['storeName']}** is located ${distanceInKm.toStringAsFixed(1)} km away from you!",
                  stores: [{'ownerId': doc.id, 'storeName': data['storeName']}]
              );
              storeFound = true;
            }
          }
        }

        if (!storeFound) {
          _addAiMessage("I couldn't find a store named '${keywords.first}' on the map. 😔");
        }
      }
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
                'ownerId': ownerId, // NEW: We need the ID for the button link
                'storeName': storeNames[ownerId],
                'storeType': storeType,
                'distance': distanceInMeters / 1000,
                'found': storeFoundItems[ownerId],
              });
            }
          }
        }

        if (recommendedStores.isEmpty) {
          if (intent != 'RECIPE') {
            _addAiMessage("I couldn't find any nearby stores mentioning those items right now. 😔");
          } else {
            // For recipes, we already gave the recipe. Just stop typing.
            setState(() => _isTyping = false);
          }
        } else {
          recommendedStores.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

          String finalMessage = intent == 'RECIPE'
              ? "Good news! I found some nearby stores that have the ingredients you need:\n\n"
              : "Here are the best nearby options:\n\n";

          List<Map<String, dynamic>> storesForButtons = [];

          for (var store in recommendedStores) {
            finalMessage += "🏪 **${store['storeName']}** (${store['storeType']}) - ${store['distance'].toStringAsFixed(1)} km away\n";
            final List<String> displayIngredients = (store['found'] as List<String>).map((e) => e[0].toUpperCase() + e.substring(1)).toList();
            finalMessage += "Has: ${displayIngredients.join(', ')}\n\n";

            // Add to the button list
            storesForButtons.add({
              'ownerId': store['ownerId'],
              'storeName': store['storeName']
            });
          }

          // Send the follow-up message with the interactive buttons attached!
          _addAiMessage(finalMessage, stores: storesForButtons);
        }
      }
    } catch (e) {
      debugPrint("DB Search Error: $e");
      _addAiMessage("Oops! I had trouble scanning the store database. Try again in a minute.");
    }
  }

  // NEW: Added an optional 'stores' parameter to pass button data!
  void _addAiMessage(String text, {List<Map<String, dynamic>>? stores}) {
    setState(() {
      _messages.add({
        'sender': 'ai',
        'text': text,
        'stores': stores // Attach the stores to the message
      });
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
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/wallpaper.png'),
            fit: BoxFit.cover,
            opacity: 0.15,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isAi = msg['sender'] == 'ai';

                  // Safely extract the stores list if it exists
                  final List<dynamic> attachedStores = msg['stores'] ?? [];

                  return Align(
                    alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg['text'],
                            style: TextStyle(color: isAi ? Colors.black87 : Colors.white, fontSize: 15),
                          ),

                          // 🔘 DYNAMIC BUTTON GENERATION
                          if (isAi && attachedStores.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: attachedStores.map((store) {
                                return ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => PublicStoreProfilePage(
                                            ownerId: store['ownerId'],
                                            storeName: store['storeName']
                                        )
                                    ));
                                  },
                                  icon: const Icon(Icons.storefront, size: 16),
                                  label: Text("Visit ${store['storeName']}"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: culinaeCream,
                                    foregroundColor: culinaeBrown,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                );
                              }).toList(),
                            )
                          ]
                        ],
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
                  child: Text('AI Chef is thinking...', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
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
      ),
    );
  }
}