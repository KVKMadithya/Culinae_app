import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart'; // <-- The speed package!
import 'public_store_profile.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = "";

  final List<String> _allCategories = [
    'Vegan', 'Non-Vegan', 'Meat', 'Seafood', 'Dessert', 'Spicy',
    'Gluten-Free', 'Lunch', 'Dinner', 'Appetizer', 'Coffee', 'Tea',
    'Pastry', 'Breakfast', 'Cold Beverage', 'Hot Beverage', 'Sandwiches',
    'Fresh Produce', 'Organic', 'Dairy', 'Snacks', 'Household', 'Spices'
  ];

  static const Color culinaeBrown = Color(0xFF4A1F1F);
  static const Color culinaeCream = Color(0xFFFFF3E3);

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: culinaeCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filter by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: culinaeBrown)),
                        if (_selectedCategory.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setModalState(() => _selectedCategory = "");
                              setState(() => _selectedCategory = "");
                            },
                            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                          )
                      ],
                    ),
                    const SizedBox(height: 12),
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
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    hintText: 'Search for stores...',
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
                  color: _selectedCategory.isNotEmpty ? culinaeBrown : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12)
              ),
              child: IconButton(
                icon: Icon(Icons.tune, color: _selectedCategory.isNotEmpty ? Colors.white : culinaeBrown, size: 22),
                onPressed: _showFilterModal,
              ),
            )
          ],
        ),
      ),
      body: _searchQuery.isNotEmpty ? _buildAccountSearchResults() : _buildPostFeed(),
    );
  }

  Widget _buildAccountSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: culinaeBrown));
        if (!snapshot.hasData) return const SizedBox();

        final matchingStores = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final storeName = (data['storeName'] ?? '').toString().toLowerCase();
          return storeName.isNotEmpty && storeName.contains(_searchQuery);
        }).toList();

        if (matchingStores.isEmpty) return const Center(child: Text('No stores found.', style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          itemCount: matchingStores.length,
          itemBuilder: (context, index) {
            final storeData = matchingStores[index].data() as Map<String, dynamic>;
            final storeId = matchingStores[index].id;
            final storeName = storeData['storeName'] ?? 'Store';
            final profilePic = storeData['profilePicUrl'] ?? '';
            final storeType = storeData['storeType'] ?? 'Store';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: culinaeBrown,
                // UPGRADED: Using CachedNetworkImageProvider for avatars
                backgroundImage: profilePic.isNotEmpty ? CachedNetworkImageProvider(profilePic) : null,
                child: profilePic.isEmpty ? const Icon(Icons.storefront, color: Colors.white) : null,
              ),
              title: Text(storeName, style: const TextStyle(fontWeight: FontWeight.bold, color: culinaeBrown)),
              subtitle: Text(storeType, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => PublicStoreProfilePage(ownerId: storeId, storeName: storeName)));
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPostFeed() {
    return StreamBuilder<QuerySnapshot>(
      // UPGRADED: Added .limit(20) so the app doesn't freeze downloading the whole database!
      stream: FirebaseFirestore.instance.collection('posts').orderBy('timestamp', descending: true).limit(20).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: culinaeBrown));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No posts yet! Check back later.', style: TextStyle(color: Colors.grey)));

        final filteredPosts = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final tags = List<String>.from(data['tags'] ?? []);
          if (_selectedCategory.isNotEmpty && !tags.contains(_selectedCategory)) return false;
          return true;
        }).toList();

        if (filteredPosts.isEmpty) return Center(child: Text('No posts found for "$_selectedCategory".', style: const TextStyle(color: Colors.grey)));

        return ListView.builder(
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

    // This handles both following AND unfollowing perfectly!
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
          // 1. HEADER
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
                      // UPGRADED: Using CachedNetworkImageProvider for avatars
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

          // 2. IMAGE CAROUSEL
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
                      // UPGRADED: Using CachedNetworkImage for lightning fast scrolling
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

          // 3. ACTION BAR
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

          // 4. LIKES COUNT & NEW PRICE DISPLAY
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

          // 5. CAPTION & TAGS
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