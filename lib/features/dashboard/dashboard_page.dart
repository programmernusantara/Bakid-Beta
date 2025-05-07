import 'package:bakid/features/jurnal/jurnal_page.dart';
import 'package:flutter/material.dart';
import 'package:bakid/features/absensi/attendance_page.dart';
import 'package:bakid/features/pengumuman/pengumuman_page.dart';
import 'package:bakid/features/perizinan/izin_asatid_page.dart';
import 'package:bakid/features/jadwal/schedule_page.dart';
import 'package:bakid/features/profile/profile_page.dart';

class DashboardPage extends StatefulWidget {
  final String userId;
  const DashboardPage({super.key, required this.userId});

  @override
  DashboardPageState createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isMenuOpen = false;
  int _selectedIndex = 0;

  final Color _buttonColor = Colors.white;
  final Color _iconColor = Colors.blueAccent;
  final double _iconSize = 20.0;

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.announcement, 'label': 'Pengumuman'},
    {'icon': Icons.fingerprint, 'label': 'Absensi'},
    {'icon': Icons.menu_book, 'label': 'Jurnal'},
    {'icon': Icons.assignment_turned_in, 'label': 'Izin'},
    {'icon': Icons.schedule, 'label': 'Jadwal'},
    {'icon': Icons.person, 'label': 'Profil'},
  ];

  late final List<Widget> _pages = [
    PengumumanPage(),
    AttendancePage(userId: widget.userId),
    JurnalPage(),
    const AizinAsatidPage(),
    SchedulePage(userId: widget.userId),
    ProfilePage(userId: widget.userId),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      _isMenuOpen ? _controller.forward() : _controller.reverse();
    });
  }

  void _navigateToPage(int index) {
    setState(() {
      _selectedIndex = index;
      _isMenuOpen = false;
      _controller.reverse();
    });
  }

  Widget _buildMenuButton(int index) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: FloatingActionButton(
            mini: true,
            heroTag: 'menu_$index',
            backgroundColor: _buttonColor,
            elevation: 2,
            onPressed: () => _navigateToPage(index),
            child: Icon(
              _menuItems[index]['icon'],
              color: _iconColor,
              size: _iconSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainButton() {
    return FloatingActionButton(
      mini: true,
      heroTag: 'main_button',
      backgroundColor: _buttonColor,
      elevation: 2,
      onPressed: _toggleMenu,
      child: Icon(
        _isMenuOpen ? Icons.close : Icons.menu,
        color: _iconColor,
        size: _iconSize,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isMenuOpen)
            ...List.generate(_menuItems.length, _buildMenuButton),
          const SizedBox(height: 8),
          _buildMainButton(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
