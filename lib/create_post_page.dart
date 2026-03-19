import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CreatePostPage extends StatefulWidget {
  final String storeType; // We pass this in to know which categories to show!
  final String storeName;
  final String storeProfilePicUrl;

  const CreatePostPage({
    super.key,
    required this.storeType,
    required this.storeName,
    required this.storeProfilePicUrl,
  });

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController(); // NEW: Price Controller!

  // Stores the selected images
  final List<XFile> _selectedImages = [];

  // Tag Filtering Logic
  List<String> _availableTags = [];
  final List<String> _selectedTags = [];
  bool _isUploading = false;

  static const Color culinaeBrown = Color(0xFF4A1F1F);
  static const Color culinaeCream = Color(0xFFFFF3E3);

  @override
  void initState() {
    super.initState();
    _setDynamicCategories();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // --- Dynamic Categories based on Store Type ---
  void _setDynamicCategories() {
    if (widget.storeType == 'Café') {
      _availableTags = ['Coffee', 'Tea', 'Pastry', 'Breakfast', 'Vegan', 'Cold Beverage', 'Hot Beverage', 'Dessert', 'Sandwiches'];
    } else if (widget.storeType == 'Grocery Store') {
      _availableTags = ['Fresh Produce', 'Organic', 'Dairy', 'Snacks', 'Meat', 'Beverages', 'Household', 'Spices', 'Vegan'];
    } else {
      // Default / Restaurant
      _availableTags = ['Vegan', 'Non-Vegan', 'Meat', 'Seafood', 'Dessert', 'Spicy', 'Gluten-Free', 'Lunch', 'Dinner', 'Appetizer'];
    }
  }

  // --- Image Picker (Max 5) ---
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    // Allows picking multiple images at once
    final List<XFile> pickedFiles = await picker.pickMultiImage(imageQuality: 70);

    if (pickedFiles.isNotEmpty) {
      setState(() {
        for (var file in pickedFiles) {
          if (_selectedImages.length < 5) { // Enforce max 5 images
            _selectedImages.add(file);
          }
        }
      });

      if (pickedFiles.length + _selectedImages.length > 5 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can only select up to 5 images per post.')));
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // --- Firebase Upload Logic ---
  Future<void> _uploadPost() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one image.')));
      return;
    }

    setState(() => _isUploading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      try {
        List<String> uploadedImageUrls = [];

        // 1. Upload all images to Firebase Storage
        for (var imageFile in _selectedImages) {
          // Create a unique file name using timestamp
          String fileName = DateTime.now().millisecondsSinceEpoch.toString() + '_' + imageFile.name;
          final storageRef = FirebaseStorage.instance.ref().child('posts/$uid/$fileName');

          await storageRef.putFile(File(imageFile.path));
          String downloadUrl = await storageRef.getDownloadURL();
          uploadedImageUrls.add(downloadUrl);
        }

        // 2. Format the Price
        String postPrice = _priceController.text.trim();
        if (postPrice.isEmpty) {
          postPrice = 'Contact for more info'; // Default if left blank!
        }

        // 3. Save the post data to Firestore
        await FirebaseFirestore.instance.collection('posts').add({
          'ownerId': uid,
          'storeName': widget.storeName,
          'storeProfilePicUrl': widget.storeProfilePicUrl,
          'imageUrls': uploadedImageUrls,
          'caption': _captionController.text.trim(),
          'price': postPrice, // Saving the price!
          'tags': _selectedTags,
          'timestamp': FieldValue.serverTimestamp(),
          'likes': [], // Upgraded likes array
        });

        if (mounted) {
          Navigator.pop(context, true); // Go back and tell the profile page to refresh
        }
      } catch (e) {
        debugPrint("Error uploading post: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to upload post. Try again.')));
      }
    }
    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: culinaeCream,
      appBar: AppBar(
        backgroundColor: culinaeBrown,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('New Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Serif')),
        actions: [
          _isUploading
              ? const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
              : TextButton(
            onPressed: _uploadPost,
            child: const Text('SHARE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Image Preview Area ---
            if (_selectedImages.isEmpty)
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  height: 250, width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate, size: 60, color: Colors.grey), SizedBox(height: 8), Text('Tap to select up to 5 photos', style: TextStyle(color: Colors.grey))]),
                ),
              )
            else
              SizedBox(
                height: 250,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length < 5 ? _selectedImages.length + 1 : _selectedImages.length,
                  itemBuilder: (context, index) {
                    if (index == _selectedImages.length) {
                      return GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: 200, margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
                          child: const Icon(Icons.add, size: 50, color: Colors.grey),
                        ),
                      );
                    }

                    return Stack(
                      children: [
                        Container(
                          width: 250, margin: EdgeInsets.only(right: _selectedImages.length > 1 ? 8 : 0),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: FileImage(File(_selectedImages[index].path)), fit: BoxFit.cover)),
                        ),
                        Positioned(
                          top: 8, right: 16,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: const CircleAvatar(radius: 14, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 16, color: Colors.white)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            // --- Caption ---
            const Text('Caption', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: culinaeBrown)),
            const SizedBox(height: 8),
            TextField(
              controller: _captionController, maxLines: 4,
              decoration: InputDecoration(hintText: 'Write a caption for this dish...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
            ),

            const SizedBox(height: 24),

            // --- Price (NEW!) ---
            const Text('Price (Optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: culinaeBrown)),
            const SizedBox(height: 8),
            TextField(
              controller: _priceController,
              decoration: InputDecoration(
                  hintText: 'e.g. \$12.99 or Rs. 1500 (Leave empty for "Contact for info")',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
              ),
            ),

            const SizedBox(height: 24),

            // --- Categories (Max 5) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: culinaeBrown)),
                Text('${_selectedTags.length}/5 selected', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0, runSpacing: 4.0,
              children: _availableTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  selectedColor: culinaeBrown.withValues(alpha: 0.2),
                  checkmarkColor: culinaeBrown,
                  labelStyle: TextStyle(color: isSelected ? culinaeBrown : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        if (_selectedTags.length < 5) {
                          _selectedTags.add(tag);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can only select up to 5 categories.')));
                        }
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}