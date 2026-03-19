import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class OwnerOrdersTab extends StatefulWidget {
  const OwnerOrdersTab({super.key});

  @override
  State<OwnerOrdersTab> createState() => _OwnerOrdersTabState();
}

class _OwnerOrdersTabState extends State<OwnerOrdersTab> {
  static const Color culinaeBrown = Color(0xFF4A1F1F);
  static const Color culinaeCream = Color(0xFFFFF3E3);

  // --- Change Order Status ---
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': newStatus,
      });
    } catch (e) {
      debugPrint("Error updating order: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: culinaeCream,
      appBar: AppBar(
        backgroundColor: culinaeCream,
        elevation: 0,
        title: const Text('Live Orders 🔔', style: TextStyle(color: culinaeBrown, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: myUid == null
          ? const Center(child: Text("Please log in."))
          : StreamBuilder<QuerySnapshot>(
        // NOTE: Removed .orderBy() to prevent invisible index crashes! We sort locally below.
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('storeId', isEqualTo: myUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: culinaeBrown));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: Colors.black26),
                  SizedBox(height: 16),
                  Text('No active orders.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          // --- Sort locally to ensure newest orders are at the top ---
          final List<DocumentSnapshot> orders = snapshot.data!.docs.toList();
          orders.sort((a, b) {
            final timeA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final timeB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (timeA == null && timeB == null) return 0;
            if (timeA == null) return 1;
            if (timeB == null) return -1;
            return timeB.compareTo(timeA); // Descending order
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final orderDoc = orders[index];
              final data = orderDoc.data() as Map<String, dynamic>;
              final String status = data['status'] ?? 'pending';
              final String customerName = data['customerName'] ?? 'Customer';
              final List<dynamic> items = data['items'] ?? [];
              final Timestamp? timestamp = data['timestamp'] as Timestamp?;

              String timeFormatted = '';
              if (timestamp != null) {
                timeFormatted = DateFormat('h:mm a').format(timestamp.toDate());
              }

              // Card Colors based on the new extended status flow
              Color cardBorder = Colors.grey.shade300;
              if (status == 'pending') cardBorder = Colors.orangeAccent;
              if (status == 'accepted') cardBorder = Colors.blueAccent; // Waiting for payment
              if (status == 'paid') cardBorder = Colors.green; // Ready to cook!
              if (status == 'rejected') cardBorder = Colors.redAccent;
              if (status == 'completed') cardBorder = Colors.grey;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: cardBorder, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Customer & Time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order from: $customerName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: culinaeBrown)),
                          Text(timeFormatted, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      const Divider(),

                      // The Items List
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

                      // --- Dynamic Action Buttons based on the Extended Status Flow! ---
                      if (status == 'pending')
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _updateOrderStatus(orderDoc.id, 'rejected'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                child: const Text('Decline'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _updateOrderStatus(orderDoc.id, 'accepted'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                                child: const Text('Accept Order', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ],
                        )
                      else if (status == 'accepted')
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue)),
                              SizedBox(width: 12),
                              Text('Waiting for customer payment...', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      else if (status == 'paid')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _updateOrderStatus(orderDoc.id, 'completed'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12)),
                              child: const Text('MARK AS COMPLETED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                            ),
                          )
                        else if (status == 'completed')
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                              child: const Center(child: Text('Order Completed ✅', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold))),
                            )
                          else if (status == 'rejected')
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: const Center(child: Text('Order Declined ❌', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                              )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}