import 'package:flutter/material.dart';
import 'parent_dashboard.dart'; // Ensure this matches your filename
import 'profile_page.dart';
import 'attendance_page.dart';

class NavigationMenu extends StatefulWidget {
  const NavigationMenu({super.key});

  @override
  State<NavigationMenu> createState() => _NavigationMenuState();
}

class _NavigationMenuState extends State<NavigationMenu> {
  // Start at index 0 (The Dashboard)
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const ParentDashboard(), // The main hub with cards
    const AttendancePage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Keep the background consistent with your dashboard theme
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        elevation: 10,
        backgroundColor: Colors.white,
        indicatorColor: Colors.green.shade100,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Attendance',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}