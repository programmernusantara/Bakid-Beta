import 'package:flutter/material.dart';
import 'package:bakid/core/services/supabase_service.dart';

class ProfilePage extends StatefulWidget {
  final String userId;
  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchProfile();
  }

  Future<Map<String, dynamic>?> _fetchProfile() async {
    try {
      return await SupabaseService.client
          .from('profil_asatid')
          .select()
          .eq('user_id', widget.userId)
          .maybeSingle();
    } catch (e) {
      throw Exception('Gagal memuat profil: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Latar belakang putih
      appBar: AppBar(
        title: const Text('Profil', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.grey[100], // Navbar putih
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.blue), // Ikon biru
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                'Profil tidak ditemukan',
                style: TextStyle(color: Colors.black87),
              ),
            );
          }

          final data = snapshot.data!;
          return _buildProfile(data);
        },
      ),
    );
  }

  Widget _buildProfile(Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          if (data['foto_profil'] != null)
            CircleAvatar(
              radius: 60,
              backgroundImage: NetworkImage(data['foto_profil']),
              backgroundColor: Colors.grey[200],
            )
          else
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
          const SizedBox(height: 24),
          _buildProfileCard(data),
        ],
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> data) {
    return Card(
      elevation: 2,
      color: Colors.grey[100], // Card abu muda
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInfoRow('Nama', data['nama'], Icons.person),
            const Divider(),
            _buildInfoRow('Alamat', data['alamat'] ?? '-', Icons.location_on),
            const Divider(),
            _buildInfoRow(
              'No. Telepon',
              data['no_telepon'] ?? '-',
              Icons.phone,
            ),
            const Divider(),
            _buildInfoRow('Daerah', data['daerah'] ?? '-', Icons.public),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue), // Ikon sesuai dengan data
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
