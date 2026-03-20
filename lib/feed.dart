import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'public_store_profile.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // --- NEW: Expanded Filters & Allergies ---
  String _selectedCategory = "";
  List<String> _selectedAllergies = [];

  final List<String> _allCategories = [
    'Appetizer', 'Bakery', 'Beverages', 'Breakfast', 'Coffee', 'Cold Beverage',
    'Dairy', 'Dessert', 'Fast Food', 'Fresh Produce', 'Gluten-Free', 'Halal',
    'Healthy', 'Hot Beverage', 'Household', 'Lunch', 'Main Course', 'Meat',
    'Meat & Poultry', 'Non-Vegan', 'Organic', 'Pantry', 'Pastry', 'Sandwiches',
    'Seafood', 'Snacks', 'Spices', 'Spicy', 'Tea', 'Vegan'
  ];

  final List<String> _allAllergies = [
    'Peanuts', 'Tree Nuts', 'Dairy', 'Eggs', 'Wheat', 'Soy', 'Fish', 'Shellfish', 'Gluten'
  ];

  static const Color culinaeBrown = Color(0xFF4A1F1F);
  static const Color culinaeCream = Color(0xFFFFF3E3);

  // --- FILTER MODAL ---
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: culinaeCream,
      isScrollControlled: true, // Allows the modal to be taller
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Filters', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: culinaeBrown)),
                          if (_selectedCategory.isNotEmpty || _selectedAllergies.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  _selectedCategory = "";
                                  _selectedAllergies.clear();
                                });
                                setState(() {
                                  _selectedCategory = "";
                                  _selectedAllergies.clear();
                                });
                              },
                              child: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            )
                        ],
                      ),
                      const Divider(),

                      // 1. CATEGORIES
                      const SizedBox(height: 8),
                      const Text('Show Category:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: culinaeBrown)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0, runSpacing: 4.0,
                        children: _allCategories.map((category) {
                          final isSelected = _selectedCategory == category;
                          return FilterChip(
                            label: Text(category),
                            selected: isSelected,
                            selectedColor: culinaeBrown.withValues(alpha: 0.2),
                            checkmarkColor: culinaeBrown,
                            labelStyle: TextStyle(
                                color: isSelected ? culinaeBrown : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                            ),
                            onSelected: (bool selected) {
                              setModalState(() => _selectedCategory = selected ? category : "");
                              setState(() => _selectedCategory = selected ? category : "");
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // 2. ALLERGIES
                      const Text('Allergies (Hide these items):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0, runSpacing: 4.0,
                        children: _allAllergies.map((allergy) {
                          final isSelected = _selectedAllergies.contains(allergy);
                          return FilterChip(
                            label: Text(allergy),
                            selected: isSelected,
                            selectedColor: Colors.red.shade100,
                            checkmarkColor: Colors.red,
                            labelStyle: TextStyle(
                                color: isSelected ? Colors.red.shade900 : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                            ),
                            onSelected: (bool selected) {
                              setModalState(() {
                                if (selected) {
                                  _selectedAllergies.add(allergy);
                                } else {
                                  _selectedAllergies.remove(allergy);
                                }
                              });
                              setState(() {}); // Updates the main feed behind the modal
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasActiveFilters = _selectedCategory.isNotEmpty || _selectedAllergies.isNotEmpty;

    return Scaffold(
      backgroundColor: culinaeCream,
      appBar: AppBar(
        backgroundColor: culinaeCream,
        elevation: 0,
        title: Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search food or people...',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: culinaeBrown, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                        FocusScope.of(context).unfocus(); // Close keyboard
                      },
                    )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                  color: hasActiveFilters ? culinaeBrown : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12)
              ),
              child: IconButton(
                icon: Icon(hasActiveFilters ? Icons.filter_alt : Icons.tune, color: hasActiveFilters ? Colors.white : culinaeBrown, size: 22),
                onPressed: _showFilterModal,
              ),
            )
          ],
        ),
      ),

      // --- UNIFIED SEARCH & FEED VIEW ---
      body: Column(
        children: [
          // If searching, show matching Users/Stores in a horizontal strip at the top!
          if (_searchQuery.isNotEmpty)
            _buildHorizontalUserSearch(),

          // The Posts Feed takes up the rest of the screen
          Expanded(child: _buildPostFeed()),
        ],
      ),
    );
  }

  // ==========================================================================
  // HORIZONTAL USER SEARCH STRIP (Like Instagram Stories)
  // ==========================================================================
  Widget _buildHorizontalUserSearch() {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        List<dynamic> myFollowing = [];
        try {
          final myDoc = snapshot.data!.docs.firstWhere((doc) => doc.id == myUid);
          myFollowing = (myDoc.data() as Map<String, dynamic>)['following'] ?? [];
        } catch (e) {
          // Ignore
        }

        final matchingUsers = snapshot.data!.docs.where((doc) {
          if (doc.id == myUid) return false;

          final data = doc.data() as Map<String, dynamic>;
          final storeName = (data['storeName'] ?? '').toString().toLowerCase();
          final userName = (data['name'] ?? data['username'] ?? '').toString().toLowerCase();

          return (storeName.isNotEmpty && storeName.contains(_searchQuery)) ||
              (userName.isNotEmpty && userName.contains(_searchQuery));
        }).toList();

        if (matchingUsers.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('Accounts matching "$_searchQuery"', style: const TextStyle(fontWeight: FontWeight.bold, color: culinaeBrown)),
            ),
            SizedBox(
              height: 155,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: matchingUsers.length,
                itemBuilder: (context, index) {
                  final userData = matchingUsers[index].data() as Map<String, dynamic>;
                  final targetId = matchingUsers[index].id;
                  final role = userData['role'] ?? 'customer';

                  final displayName = role == 'owner' ? (userData['storeName'] ?? 'Store') : (userData['name'] ?? userData['username'] ?? 'User');
                  final profilePic = userData['profilePicUrl'] ?? '';
                  final isFollowing = myFollowing.contains(targetId);

                  return GestureDetector(
                    onTap: () {
                      if (role == 'owner') {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => PublicStoreProfilePage(ownerId: targetId, storeName: displayName)));
                      }
                    },
                    child: Container(
                      width: 130,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: culinaeBrown,
                            backgroundImage: profilePic.isNotEmpty ? CachedNetworkImageProvider(profilePic) : null,
                            child: profilePic.isEmpty ? Icon(role == 'owner' ? Icons.storefront : Icons.person, color: Colors.white) : null,
                          ),
                          const SizedBox(height: 8),
                          Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: culinaeBrown)),
                          const SizedBox(height: 8),

                          // Tiny Follow Button
                          SizedBox(
                            height: 28, width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: isFollowing ? Colors.grey.shade200 : Colors.blueAccent,
                                  foregroundColor: isFollowing ? Colors.black87 : Colors.white,
                                  elevation: 0, padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                              onPressed: () async {
                                final myUserRef = FirebaseFirestore.instance.collection('users').doc(myUid);
                                final targetUserRef = FirebaseFirestore.instance.collection('users').doc(targetId);
                                if (isFollowing) {
                                  await myUserRef.update({'following': FieldValue.arrayRemove([targetId])});
                                  await targetUserRef.update({'followers': FieldValue.arrayRemove([myUid])});
                                } else {
                                  await myUserRef.update({'following': FieldValue.arrayUnion([targetId])});
                                  await targetUserRef.update({'followers': FieldValue.arrayUnion([myUid])});
                                }
                              },
                              child: Text(
                                isFollowing ? (role == 'owner' ? 'Following' : 'Friends') : (role == 'owner' ? 'Follow' : 'Add Friend'),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, thickness: 1),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // UNIFIED POST FEED (Handles Search, Categories, AND Allergies)
  // ==========================================================================
  Widget _buildPostFeed() {
    return StreamBuilder<QuerySnapshot>(
      // We pull the 100 most recent posts so client-side filtering has enough data to search through
      stream: FirebaseFirestore.instance.collection('posts').orderBy('timestamp', descending: true).limit(100).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: culinaeBrown));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No posts found!', style: TextStyle(color: Colors.grey)));

        final filteredPosts = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final tags = List<String>.from(data['tags'] ?? []).map((e) => e.toLowerCase()).toList();
          final caption = (data['caption'] ?? '').toString().toLowerCase();

          // 1. SEARCH QUERY FILTER
          if (_searchQuery.isNotEmpty) {
            bool matchesSearch = caption.contains(_searchQuery) || tags.contains(_searchQuery);
            if (!matchesSearch) return false;
          }

          // 2. CATEGORY FILTER
          if (_selectedCategory.isNotEmpty && !tags.contains(_selectedCategory.toLowerCase())) {
            return false;
          }

          // 3. ALLERGY FILTER (Hide the post if it contains the allergy!)
          if (_selectedAllergies.isNotEmpty) {
            for (var allergy in _selectedAllergies) {
              if (caption.contains(allergy.toLowerCase()) || tags.contains(allergy.toLowerCase())) {
                return false; // DANGER: Post contains allergy. Hide it!
              }
            }
          }

          return true; // Passed all filters! Show it!
        }).toList();

        if (filteredPosts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                  'No food posts found matching your search and safety filters.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 16)
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: filteredPosts.length,
          itemBuilder: (context, index) {
            return PostCard(postDoc: filteredPosts[index]);
          },
        );
      },
    );
  }
}

// ============================================================================
// THE POST CARD WIDGET
// ============================================================================
class PostCard extends StatefulWidget {
  final DocumentSnapshot postDoc;
  const PostCard({super.key, required this.postDoc});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int _currentImageIndex = 0;
  static const Color culinaeBrown = Color(0xFF4A1F1F);

  Future<void> _toggleLike() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postDoc.id);
    final data = widget.postDoc.data() as Map<String, dynamic>;
    List<dynamic> likes = data['likes'] ?? [];

    if (likes.contains(uid)) {
      await postRef.update({'likes': FieldValue.arrayRemove([uid])});
    } else {
      await postRef.update({'likes': FieldValue.arrayUnion([uid])});
    }
  }

  Future<void> _toggleFollow(String storeOwnerId, bool isFollowing) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || myUid == storeOwnerId) return;

    final myUserRef = FirebaseFirestore.instance.collection('users').doc(myUid);
    final storeUserRef = FirebaseFirestore.instance.collection('users').doc(storeOwnerId);

    if (isFollowing) {
      await myUserRef.update({'following': FieldValue.arrayRemove([storeOwnerId])});
      await storeUserRef.update({'followers': FieldValue.arrayRemove([myUid])});
    } else {
      await myUserRef.update({'following': FieldValue.arrayUnion([storeOwnerId])});
      await storeUserRef.update({'followers': FieldValue.arrayUnion([myUid])});
    }
  }

  Future<void> _addToCart() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final data = widget.postDoc.data() as Map<String, dynamic>;
    final List<dynamic> imageUrls = data['imageUrls'] ?? [];
    final String price = data['price'] ?? 'Contact for info';

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('cart').add({
        'postId': widget.postDoc.id,
        'storeId': data['ownerId'] ?? '',
        'storeName': data['storeName'] ?? 'Unknown Store',
        'caption': data['caption'] ?? 'Delicious food',
        'price': price,
        'imageUrl': imageUrls.isNotEmpty ? imageUrls[0] : '',
        'addedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to Cart! 🛒'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      debugPrint('Error adding to cart: $e');
    }
  }

  void _goToStoreProfile(String ownerId, String storeName) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PublicStoreProfilePage(ownerId: ownerId, storeName: storeName)));
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LiveCommentsModal(postId: widget.postDoc.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.postDoc.data() as Map<String, dynamic>;
    final String storeName = data['storeName'] ?? 'Unknown Store';
    final String profilePic = data['storeProfilePicUrl'] ?? '';
    final String caption = data['caption'] ?? '';
    final String price = data['price'] ?? '';
    final List<dynamic> imageUrls = data['imageUrls'] ?? [];
    final String ownerId = data['ownerId'] ?? '';
    final List<dynamic> tags = data['tags'] ?? [];

    final List<dynamic> likes = data['likes'] ?? [];
    final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool isLikedByMe = likes.contains(myUid);
    final int likeCount = likes.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(myUid).snapshots(),
              builder: (context, userSnapshot) {
                bool isFollowing = false;
                if (userSnapshot.hasData && userSnapshot.data!.data() != null) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  List<dynamic> followingList = userData['following'] ?? [];
                  isFollowing = followingList.contains(ownerId);
                }

                return ListTile(
                  leading: GestureDetector(
                    onTap: () => _goToStoreProfile(ownerId, storeName),
                    child: CircleAvatar(
                      backgroundColor: culinaeBrown,
                      backgroundImage: profilePic.isNotEmpty ? CachedNetworkImageProvider(profilePic) : null,
                      child: profilePic.isEmpty ? const Icon(Icons.storefront, color: Colors.white, size: 20) : null,
                    ),
                  ),
                  title: GestureDetector(
                    onTap: () => _goToStoreProfile(ownerId, storeName),
                    child: Text(storeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: culinaeBrown)),
                  ),
                  trailing: myUid != ownerId
                      ? TextButton(
                    onPressed: () => _toggleFollow(ownerId, isFollowing),
                    style: TextButton.styleFrom(
                      backgroundColor: isFollowing ? Colors.grey.shade200 : Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(
                      isFollowing ? 'Following' : 'Follow',
                      style: TextStyle(color: isFollowing ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  )
                      : const Icon(Icons.more_horiz),
                );
              }
          ),

          if (imageUrls.isNotEmpty)
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                SizedBox(
                  height: 350,
                  width: double.infinity,
                  child: PageView.builder(
                    itemCount: imageUrls.length,
                    onPageChanged: (index) => setState(() => _currentImageIndex = index),
                    itemBuilder: (context, index) {
                      return CachedNetworkImage(
                        imageUrl: imageUrls[index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: culinaeBrown),
                        ),
                        errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
                      );
                    },
                  ),
                ),
                if (imageUrls.length > 1)
                  Positioned(
                    bottom: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(imageUrls.length, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentImageIndex == index ? 8 : 6,
                          height: _currentImageIndex == index ? 8 : 6,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: _currentImageIndex == index ? culinaeBrown : Colors.white.withValues(alpha: 0.7)),
                        );
                      }),
                    ),
                  ),
              ],
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(icon: Icon(isLikedByMe ? Icons.favorite : Icons.favorite_border, color: isLikedByMe ? Colors.red : culinaeBrown, size: 28), onPressed: _toggleLike),
                IconButton(icon: const Icon(Icons.chat_bubble_outline, color: culinaeBrown, size: 26), onPressed: _openComments),
                const Spacer(),

                IconButton(icon: const Icon(Icons.add_shopping_cart, color: culinaeBrown, size: 28), onPressed: _addToCart),

                StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(myUid).snapshots(),
                    builder: (context, userSnapshot) {
                      bool isSaved = false;
                      if (userSnapshot.hasData && userSnapshot.data!.data() != null) {
                        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                        List<dynamic> savedIds = userData['savedPostIds'] ?? [];
                        isSaved = savedIds.contains(widget.postDoc.id);
                      }

                      return IconButton(
                        icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, color: culinaeBrown, size: 28),
                        onPressed: () async {
                          final userRef = FirebaseFirestore.instance.collection('users').doc(myUid);
                          if (isSaved) {
                            await userRef.update({'savedPostIds': FieldValue.arrayRemove([widget.postDoc.id])});
                          } else {
                            await userRef.update({'savedPostIds': FieldValue.arrayUnion([widget.postDoc.id])});
                          }
                        },
                      );
                    }
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (likeCount > 0)
                  Text('$likeCount ${likeCount == 1 ? 'like' : 'likes'}', style: const TextStyle(fontWeight: FontWeight.bold, color: culinaeBrown)),
                if (price.isNotEmpty)
                  Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  TextSpan(text: '$storeName ', style: const TextStyle(fontWeight: FontWeight.bold, color: culinaeBrown)),
                  TextSpan(text: caption),
                ],
              ),
            ),
          ),

          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 6.0,
                children: tags.map((tag) => Text('#$tag', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12))).toList(),
              ),
            ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ============================================================================
// LIVE COMMENTS MODAL
// ============================================================================
class LiveCommentsModal extends StatefulWidget {
  final String postId;
  const LiveCommentsModal({super.key, required this.postId});

  @override
  State<LiveCommentsModal> createState() => _LiveCommentsModalState();
}

class _LiveCommentsModalState extends State<LiveCommentsModal> {
  final TextEditingController _commentController = TextEditingController();
  bool _isPosting = false;

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isPosting = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final username = userDoc.data()?['name'] ?? userDoc.data()?['storeName'] ?? 'User';

        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .add({
          'userId': uid,
          'username': username,
          'text': _commentController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        });

        _commentController.clear();
      } catch (e) {
        debugPrint('Error posting comment: $e');
      }
    }
    setState(() => _isPosting = false);
  }

  @override
  Widget build(BuildContext context) {
    const Color culinaeBrown = Color(0xFF4A1F1F);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 4, width: 40,
            decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
          ),
          const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: culinaeBrown)),
          const Divider(),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: culinaeBrown));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No comments yet. Be the first!', style: TextStyle(color: Colors.grey)));

                return ListView.builder(
                  reverse: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final commentData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    final text = commentData['text'] ?? '';
                    final username = commentData['username'] ?? 'User';
                    final timestamp = commentData['timestamp'] as Timestamp?;

                    String timeAgo = '';
                    if (timestamp != null) {
                      final difference = DateTime.now().difference(timestamp.toDate());
                      if (difference.inDays > 0) timeAgo = '${difference.inDays}d';
                      else if (difference.inHours > 0) timeAgo = '${difference.inHours}h';
                      else if (difference.inMinutes > 0) timeAgo = '${difference.inMinutes}m';
                      else timeAgo = 'Just now';
                    }

                    return ListTile(
                      leading: CircleAvatar(radius: 16, backgroundColor: Colors.grey.shade300, child: const Icon(Icons.person, size: 16, color: Colors.white)),
                      title: Row(
                        children: [
                          Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: culinaeBrown)),
                          const SizedBox(width: 8),
                          Text(timeAgo, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                      subtitle: Text(text, style: const TextStyle(color: Colors.black87, fontSize: 14)),
                    );
                  },
                );
              },
            ),
          ),

          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16, right: 16, top: 8,
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: const TextStyle(fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isPosting
                      ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: culinaeBrown)))
                      : IconButton(icon: const Icon(Icons.send, color: Colors.blueAccent), onPressed: _postComment),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}