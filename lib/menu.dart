import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- Helper Class ---
class MenuItemData {
  final TextEditingController nameController;
  final TextEditingController priceController;

  MenuItemData({String name = '', String price = ''})
      : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price);
}

// --- Main Menu Page ---
class OwnerMenuPage extends StatefulWidget {
  const OwnerMenuPage({super.key});

  @override
  State<OwnerMenuPage> createState() => _OwnerMenuPageState();
}

class _OwnerMenuPageState extends State<OwnerMenuPage> {
  String _storeName = "Your Store";
  bool _isEditing = false;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<MenuItemData> _menuItems = [];

  static const Color culinaeBrown = Color(0xFF4A1F1F);
  static const Color culinaeCream = Color(0xFFFFF3E3);

  @override
  void initState() {
    super.initState();
    _fetchMenuData();
  }

  // --- 1️⃣ FIREBASE: Fetch Existing Menu & Store Name ---
  Future<void> _fetchMenuData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        setState(() {
          if (data.containsKey('storeName')) {
            _storeName = data['storeName'];
          }

          if (data.containsKey('menu')) {
            final List<dynamic> savedMenu = data['menu'];

            _menuItems.clear(); // <-- CRITICAL FIX: Clears the list so we don't get duplicates on refresh!

            for (var item in savedMenu) {
              _menuItems.add(MenuItemData(
                name: item['name'] ?? '',
                price: item['price'] ?? '',
              ));
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching menu: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- 2️⃣ FIREBASE: Save Menu to Cloud ---
  Future<void> _saveMenu() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    List<Map<String, String>> menuToSave = [];
    for (var item in _menuItems) {
      if (item.nameController.text.trim().isNotEmpty || item.priceController.text.trim().isNotEmpty) {
        menuToSave.add({
          'name': item.nameController.text.trim(),
          'price': item.priceController.text.trim(),
        });
      }
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'menu': menuToSave,
      }, SetOptions(merge: true));

      setState(() {
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menu saved successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving menu: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      if (_menuItems.isEmpty) {
        _addNewItemRow();
      }
    });
  }

  void _addNewItemRow() {
    setState(() {
      _menuItems.add(MenuItemData());
    });
  }

  void _removeRow(int index) {
    setState(() {
      _menuItems[index].nameController.dispose();
      _menuItems[index].priceController.dispose();
      _menuItems.removeAt(index);
    });
  }

  @override
  void dispose() {
    for (var item in _menuItems) {
      item.nameController.dispose();
      item.priceController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMenuEmpty = _menuItems.isEmpty || (_menuItems.length == 1 && _menuItems[0].nameController.text.isEmpty);

    return Scaffold(
      backgroundColor: culinaeCream,
      appBar: AppBar(
        backgroundColor: culinaeCream,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text("$_storeName Menu", style: const TextStyle(color: culinaeBrown, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (_isEditing)
            _isSaving
                ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: culinaeBrown, strokeWidth: 2))),
            )
                : TextButton(
              onPressed: _saveMenu,
              child: const Text('Save', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      floatingActionButton: !_isEditing && !_isLoading
          ? FloatingActionButton(
        onPressed: _startEditing,
        backgroundColor: culinaeBrown,
        foregroundColor: culinaeCream,
        child: const Icon(Icons.edit),
      )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: culinaeBrown))
          : Column(
        children: [
          if (!_isEditing && isMenuEmpty)
            const Expanded(
              child: Center(
                child: Text('Your menu is empty.\nTap the pen icon to add dishes!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  return _buildMenuRow(index);
                },
              ),
            ),
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _addNewItemRow,
                  icon: const Icon(Icons.add, color: culinaeBrown),
                  label: const Text('Add New Dish', style: TextStyle(color: culinaeBrown, fontSize: 16, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: culinaeBrown, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuRow(int index) {
    final item = _menuItems[index];

    if (!_isEditing) {
      if (item.nameController.text.isEmpty && item.priceController.text.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(item.nameController.text.isEmpty ? 'Unnamed Dish' : item.nameController.text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: culinaeBrown))),
            Text('Rs. ${item.priceController.text.isEmpty ? '0.00' : item.priceController.text}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: item.nameController,
              decoration: InputDecoration(hintText: 'Dish Name', filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextField(
              controller: item.priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(prefixText: 'Rs. ', prefixStyle: const TextStyle(color: culinaeBrown, fontWeight: FontWeight.bold), hintText: '0.00', filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
            ),
          ),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _removeRow(index)),
        ],
      ),
    );
  }
}