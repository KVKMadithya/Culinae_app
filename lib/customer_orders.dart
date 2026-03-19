import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomerOrdersTab extends StatefulWidget {
  const CustomerOrdersTab({super.key});

  @override
  State<CustomerOrdersTab> createState() => _CustomerOrdersTabState();
}

class _CustomerOrdersTabState extends State<CustomerOrdersTab> {
  static const Color culinaeBrown = Color(0xFF4A1F1F);
  static const Color culinaeCream = Color(0xFFFFF3E3);

  // --- Remove Item from Cart ---
  Future<void> _removeFromCart(String cartItemId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cart')
        .doc(cartItemId)
        .delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item removed from cart'), duration: Duration(seconds: 1)),
      );
    }
  }

  // --- Real Firebase Order Function (Handles 1 or All) ---
  Future<void> _placeOrder(List<DocumentSnapshot> itemsToOrder) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || itemsToOrder.isEmpty) return;

    try {
      // 1. Fetch the customer's name
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final customerName = userDoc.data()?['name'] ?? userDoc.data()?['username'] ?? 'Customer';

      // 2. Group the cart items by Store ID
      Map<String, List<Map<String, dynamic>>> ordersByStore = {};
      for (var doc in itemsToOrder) {
        final item = doc.data() as Map<String, dynamic>;
        final storeId = item['storeId'] ?? 'unknown';
        if (!ordersByStore.containsKey(storeId)) {
          ordersByStore[storeId] = [];
        }
        ordersByStore[storeId]!.add(item);
      }

      // 3. Create a massive "Batch" to send orders and clear the cart simultaneously
      final batch = FirebaseFirestore.instance.batch();

      for (String storeId in ordersByStore.keys) {
        final orderRef = FirebaseFirestore.instance.collection('orders').doc();
        batch.set(orderRef, {
          'customerId': uid,
          'customerName': customerName,
          'storeId': storeId,
          'items': ordersByStore[storeId],
          'status': 'pending', // Starts as pending!
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // Delete the ordered items from the Customer's Cart
      for (var doc in itemsToOrder) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order sent to store! 🚀'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      debugPrint("Error placing order: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to place order.'), backgroundColor: Colors.red));
    }
  }

  // --- Payment Simulation ---
  Future<void> _payForOrder(String orderId) async {
    // Show a quick loading dialog to make the payment feel real
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: culinaeBrown)),
    );

    await Future.delayed(const Duration(seconds: 2)); // Fake processing time

    // Update status to Paid in Firebase
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'paid'
    });

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment Successful! Meal is being prepared. 🍽️'), backgroundColor: Colors.green)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text("Please log in to view orders.")));
    }

    return DefaultTabController(
      length: 2, // We now have TWO tabs: Cart and Active Orders!
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Your Orders 🛒', style: TextStyle(color: culinaeBrown, fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: culinaeBrown,
            unselectedLabelColor: Colors.grey,
            indicatorColor: culinaeBrown,
            tabs: [
              Tab(text: 'My Cart'),
              Tab(text: 'Track Orders'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCartView(uid),
            _buildTrackOrdersView(uid),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // VIEW 1: THE CART (Items ready to be ordered)
  // =========================================================================
  Widget _buildCartView(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('cart').orderBy('addedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: culinaeBrown));

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('Your cart is empty!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: culinaeBrown)),
                const SizedBox(height: 8),
                const Text('Go to the feed and add some delicious food.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final cartItems = snapshot.data!.docs;

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  final item = cartItems[index].data() as Map<String, dynamic>;
                  final itemId = cartItems[index].id;
                  final String price = item['price'] ?? 'Contact for info';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: item['imageUrl'] != ''
                                ? Image.network(item['imageUrl'], width: 70, height: 70, fit: BoxFit.cover)
                                : Container(width: 70, height: 70, color: Colors.grey, child: const Icon(Icons.fastfood, color: Colors.white)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['storeName'] ?? 'Store', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: culinaeBrown)),
                                const SizedBox(height: 4),
                                Text(item['caption'] ?? 'Dish', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87)),
                                const SizedBox(height: 4),
                                Text(price, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => _removeFromCart(itemId),
                              ),
                              ElevatedButton(
                                onPressed: () => _placeOrder([cartItems[index]]), // Order ONE by one!
                                style: ElevatedButton.styleFrom(backgroundColor: culinaeBrown, minimumSize: const Size(60, 30), padding: const EdgeInsets.symmetric(horizontal: 12)),
                                child: const Text('Order', style: TextStyle(color: Colors.white, fontSize: 12)),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Checkout ALL Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))]),
              child: SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () => _placeOrder(cartItems), // Order ALL at once!
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('ORDER ALL ITEMS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
                ),
              ),
            )
          ],
        );
      },
    );
  }

  // =========================================================================
  // VIEW 2: TRACK ORDERS (Sent to store, waiting for acceptance/payment)
  // =========================================================================
  Widget _buildTrackOrdersView(String uid) {
    return StreamBuilder<QuerySnapshot>(
      // Note: No orderBy here to prevent the invisible index error! We sort it locally below.
      stream: FirebaseFirestore.instance.collection('orders').where('customerId', isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: culinaeBrown));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("You have no active orders.", style: TextStyle(color: Colors.grey)));
        }

        // Locally sort the orders so newest is at the top
        final List<DocumentSnapshot> orders = snapshot.data!.docs.toList();
        orders.sort((a, b) {
          final timeA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          final timeB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (timeA == null && timeB == null) return 0;
          if (timeA == null) return 1;
          if (timeB == null) return -1;
          return timeB.compareTo(timeA);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final orderData = orders[index].data() as Map<String, dynamic>;
            final orderId = orders[index].id;
            final List<dynamic> items = orderData['items'] ?? [];
            final String storeName = items.isNotEmpty ? items[0]['storeName'] : 'Store';
            final String status = orderData['status'] ?? 'pending';

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order sent to: $storeName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: culinaeBrown)),
                    const Divider(),

                    ...items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            const Text('1x ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                            Expanded(child: Text(item['caption'] ?? 'Dish', maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text(item['price'] ?? '', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 16),

                    // --- Dynamic Status Display ---
                    if (status == 'pending')
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
                            SizedBox(width: 12),
                            Text('Waiting for store to accept...', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    else if (status == 'accepted')
                      SizedBox(
                        width: double.infinity, height: 45,
                        child: ElevatedButton(
                          onPressed: () => _payForOrder(orderId),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: const Text('PAY FOR MEAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ),
                      )
                    else if (status == 'rejected')
                        Container(
                          width: double.infinity, padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                          child: const Center(child: Text('Store declined order.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                        )
                      else if (status == 'paid')
                          Container(
                            width: double.infinity, padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                            child: const Center(child: Text('Paid! Preparing your meal 🍳', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                          )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}