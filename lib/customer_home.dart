import 'package:flutter/material.dart';

// Make sure these paths match your actual file structure!
import 'map_tab.dart';
import 'profile_page.dart';
import 'feed.dart';
import 'customer_orders.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  int _currentIndex = 0;

  // 1. Create a unique navigation "Key" for each tab.
  // This allows each tab to push and pop its own pages without hiding the bottom bar!
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  // 2. The base screens for each tab
  final List<Widget> _pages = [
    const FeedPage(),
    const MapTab(),
    const CustomerOrdersTab(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    // WillPopScope ensures that if an Android user hits their physical back button,
    // it goes back inside the current tab rather than instantly closing the app!
    return WillPopScope(
      onWillPop: () async {
        final currentNavigator = _navigatorKeys[_currentIndex].currentState;

        // If the current tab has pages to go back to (like a public profile), go back.
        if (currentNavigator != null && currentNavigator.canPop()) {
          currentNavigator.pop();
          return false;
        }

        // If they are on a different tab and hit back, take them back to the Home/Feed tab
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return false;
        }

        // If they are on the Home tab and can't go back any further, let them exit the app.
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF4A1F1F),

        // 3. IndexedStack keeps all tabs alive in the background.
        // This is what stops the Feed from resetting to the top when you switch tabs!
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
            // PRO UX TRICK: If they tap the tab they are already on, scroll them back to the root page!
            if (_currentIndex == index) {
              _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
            } else {
              setState(() => _currentIndex = index);
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFFFFF3E3),
          selectedItemColor: const Color(0xFF4A1F1F),
          unselectedItemColor: Colors.brown.shade300,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Map'),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_rounded), label: 'Orders'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}