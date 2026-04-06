import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'feed.dart'; // <-- Needed to reuse the PostCard widget!

class PublicStoreProfilePage extends StatefulWidget {
  final String ownerId;
  final String storeName;

  const PublicStoreProfilePage({
    super.key,
    required this.ownerId,
    required this.storeName,
  });

  @override
  State<PublicStoreProfilePage> createState() => _PublicStoreProfilePageState();
}

class _PublicStoreProfilePageState extends State<PublicStoreProfilePage> {
  // Store Details
  String profilePicUrl = '';
  String storeName = '';
  String bio = '';
  String contactNumber = '';
  String location = '';
  String storeType = 'Store';

  // Live Stats & State
  int followersCount = 0;
  int totalLikes = 0;
  bool isFollowing = false;
  bool _isLoading = true;

  // NEW: UI Toggle State
  bool _showMenu = false;

  final List<DocumentSnapshot> _storePosts = [];
  List<Map<String, dynamic>> _menuItems = []; // NEW: Stores the text menu

  static const Color culinaeBrown = Color(0xFF4A1F1F);
  static const Color culinaeCream = Color(0xFFFFF3E3);

  @override
  void initState() {
    super.initState();
    storeName = widget.storeName;
    _fetchStoreData();
    _fetchPosts();
  }

  // --- Fetch Store Details, Followers, AND Menu! ---
  Future<void> _fetchStoreData() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.ownerId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        List<dynamic> followers = data['followers'] ?? [];

        setState(() {
          storeName = data['storeName'] ?? data['name'] ?? widget.storeName;
          bio = data['bio'] ?? '';
          contactNumber = data['contactNumber'] ?? '';
          location = data['storeAddress'] ?? '';
          storeType = data['storeType'] ?? 'Store';
          profilePicUrl = data['profilePicUrl'] ?? '';
          followersCount = followers.length;

          // Load the menu array if the owner has created one!
          if (data.containsKey('menu')) {
            _menuItems = List<Map<String, dynamic>>.from(data['menu']);
          }

          if (myUid != null) {
            isFollowing = followers.contains(myUid);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching store data: $e');
      setState(() => _isLoading = false);
    }
  }

  // --- Fetch Posts & Calculate Total Likes ---
  Future<void> _fetchPosts() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('ownerId', isEqualTo: widget.ownerId)
          .get();

      if (mounted) {
        int calculatedLikes = 0;
        List<DocumentSnapshot> fetchedDocs = [];

        for (var doc in snapshot.docs) {
          final data = doc.data();

          List<dynamic> postLikes = data['likes'] ?? [];
          calculatedLikes += postLikes.length;

          fetchedDocs.add(doc);
        }

        fetchedDocs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final timeA = dataA['timestamp'] as Timestamp?;
          final timeB = dataB['timestamp'] as Timestamp?;

          if (timeA == null && timeB == null) return 0;
          if (timeA == null) return 1;
          if (timeB == null) return -1;
          return timeB.compareTo(timeA);
        });

        setState(() {
          _storePosts.clear();
          _storePosts.addAll(fetchedDocs);
          totalLikes = calculatedLikes;
        });
      }
    } catch (e) {
      debugPrint('Error fetching public posts: $e');
    }
  }

  // --- Follow / Unfollow Logic ---
  Future<void> _toggleFollow() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || myUid == widget.ownerId) return;

    setState(() {
      if (isFollowing) {
        isFollowing = false;
        followersCount--;
      } else {
        isFollowing = true;
        followersCount++;
      }
    });

    final myUserRef = FirebaseFirestore.instance.collection('users').doc(myUid);
    final storeUserRef = FirebaseFirestore.instance.collection('users').doc(widget.ownerId);

    try {
      if (!isFollowing) {
        await myUserRef.update({'following': FieldValue.arrayRemove([widget.ownerId])});
        await storeUserRef.update({'followers': FieldValue.arrayRemove([myUid])});
      } else {
        await myUserRef.update({'following': FieldValue.arrayUnion([widget.ownerId])});
        await storeUserRef.update({'followers': FieldValue.arrayUnion([myUid])});
      }
    } catch (e) {
      debugPrint("Failed to follow: $e");
      setState(() {
        isFollowing = !isFollowing;
        isFollowing ? followersCount++ : followersCount--;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update follow status.')));
    }
  }

  // --- NEW: Add Menu Item to Cart ---
  Future<void> _addMenuItemToCart(Map<String, dynamic> item) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('cart').add({
        'postId': 'menu_item_${DateTime.now().millisecondsSinceEpoch}', // Pseudo-ID for text items
        'storeId': widget.ownerId,
        'storeName': storeName,
        'caption': item['name'], // Using the dish name as the caption in the cart
        'price': 'Rs. ${item['price']}',
        'imageUrl': '', // Text menu items don't have images
        'addedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to Cart! 🛒'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      debugPrint('Error adding menu item to cart: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: culinaeCream,
          body: Center(child: CircularProgressIndicator(color: culinaeBrown))
      );
    }

    final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool isMyOwnProfile = myUid == widget.ownerId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: culinaeBrown),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(storeName, style: const TextStyle(fontWeight: FontWeight.bold, color: culinaeBrown, fontFamily: 'Serif')),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TOP HEADER SECTION ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: culinaeBrown,
                      image: profilePicUrl.isNotEmpty ? DecorationImage(image: NetworkImage(profilePicUrl), fit: BoxFit.cover) : null,
                    ),
                    child: profilePicUrl.isEmpty ? const Icon(Icons.storefront, color: culinaeCream, size: 40) : null,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(storeName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: culinaeBrown, fontFamily: 'Serif')),
                        const SizedBox(height: 4),
                        Text(location.isNotEmpty ? location : 'Location not provided', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blueGrey.shade100, borderRadius: BorderRadius.circular(8)),
                              child: Text(storeType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            )
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),

            // --- BIO & CONTACT SECTION ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: culinaeBrown)),
                  const SizedBox(height: 8),
                  Text(bio.isNotEmpty ? bio : 'Welcome to $storeName!', style: const TextStyle(fontSize: 14, color: Colors.black87)),

                  if (contactNumber.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(contactNumber, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ]
                ],
              ),
            ),

            // --- LIVE STATS ROW ---
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn('Posts', _storePosts.length),
                  _buildStatColumn('Followers', followersCount),
                  _buildStatColumn('Total Likes', totalLikes),
                ],
              ),
            ),

            // --- THE FOLLOW BUTTON ---
            if (!isMyOwnProfile)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing ? Colors.grey.shade300 : Colors.blueAccent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      isFollowing ? 'Following' : 'Follow Store',
                      style: TextStyle(color: isFollowing ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ),
            if (!isMyOwnProfile) const Divider(color: Colors.black12, thickness: 1),

            // --- NEW: POSTS / MENU TOGGLE ---
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _showMenu = false),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Icon(Icons.grid_on, color: !_showMenu ? culinaeBrown : Colors.grey),
                        ),
                        Container(height: 2, color: !_showMenu ? culinaeBrown : Colors.transparent)
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _showMenu = true),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Icon(Icons.restaurant_menu, color: _showMenu ? culinaeBrown : Colors.grey),
                        ),
                        Container(height: 2, color: _showMenu ? culinaeBrown : Colors.transparent)
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- DYNAMIC BODY: Show Grid OR Show Menu ---
            if (!_showMenu) ...[
              // --- CLICKABLE PHOTO GRID ---
              if (_storePosts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(child: Text("This store hasn't posted anything yet.", style: TextStyle(color: Colors.grey))),
                )
              else
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2.0,
                    mainAxisSpacing: 2.0,
                  ),
                  itemCount: _storePosts.length,
                  itemBuilder: (context, index) {
                    final postDoc = _storePosts[index];
                    final data = postDoc.data() as Map<String, dynamic>;
                    final List<dynamic> urls = data['imageUrls'] ?? [];
                    final String mainImage = urls.isNotEmpty ? urls[0] : '';

                    if (mainImage.isEmpty) return const SizedBox();

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              backgroundColor: const Color(0xFFFFF3E3),
                              appBar: AppBar(
                                backgroundColor: const Color(0xFFFFF3E3),
                                elevation: 0,
                                leading: const BackButton(color: Color(0xFF4A1F1F)),
                              ),
                              body: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: PostCard(postDoc: postDoc),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: Image.network(mainImage, fit: BoxFit.cover),
                    );
                  },
                ),
            ] else ...[
              // --- STORE MENU LIST ---
              if (_menuItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(child: Text("This store hasn't set up their menu yet.", style: TextStyle(color: Colors.grey))),
                )
              else
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _menuItems.length,
                  itemBuilder: (context, index) {
                    final item = _menuItems[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      color: culinaeCream,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
                      child: ListTile(
                        title: Text(item['name'] ?? 'Dish', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: culinaeBrown)),
                        subtitle: Text('Rs. ${item['price'] ?? '0.00'}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_shopping_cart, color: culinaeBrown),
                          onPressed: () => _addMenuItemToCart(item),
                        ),
                      ),
                    );
                  },
                ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, int number) {
    return Column(
      children: [
        Text(number.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: culinaeBrown)),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }
}
