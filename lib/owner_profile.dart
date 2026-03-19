import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'create_post_page.dart';

import 'main.dart';
import 'customer_home.dart';

// --- Data Models ---
class OwnerPost {
  final String imageUrl;
  final String caption;
  final List<String> tags;
  final Timestamp? timestamp; // <-- Added so we can sort them locally!

  OwnerPost({required this.imageUrl, required this.caption, required this.tags, this.timestamp});
}

// --- Main Owner Profile Page ---
class OwnerProfileTab extends StatefulWidget {
  const OwnerProfileTab({super.key});

  @override
  State<OwnerProfileTab> createState() => _OwnerProfileTabState();
}

class _OwnerProfileTabState extends State<OwnerProfileTab> {
  // Store Profile State
  String profilePicUrl = '';
  String storeName = 'Loading...';
  String bio = '';
  String contactNumber = '';
  String location = '';
  String storeType = 'Restaurant';

  // Live Stats
  int followersCount = 0;
  int totalLikes = 0;

  final List<OwnerPost> _posts = [];
  bool _isLoading = true;

  static const Color culinaeBrown = Color(0xFF4A1F1F);
  static const Color culinaeCream = Color(0xFFFFF3E3);

  @override
  void initState() {
    super.initState();
    _fetchStoreData();
    _fetchPosts();
  }

  // --- Fetch Data & Followers from Firebase ---
  Future<void> _fetchStoreData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        List<dynamic> followers = data['followers'] ?? [];

        setState(() {
          storeName = data['storeName'] ?? 'Unnamed Store';
          bio = data['bio'] ?? '';
          contactNumber = data['contactNumber'] ?? '';
          location = data['storeAddress'] ?? '';
          storeType = data['storeType'] ?? 'Restaurant';
          profilePicUrl = data['profilePicUrl'] ?? '';
          followersCount = followers.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      setState(() => _isLoading = false);
    }
  }

  // --- Fetch Posts & Calculate Total Likes ---
  Future<void> _fetchPosts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // THE FIX: Removed the .orderBy() so Firebase doesn't crash from a missing index!
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('ownerId', isEqualTo: uid)
          .get();

      if (mounted) {
        int calculatedLikes = 0;
        List<OwnerPost> fetchedPosts = [];

        for (var doc in snapshot.docs) {
          final data = doc.data();

          // 1. Tally up the likes for this post
          List<dynamic> postLikes = data['likes'] ?? [];
          calculatedLikes += postLikes.length;

          // 2. Grab the first image for the grid
          List<dynamic> urls = data['imageUrls'] ?? [];
          String mainImageUrl = urls.isNotEmpty ? urls[0] : '';

          if (mainImageUrl.isNotEmpty) {
            fetchedPosts.add(OwnerPost(
              imageUrl: mainImageUrl,
              caption: data['caption'] ?? '',
              tags: List<String>.from(data['tags'] ?? []),
              timestamp: data['timestamp'] as Timestamp?, // Save the time to sort locally
            ));
          }
        }

        // THE FIX: Sort the posts locally (Newest at the top)
        fetchedPosts.sort((a, b) {
          if (a.timestamp == null && b.timestamp == null) return 0;
          if (a.timestamp == null) return 1;
          if (b.timestamp == null) return -1;
          return b.timestamp!.compareTo(a.timestamp!);
        });

        setState(() {
          _posts.clear();
          _posts.addAll(fetchedPosts);
          totalLikes = calculatedLikes; // The real likes should now show!
        });
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
    }
  }

  // --- Account Management Popups ---
  Future<void> _handleMenuSelection(String value) async {
    if (value == 'logout') {
      bool confirm = await _showConfirmationDialog('Log Out?', 'Are you sure you want to log out?', 'Log Out', culinaeBrown);
      if (confirm) {
        await FirebaseAuth.instance.signOut();
        if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AuthWrapper()), (route) => false);
      }
    } else if (value == 'delete') {
      bool confirm = await _showConfirmationDialog('Delete Account?', 'WARNING: This action cannot be undone.', 'Delete Forever', Colors.red);
      if (confirm) {
        try {
          await FirebaseAuth.instance.currentUser?.delete();
          if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AuthWrapper()), (route) => false);
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Security alert: Please log out and log back in before deleting.')));
        }
      }
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content, String confirmText, Color confirmColor) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: culinaeCream,
        title: Text(title, style: const TextStyle(color: culinaeBrown, fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            child: Text(confirmText, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditOwnerProfilePage(
          initialProfilePicUrl: profilePicUrl,
          initialName: storeName,
          initialBio: bio,
          initialContact: contactNumber,
          initialLocation: location,
          initialType: storeType,
        ),
      ),
    );

    if (result == true) {
      _fetchStoreData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: culinaeCream, body: Center(child: CircularProgressIndicator(color: culinaeBrown)));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: culinaeBrown, size: 32),
            onSelected: _handleMenuSelection,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'logout', child: Row(children: [Icon(Icons.logout, color: culinaeBrown), SizedBox(width: 8), Text('Logout')])),
              const PopupMenuItem<String>(value: 'delete', child: Row(children: [Icon(Icons.delete_forever, color: Colors.red), SizedBox(width: 8), Text('Delete Account', style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
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
                        Text(storeName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: culinaeBrown, fontFamily: 'Serif')),
                        const SizedBox(height: 4),
                        Text(location.isNotEmpty ? location : 'Location not set', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

            // --- BIO SECTION ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: culinaeBrown)),
                  const SizedBox(height: 8),
                  Text(bio.isNotEmpty ? bio : 'Add a bio to tell customers about your store!', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // --- LIVE STATS ROW ---
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn('Posts', _posts.length),
                  _buildStatColumn('Followers', followersCount),
                  _buildStatColumn('Total Likes', totalLikes),
                ],
              ),
            ),

            // --- EDIT PROFILE BUTTON ---
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.black12), bottom: BorderSide(color: Colors.black12))
              ),
              child: TextButton(
                onPressed: _openEditProfile,
                child: const Text('Edit profile', style: TextStyle(color: Colors.black87)),
              ),
            ),

            // --- PHOTO GRID ---
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2.0,
                mainAxisSpacing: 2.0,
              ),
              itemCount: _posts.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreatePostPage(
                            storeType: storeType,
                            storeName: storeName,
                            storeProfilePicUrl: profilePicUrl,
                          ),
                        ),
                      );
                      if (result == true) {
                        _fetchPosts();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
                      child: const Center(
                        child: Icon(Icons.add_circle_outline, size: 60, color: Colors.black),
                      ),
                    ),
                  );
                }

                final post = _posts[index - 1];
                return Image.network(post.imageUrl, fit: BoxFit.cover);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widget for Stats ---
  Widget _buildStatColumn(String label, int number) {
    return Column(
      children: [
        Text(number.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: culinaeBrown)),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }
}

// =========================================================================
// THE EDIT PROFILE PAGE
// =========================================================================

class EditOwnerProfilePage extends StatefulWidget {
  final String initialProfilePicUrl;
  final String initialName;
  final String initialBio;
  final String initialContact;
  final String initialLocation;
  final String initialType;

  const EditOwnerProfilePage({super.key, required this.initialProfilePicUrl, required this.initialName, required this.initialBio, required this.initialContact, required this.initialLocation, required this.initialType});

  @override
  State<EditOwnerProfilePage> createState() => _EditOwnerProfilePageState();
}

class _EditOwnerProfilePageState extends State<EditOwnerProfilePage> {
  late TextEditingController _nameController, _bioController, _contactController, _locationController;
  late String _storeType;
  String _currentPicUrl = '';
  File? _newImageFile;
  bool _isSaving = false;

  static const Color culinaeBrown = Color(0xFF4A1F1F);
  static const Color culinaeCream = Color(0xFFFFF3E3);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _bioController = TextEditingController(text: widget.initialBio);
    _contactController = TextEditingController(text: widget.initialContact);
    _locationController = TextEditingController(text: widget.initialLocation);
    _storeType = widget.initialType;
    _currentPicUrl = widget.initialProfilePicUrl;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedFile != null) {
      setState(() {
        _newImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      try {
        String finalImageUrl = _currentPicUrl;

        if (_newImageFile != null) {
          final storageRef = FirebaseStorage.instance.ref().child('profile_pics/$uid.jpg');
          await storageRef.putFile(_newImageFile!);
          finalImageUrl = await storageRef.getDownloadURL();
        }

        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'storeName': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'contactNumber': _contactController.text.trim(),
          'storeAddress': _locationController.text.trim(),
          'storeType': _storeType,
          'profilePicUrl': finalImageUrl,
        });

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        debugPrint("Error saving profile: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save profile. Try again.')));
      }
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: culinaeCream,
      appBar: AppBar(
        backgroundColor: culinaeBrown,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontFamily: 'Serif', fontSize: 22, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              backgroundImage: _currentPicUrl.isNotEmpty ? NetworkImage(_currentPicUrl) : null,
              child: _currentPicUrl.isEmpty ? const Icon(Icons.storefront, size: 16, color: culinaeBrown) : null,
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: culinaeBrown,
                    image: _newImageFile != null
                        ? DecorationImage(image: FileImage(_newImageFile!), fit: BoxFit.cover)
                        : (_currentPicUrl.isNotEmpty ? DecorationImage(image: NetworkImage(_currentPicUrl), fit: BoxFit.cover) : null),
                  ),
                  child: (_newImageFile == null && _currentPicUrl.isEmpty) ? const Icon(Icons.storefront, color: culinaeCream, size: 40) : null,
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.pink.shade200),
                    child: const Icon(Icons.add, size: 40, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Change Profile Picture', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 32),

            _buildField('Name', _nameController),
            _buildField('Location', _locationController),
            _buildField('Contact No.', _contactController),
            _buildField('Bio', _bioController, isMulti: true),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mode', style: TextStyle(fontSize: 16, color: Colors.black87)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _storeType,
                      items: ['Restaurant', 'Café', 'Grocery Store'].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                      onChanged: (val) => setState(() => _storeType = val!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: 200, height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown.shade400,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SAVE', style: TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1.5)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool isMulti = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.black87)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: isMulti ? 3 : 1,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }
}