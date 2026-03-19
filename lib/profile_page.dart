import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'owner_home.dart';
import 'feed.dart'; // <-- IMPORTED THIS so we can reuse the PostCard!

// -- Main Profile Page --
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Real State Variables
  String profilePicUrl = '';
  String username = 'Loading...';
  String bio = '';
  String savedLocation = '';

  // CHANGED: We now save the entire Document, not just the string URL!
  List<DocumentSnapshot> savedPosts = [];
  bool _isLoading = true;

  // Dual Role State
  bool _canSwitchToOwner = false;

  static const Color culinaeBrown = Color(0xFF4A1F1F);
  static const Color culinaeCream = Color(0xFFFFF3E3);

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // --- FIREBASE: Fetch User Data & Saved Posts ---
  Future<void> _fetchUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        // 1. Load Profile Details
        setState(() {
          username = data['name'] ?? data['username'] ?? 'Culinae User';
          bio = data['bio'] ?? '';
          savedLocation = data['savedLocation'] ?? '';
          profilePicUrl = data['profilePicUrl'] ?? '';
          if (data['hasDualRole'] == true) _canSwitchToOwner = true;
        });

        // 2. Load Saved Posts Grid
        List<dynamic> savedPostIds = data['savedPostIds'] ?? [];
        List<DocumentSnapshot> fetchedPosts = [];

        // Fetch the FULL document for every post the user has saved
        for (String postId in savedPostIds) {
          final postDoc = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
          if (postDoc.exists) {
            fetchedPosts.add(postDoc);
          }
        }

        setState(() {
          savedPosts = fetchedPosts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      setState(() => _isLoading = false);
    }
  }

  // --- Reusable Themed Confirmation Popup ---
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

  // --- Logic for Account Management ---
  Future<void> _handleMenuSelection(String value) async {
    if (value == 'switch') {
      bool confirm = await _showConfirmationDialog('Switch Modes?', 'Do you want to switch to the Store Owner dashboard?', 'Switch', Colors.blueAccent);
      if (confirm) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({'role': 'owner'});
          if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const OwnerHomePage()), (route) => false);
        }
      }
    } else if (value == 'logout') {
      bool confirm = await _showConfirmationDialog('Log Out?', 'Are you sure you want to log out of Culinae?', 'Log Out', culinaeBrown);
      if (confirm) {
        await FirebaseAuth.instance.signOut();
      }
    } else if (value == 'delete') {
      bool confirm = await _showConfirmationDialog('Delete Account?', 'WARNING: This action cannot be undone.', 'Delete Forever', Colors.red);
      if (confirm) {
        try {
          await FirebaseAuth.instance.currentUser?.delete();
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Security alert: Please log out and log back in before deleting your account.')));
        }
      }
    }
  }

  void _openEditProfile() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditProfileModal(
        initialProfilePicUrl: profilePicUrl,
        initialUsername: username,
        initialBio: bio,
        initialSavedLocation: savedLocation,
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      _fetchUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: culinaeCream, body: Center(child: CircularProgressIndicator(color: culinaeBrown)));
    }

    final bool isProfileEmpty = profilePicUrl.isEmpty;

    return Scaffold(
      backgroundColor: culinaeCream,
      appBar: AppBar(
        title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold, color: culinaeBrown)),
        backgroundColor: culinaeCream,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: culinaeBrown),
            onSelected: _handleMenuSelection,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              if (_canSwitchToOwner) ...[
                const PopupMenuItem<String>(value: 'switch', child: Row(children: [Icon(Icons.storefront, color: Colors.blueAccent), SizedBox(width: 8), Text('Switch to Owner', style: TextStyle(color: Colors.blueAccent))])),
                const PopupMenuDivider(),
              ],
              const PopupMenuItem<String>(value: 'logout', child: Row(children: [Icon(Icons.logout, color: culinaeBrown), SizedBox(width: 8), Text('Logout')])),
              const PopupMenuItem<String>(value: 'delete', child: Row(children: [Icon(Icons.delete_forever, color: Colors.red), SizedBox(width: 8), Text('Delete Account', style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ProfileHeader(
              profilePicUrl: profilePicUrl,
              isProfileEmpty: isProfileEmpty,
              username: username,
              bio: bio,
              savesCount: savedPosts.length, // Passed the length of the documents array
              onEditPressed: _openEditProfile,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.bookmark_border, color: culinaeBrown),
                  SizedBox(width: 8),
                  Text('Saved Items from Stores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: culinaeBrown)),
                ],
              ),
            ),
            if (savedPosts.isNotEmpty)
              SavedPostsGrid(posts: savedPosts) // Passed the documents array!
            else
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Text(
                    'Follow stores to see and save their latest posts!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -- Profile Header Widget --
class ProfileHeader extends StatelessWidget {
  final String profilePicUrl;
  final bool isProfileEmpty;
  final String username;
  final String bio;
  final int savesCount;
  final VoidCallback onEditPressed;

  const ProfileHeader({
    super.key,
    required this.profilePicUrl,
    required this.isProfileEmpty,
    required this.username,
    required this.bio,
    required this.savesCount,
    required this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onEditPressed,
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: const Color(0xffeaeaea),
                  backgroundImage: profilePicUrl.isNotEmpty ? NetworkImage(profilePicUrl) : null,
                  child: isProfileEmpty ? const Icon(Icons.person, size: 50, color: Color(0xffb0b0b0)) : null,
                ),
              ),
              const Expanded(child: SizedBox()),
              _buildStatColumn('Saves', savesCount),
              const SizedBox(width: 24),
              _buildStatColumn('Stores', 0), // Default 0 as requested
              const SizedBox(width: 24),
              _buildStatColumn('Community', 0), // Default 0 as requested
              const SizedBox(width: 16),
            ],
          ),
          const SizedBox(height: 16),
          Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF4A1F1F))),
          if (bio.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(bio, style: const TextStyle(fontSize: 14, color: Colors.black87))),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: onEditPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A1F1F),
                foregroundColor: const Color(0xFFFFF3E3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, int number) {
    return Column(
      children: [
        Text(number.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4A1F1F))),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }
}

// -- UPGRADED: Saved Posts Grid Widget (Now Clickable!) --
class SavedPostsGrid extends StatelessWidget {
  final List<DocumentSnapshot> posts;
  const SavedPostsGrid({super.key, required this.posts});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2.0,
        mainAxisSpacing: 2.0,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final data = posts[index].data() as Map<String, dynamic>;
        final List<dynamic> urls = data['imageUrls'] ?? [];
        final String mainImage = urls.isNotEmpty ? urls[0] : '';

        if (mainImage.isEmpty) return const SizedBox();

        return GestureDetector(
          onTap: () {
            // Opens a new screen and renders the exact PostCard from your feed!
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  backgroundColor: const Color(0xFFFFF3E3),
                  appBar: AppBar(
                    backgroundColor: const Color(0xFFFFF3E3),
                    elevation: 0,
                    leading: const BackButton(color: Color(0xFF4A1F1F)),
                    title: const Text('Saved Post', style: TextStyle(color: Color(0xFF4A1F1F), fontWeight: FontWeight.bold)),
                  ),
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: PostCard(postDoc: posts[index]), // Recycled from Feed!
                    ),
                  ),
                ),
              ),
            );
          },
          child: Image.network(mainImage, fit: BoxFit.cover),
        );
      },
    );
  }
}

// -- LIVE Edit Profile Modal Screen --
class EditProfileModal extends StatefulWidget {
  final String initialProfilePicUrl;
  final String initialUsername;
  final String initialBio;
  final String initialSavedLocation;

  const EditProfileModal({
    super.key,
    required this.initialProfilePicUrl,
    required this.initialUsername,
    required this.initialBio,
    required this.initialSavedLocation,
  });

  @override
  State<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends State<EditProfileModal> {
  late TextEditingController _usernameController, _bioController, _locationController;
  String _currentProfilePicUrl = '';
  File? _newImageFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialUsername);
    _bioController = TextEditingController(text: widget.initialBio);
    _locationController = TextEditingController(text: widget.initialSavedLocation);
    _currentProfilePicUrl = widget.initialProfilePicUrl;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // Pick Image from Gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) setState(() => _newImageFile = File(pickedFile.path));
  }

  // Upload to Firebase and Save Data
  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      try {
        String finalImageUrl = _currentProfilePicUrl;

        // Upload new image if selected
        if (_newImageFile != null) {
          final storageRef = FirebaseStorage.instance.ref().child('profile_pics/$uid.jpg');
          await storageRef.putFile(_newImageFile!);
          finalImageUrl = await storageRef.getDownloadURL();
        }

        // Save Data to Firestore
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'name': _usernameController.text.trim(),
          'bio': _bioController.text.trim(),
          'savedLocation': _locationController.text.trim(),
          'profilePicUrl': finalImageUrl,
        });

        if (mounted) Navigator.pop(context, true); // Tell parent to refresh!
      } catch (e) {
        debugPrint("Error saving profile: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save profile. Try again.')));
      }
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    const Color culinaeBrown = Color(0xFF4A1F1F);
    const Color culinaeCream = Color(0xFFFFF3E3);

    return SafeArea(
      child: Scaffold(
        backgroundColor: culinaeCream,
        appBar: AppBar(
          backgroundColor: culinaeCream,
          elevation: 0,
          leading: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.redAccent, fontSize: 16))),
          title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, color: culinaeBrown)),
          centerTitle: true,
          actions: [
            _isSaving
                ? const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : TextButton(onPressed: _saveProfile, child: const Text('Done', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xffeaeaea),
                          image: _newImageFile != null
                              ? DecorationImage(image: FileImage(_newImageFile!), fit: BoxFit.cover)
                              : (_currentProfilePicUrl.isNotEmpty ? DecorationImage(image: NetworkImage(_currentProfilePicUrl), fit: BoxFit.cover) : null),
                        ),
                        child: (_newImageFile == null && _currentProfilePicUrl.isEmpty) ? const Icon(Icons.person, color: Color(0xffb0b0b0), size: 50) : null,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _pickImage,
                        child: const Text('Change Profile Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                _buildEditField('Username', 'e.g. CulinaeCustomer_42', _usernameController, false),
                const SizedBox(height: 16),
                _buildEditField('Bio', 'Write something about yourself...', _bioController, true),
                const SizedBox(height: 16),
                _buildEditField('Saved Location', 'Add a city or neighborhood...', _locationController, false),
                const SizedBox(height: 32),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditField(String label, String hint, TextEditingController controller, bool isMultiLine) {
    const Color culinaeBrown = Color(0xFF4A1F1F);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: culinaeBrown)),
        const SizedBox(height: 6),
        TextField(
          controller: controller, maxLines: isMultiLine ? 4 : 1, minLines: 1, style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint, hintStyle: const TextStyle(color: Colors.grey),
            filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xffeaeaea))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: culinaeBrown, width: 2)),
          ),
        ),
      ],
    );
  }
}