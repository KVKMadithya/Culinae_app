import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'main.dart'; // To route back to AuthWrapper on logout

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _currentIndex = 0;

  static const Color culinaeBrown = Color(0xFF4A1F1F);
  static const Color culinaeCream = Color(0xFFFFF3E3);

  final List<Widget> _pages = [
    const AdminDashboardTab(),
    const AdminUsersManagerTab(),
    const AdminStaffTab(),
    const AdminReportsTab(),
  ];

  Future<void> _logout() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: culinaeBrown),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
              (route) => false,
        );
      }
    }
  }

  // --- Handle Menu Selection ---
  void _handleMenuSelection(String value) {
    if (value == 'logout') {
      _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: culinaeBrown,
        title: const Text('Culinae Admin HQ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          // --- UPDATED: The Three-Dots Menu! ---
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: _handleMenuSelection,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                      children: [
                        Icon(Icons.logout, color: culinaeBrown),
                        SizedBox(width: 8),
                        Text('Logout')
                      ]
                  )
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        selectedItemColor: culinaeBrown,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Overview'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admins'),
          BottomNavigationBarItem(icon: Icon(Icons.flag), label: 'Reports'),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 1: OVERVIEW DASHBOARD (Quick Stats)
// ============================================================================
class AdminDashboardTab extends StatelessWidget {
  const AdminDashboardTab({super.key});
  static const Color culinaeBrown = Color(0xFF4A1F1F);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, userSnapshot) {
        int customerCount = 0;
        int ownerCount = 0;

        if (userSnapshot.hasData) {
          for (var doc in userSnapshot.data!.docs) {
            final role = (doc.data() as Map<String, dynamic>)['role'];
            if (role == 'customer') customerCount++;
            if (role == 'owner') ownerCount++;
          }
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Platform Health', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: culinaeBrown)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _StatCard(title: 'Customers', count: customerCount, icon: Icons.person, color: Colors.green)),
                  const SizedBox(width: 16),
                  Expanded(child: _StatCard(title: 'Stores', count: ownerCount, icon: Icons.storefront, color: Colors.blueAccent)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.count, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Column(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 12),
          Text(count.toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 2: CATEGORIZED USER MANAGEMENT
// ============================================================================
class AdminUsersManagerTab extends StatelessWidget {
  const AdminUsersManagerTab({super.key});
  static const Color culinaeBrown = Color(0xFF4A1F1F);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: culinaeBrown,
            unselectedLabelColor: Colors.grey,
            indicatorColor: culinaeBrown,
            tabs: [
              Tab(text: 'Customers'),
              Tab(text: 'Store Owners'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _UserList(roleFilter: 'customer'),
                _UserList(roleFilter: 'owner'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  final String roleFilter;
  const _UserList({required this.roleFilter});

  void _openEditUserModal(BuildContext context, DocumentSnapshot userDoc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _EditUserModal(userDoc: userDoc),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: roleFilter).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text("No ${roleFilter}s found."));

        final users = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final data = users[index].data() as Map<String, dynamic>;
            final name = roleFilter == 'owner' ? (data['storeName'] ?? 'Unnamed Store') : (data['name'] ?? data['username'] ?? 'Unnamed User');
            final email = data['email'] ?? 'No email';
            final isBanned = data['isBanned'] == true;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isBanned ? Colors.red.shade100 : Colors.grey.shade200,
                  child: Icon(roleFilter == 'owner' ? Icons.storefront : Icons.person, color: isBanned ? Colors.red : Colors.black54),
                ),
                title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, decoration: isBanned ? TextDecoration.lineThrough : null)),
                subtitle: Text(email),
                trailing: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                onTap: () => _openEditUserModal(context, users[index]),
              ),
            );
          },
        );
      },
    );
  }
}

class _EditUserModal extends StatefulWidget {
  final DocumentSnapshot userDoc;
  const _EditUserModal({required this.userDoc});

  @override
  State<_EditUserModal> createState() => _EditUserModalState();
}

class _EditUserModalState extends State<_EditUserModal> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  bool _isBanned = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.userDoc.data() as Map<String, dynamic>;
    final role = data['role'] ?? 'customer';

    final initialName = role == 'owner' ? (data['storeName'] ?? '') : (data['name'] ?? data['username'] ?? '');

    _nameController = TextEditingController(text: initialName);
    _bioController = TextEditingController(text: data['bio'] ?? '');
    _isBanned = data['isBanned'] == true;
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    final data = widget.userDoc.data() as Map<String, dynamic>;
    final role = data['role'] ?? 'customer';

    Map<String, dynamic> updates = {
      'bio': _bioController.text.trim(),
      'isBanned': _isBanned,
    };

    if (role == 'owner') {
      updates['storeName'] = _nameController.text.trim();
    } else {
      updates['name'] = _nameController.text.trim();
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userDoc.id).update(updates);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error updating user: $e");
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Edit User Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Divider(),
          const SizedBox(height: 12),

          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Display Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _bioController,
            decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('Ban User Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            subtitle: const Text('This will block them from logging in.'),
            activeColor: Colors.red,
            value: _isBanned,
            onChanged: (val) => setState(() => _isBanned = val),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A1F1F)),
              child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE CHANGES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 3: NEW! ADMIN TEAM MANAGEMENT (Search & Promote)
// ============================================================================
class AdminStaffTab extends StatefulWidget {
  const AdminStaffTab({super.key});

  @override
  State<AdminStaffTab> createState() => _AdminStaffTabState();
}

class _AdminStaffTabState extends State<AdminStaffTab> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  static const Color culinaeBrown = Color(0xFF4A1F1F);

  Future<void> _updateUserRole(String userId, String newRole) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({'role': newRole});
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      children: [
        // 1. The Search Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search email or name to promote...',
              prefixIcon: const Icon(Icons.search, color: culinaeBrown),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = "");
                  FocusScope.of(context).unfocus();
                },
              )
                  : null,
            ),
          ),
        ),

        // 2. The Dynamic List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: culinaeBrown));

              final allUsers = snapshot.data!.docs;

              // If NOT searching, show current Admins
              if (_searchQuery.isEmpty) {
                final currentAdmins = allUsers.where((doc) => (doc.data() as Map<String, dynamic>)['role'] == 'admin').toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('Current Admins', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: currentAdmins.length,
                        itemBuilder: (context, index) {
                          final data = currentAdmins[index].data() as Map<String, dynamic>;
                          final docId = currentAdmins[index].id;
                          final name = data['name'] ?? 'Admin';

                          return ListTile(
                            leading: const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.admin_panel_settings, color: Colors.white)),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(data['email'] ?? ''),
                            // Prevent the admin from accidentally demoting themselves
                            trailing: docId == myUid
                                ? const Text('YOU', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold))
                                : TextButton(
                              onPressed: () => _updateUserRole(docId, 'customer'),
                              child: const Text('Demote', style: TextStyle(color: Colors.red)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }

              // If SEARCHING, show matching regular users to promote
              final searchResults = allUsers.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['name'] ?? data['storeName'] ?? data['username'] ?? '').toString().toLowerCase();
                final email = (data['email'] ?? '').toString().toLowerCase();
                final role = data['role'] ?? 'customer';

                // Only show non-admins that match the search
                return role != 'admin' && (name.contains(_searchQuery) || email.contains(_searchQuery));
              }).toList();

              if (searchResults.isEmpty) {
                return const Center(child: Text('No users found.'));
              }

              return ListView.builder(
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final data = searchResults[index].data() as Map<String, dynamic>;
                  final docId = searchResults[index].id;
                  final name = data['name'] ?? data['storeName'] ?? 'User';

                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white)),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(data['email'] ?? ''),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                      onPressed: () => _updateUserRole(docId, 'admin'),
                      child: const Text('Promote', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }
}

// ============================================================================
// TAB 4: REPORT HANDLING
// ============================================================================
class AdminReportsTab extends StatelessWidget {
  const AdminReportsTab({super.key});
  static const Color culinaeBrown = Color(0xFF4A1F1F);

  Future<void> _markResolved(String reportId) async {
    await FirebaseFirestore.instance.collection('reports').doc(reportId).update({'status': 'resolved'});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Only show pending reports that need attention!
      stream: FirebaseFirestore.instance.collection('reports').where('status', isEqualTo: 'pending').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: culinaeBrown));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Hooray! No pending reports.", style: TextStyle(fontSize: 16, color: Colors.grey)));
        }

        final reports = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final data = reports[index].data() as Map<String, dynamic>;
            final reason = data['reason'] ?? 'No reason provided';
            final reportedBy = data['reportedBy'] ?? 'Unknown User';
            final type = data['type'] ?? 'General';

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.redAccent)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                          child: Text('Type: $type', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        Text('By: $reportedBy', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('"$reason"', style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _markResolved(reports[index].id),
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        label: const Text('Mark as Resolved', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green)),
                      ),
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