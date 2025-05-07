import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bakid/core/services/supabase_service.dart';

class AizinAsatidPage extends StatefulWidget {
  const AizinAsatidPage({super.key});

  @override
  State<AizinAsatidPage> createState() => _AizinAsatidPageState();
}

class _AizinAsatidPageState extends State<AizinAsatidPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _alasanController = TextEditingController();
  String? _jenisIzin;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _riwayatIzin = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRiwayatIzin();
  }

  @override
  void dispose() {
    _alasanController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<String?> _getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  Future<void> _submitIzin() async {
    if (!_formKey.currentState!.validate() || _jenisIzin == null) return;

    setState(() => _isSubmitting = true);
    try {
      final userId = await _getStoredUserId();
      if (userId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User ID tidak ditemukan.')),
        );
        return;
      }

      await SupabaseService.client.from('perizinan_asatid').insert({
        'user_id': userId,
        'jenis_izin': _jenisIzin, // ✅ ENUM harus sesuai database
        'alasan': _alasanController.text.trim(),
        'tanggal_permohonan': DateTime.now().toIso8601String(),
        'status': 'menunggu',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permohonan izin berhasil diajukan')),
      );

      _alasanController.clear();
      setState(() => _jenisIzin = null);
      await _fetchRiwayatIzin();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _fetchRiwayatIzin() async {
    try {
      final userId = await _getStoredUserId();
      if (userId == null) return;

      final response = await SupabaseService.client
          .from('perizinan_asatid')
          .select()
          .eq('user_id', userId)
          .order('tanggal_permohonan', ascending: false);

      if (!mounted) return;
      setState(() {
        _riwayatIzin = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil riwayat izin: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.grey[100],
            foregroundColor: Colors.black,
            elevation: 1,
            title: const Text('Izin'),
            centerTitle: true,
            pinned: true, // Agar app bar tetap di atas saat scroll
            floating: false,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.blue,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(icon: Icon(Icons.add_box), text: 'Ajukan Izin'),
                Tab(icon: Icon(Icons.history), text: 'Riwayat Izin'),
              ],
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TabBarView(
                controller: _tabController,
                children: [_buildFormIzin(), _buildRiwayatIzin()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormIzin() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            DropdownButtonFormField<String>(
              value: _jenisIzin,
              hint: const Text('Pilih Jenis Izin'),
              items: const [
                DropdownMenuItem(
                  value: 'keluar',
                  child: Text('Keluar Pesantren'),
                ),
                DropdownMenuItem(value: 'pulang', child: Text('Pulang')),
                DropdownMenuItem(
                  value: 'tidak_mengajar',
                  child: Text('Tidak Mengajar'),
                ),
              ],
              onChanged: (value) => setState(() => _jenisIzin = value),
              validator:
                  (value) => value == null ? 'Jenis izin harus dipilih' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _alasanController,
              decoration: const InputDecoration(
                labelText: 'Alasan',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator:
                  (value) => value!.isEmpty ? 'Alasan harus diisi' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitIzin,
                icon: const Icon(Icons.send, color: Colors.white),
                label: Text(
                  _isSubmitting ? 'Mengirim...' : 'Ajukan Izin',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiwayatIzin() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child:
          _riwayatIzin.isEmpty
              ? const Center(
                child: Text(
                  'Belum ada riwayat izin.',
                  style: TextStyle(fontSize: 16),
                ),
              )
              : ListView.builder(
                itemCount: _riwayatIzin.length,
                itemBuilder: (context, index) {
                  final izin = _riwayatIzin[index];
                  final tanggal =
                      DateTime.tryParse(
                        izin['tanggal_permohonan'] ?? '',
                      )?.toLocal().toString().split(' ')[0] ??
                      'Tanggal tidak valid';

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_note, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              izin['jenis_izin']
                                      ?.toString()
                                      .replaceAll('_', ' ')
                                      .toUpperCase() ??
                                  '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tanggal: $tanggal',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Status: ${izin['status'] ?? '-'}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                izin['status'] == 'disetujui'
                                    ? Colors.green
                                    : izin['status'] == 'ditolak'
                                    ? Colors.red
                                    : Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Alasan:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          izin['alasan'] ?? '-',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
