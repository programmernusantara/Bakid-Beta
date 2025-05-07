import 'package:bakid/core/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart'; // pastikan ditambahkan pada pubspec.yaml

class SchedulePage extends StatefulWidget {
  final String userId;

  const SchedulePage({super.key, required this.userId});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late Future<List<Map<String, dynamic>>> _jadwalFuture;

  @override
  void initState() {
    super.initState();
    _jadwalFuture = _fetchJadwal();
  }

  Future<List<Map<String, dynamic>>> _fetchJadwal() async {
    try {
      final data = await SupabaseService.client
          .from('jadwal_asatid')
          .select()
          .eq('user_id', widget.userId)
          .order('jam_mulai', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Gagal mengambil jadwal: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Jadwal', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.grey[100],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.blue),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _jadwalFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final jadwalList = snapshot.data ?? [];
          if (jadwalList.isEmpty) {
            return const Center(child: Text('Tidak ada jadwal'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: jadwalList.length,
            itemBuilder: (context, index) {
              return _buildJadwalCard(jadwalList[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildJadwalCard(Map<String, dynamic> jadwal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          _buildRow(
            icon: LucideIcons.bookOpen,
            label: 'Pelajaran',
            value: jadwal['pelajaran'],
          ),
          const SizedBox(height: 12),
          _buildRow(
            icon: LucideIcons.users,
            label: 'Kelas',
            value: jadwal['kelas'],
          ),
          const SizedBox(height: 12),
          _buildRow(
            icon: LucideIcons.calendar,
            label: 'Hari',
            value: jadwal['hari'],
          ),
          const SizedBox(height: 12),
          _buildRow(
            icon: LucideIcons.clock,
            label: 'Jam',
            value: '${jadwal['jam_mulai']} - ${jadwal['jam_selesai']}',
          ),
        ],
      ),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.blue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
