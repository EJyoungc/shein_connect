import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../utils/app_theme.dart';
import 'admin/admin_dashboard_screen.dart';
import 'browser/browser_screen.dart';
import 'cart/cart_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final isAdmin = authService.isAdmin;

    final List<Widget> screens = isAdmin
        ? [
            const AdminDashboardScreen(),
            const BrowserScreen(),
            DashboardScreen(
              onBrowseShein: () => _switchTab(1),
              onViewCart: () => _switchTab(3),
            ),
            CartScreen(onBrowseSheinPressed: () => _switchTab(1)),
            const ProfileScreen(),
          ]
        : [
            DashboardScreen(
              onBrowseShein: () => _switchTab(1),
              onViewCart: () => _switchTab(2),
            ),
            const BrowserScreen(),
            CartScreen(onBrowseSheinPressed: () => _switchTab(1)),
            const ProfileScreen(),
          ];

    // Ensure _currentIndex is within bounds if role changes
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    final List<NavigationDestination> destinations = isAdmin
        ? [
            const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings, color: AppTheme.sheinCoral),
              label: 'Admin Hub',
            ),
            const NavigationDestination(
              icon: Icon(Icons.travel_explore_outlined),
              selectedIcon: Icon(Icons.travel_explore, color: AppTheme.sheinCoral),
              label: 'Shein Browser',
            ),
            const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront, color: AppTheme.sheinCoral),
              label: 'Shop View',
            ),
            NavigationDestination(
              icon: Consumer<CartService>(
                builder: (context, cart, child) {
                  return Badge(
                    label: Text('${cart.itemCount}'),
                    isLabelVisible: cart.itemCount > 0,
                    backgroundColor: AppTheme.sheinCoral,
                    child: const Icon(Icons.shopping_bag_outlined),
                  );
                },
              ),
              selectedIcon: Consumer<CartService>(
                builder: (context, cart, child) {
                  return Badge(
                    label: Text('${cart.itemCount}'),
                    isLabelVisible: cart.itemCount > 0,
                    backgroundColor: AppTheme.sheinCoral,
                    child: const Icon(Icons.shopping_bag, color: AppTheme.sheinCoral),
                  );
                },
              ),
              label: 'Cart',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppTheme.sheinCoral),
              label: 'Profile',
            ),
          ]
        : [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: AppTheme.sheinCoral),
              label: 'Dashboard',
            ),
            const NavigationDestination(
              icon: Icon(Icons.travel_explore_outlined),
              selectedIcon: Icon(Icons.travel_explore, color: AppTheme.sheinCoral),
              label: 'Shein Browser',
            ),
            NavigationDestination(
              icon: Consumer<CartService>(
                builder: (context, cart, child) {
                  return Badge(
                    label: Text('${cart.itemCount}'),
                    isLabelVisible: cart.itemCount > 0,
                    backgroundColor: AppTheme.sheinCoral,
                    child: const Icon(Icons.shopping_bag_outlined),
                  );
                },
              ),
              selectedIcon: Consumer<CartService>(
                builder: (context, cart, child) {
                  return Badge(
                    label: Text('${cart.itemCount}'),
                    isLabelVisible: cart.itemCount > 0,
                    backgroundColor: AppTheme.sheinCoral,
                    child: const Icon(Icons.shopping_bag, color: AppTheme.sheinCoral),
                  );
                },
              ),
              label: 'Local Cart',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppTheme.sheinCoral),
              label: 'Profile',
            ),
          ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 1.0),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _switchTab,
          backgroundColor: Colors.white,
          indicatorColor: AppTheme.sheinCoralLight,
          elevation: 0,
          destinations: destinations,
        ),
      ),
    );
  }
}
