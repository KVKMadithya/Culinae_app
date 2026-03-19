import 'package:flutter/material.dart';
import 'menu.dart';
import 'owner_profile.dart';
import 'feed.dart';
import 'owner_orders.dart'; // <-- Perfectly linked to your real orders page!

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  int _currentIndex = 0;

  // 1. Create a unique navigation "Key" for each of the 5 tabs.
  // This keeps the bottom bar visible when pushing new pages!
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  // 2. The 5 Tabs for the Store Owner
  final List<Widget> _pages = [
    const FeedPage(),
    const OwnerMenuPage(),
    const OwnerOrdersTab(), // <-- The real Live Orders dashboard!
    const OwnerMapTab(),
    const OwnerProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    // WillPopScope handles the Android back button smoothly without closing the app
    return WillPopScope(
      onWillPop: () async {
        final currentNavigator = _navigatorKeys[_currentIndex].currentState;

        // If the current tab has pages to go back to, go back.
        if (currentNavigator != null && currentNavigator.canPop()) {
          currentNavigator.pop();
          return false;
        }

        // If they are on a different tab, jump back to the Feed tab
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return false;
        }

        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF4A1F1F), // Culinae Dark Brown

        // 3. IndexedStack keeps all tabs alive so they don't reset when switching!
        body: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: List.generate(_pages.length, (index) {
              return Navigator(
                key: _navigatorKeys[index],
                onGenerateRoute: (settings) {
                  return MaterialPageRoute(
                    builder: (context) => _pages[index],
                  );
                },
              );
            }),
          ),
        ),

        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            // PRO UX TRICK: Tap the active tab again to scroll back to the top/root page!
            if (_currentIndex == index) {
              _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
            } else {
              setState(() => _currentIndex = index);
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFFFFF3E3), // Culinae Cream
          selectedItemColor: const Color(0xFF4A1F1F),
          unselectedItemColor: Colors.brown.shade300,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 10,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dynamic_feed_rounded), label: 'Feed'),
            BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu_rounded), label: 'Menu'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
            BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Map'),
            BottomNavigationBarItem(icon: Icon(Icons.storefront_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

/* =========================
   OWNER PLACEHOLDER TABS
   ========================= */

// (The OwnerOrdersTab placeholder was deleted because you built the real one!)

class OwnerMapTab extends StatelessWidget {
  const OwnerMapTab({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Store Map Location 📍\n(Coming Soon)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 18)),
    );
  }
}