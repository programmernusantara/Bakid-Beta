import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:bakid/core/services/supabase_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class AbsensiAsatidPage extends StatefulWidget {
  const AbsensiAsatidPage({super.key});

  @override
  State<AbsensiAsatidPage> createState() => _AbsensiAsatidPageState();
}

class _AbsensiAsatidPageState extends State<AbsensiAsatidPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _jadwalHariIni = [];
  List<Map<String, dynamic>> _riwayatAbsensi = [];
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  bool _isLoadingJadwal = false;
  bool _isLoadingRiwayat = false;
  bool _isSubmitting = false;
  late TabController _tabController;

  // Warna yang konsisten
  final colorPrimary = Colors.blue; // warna utama biru
  final bgColor = const Color(0xFFFFFFFF); // warna latar belakang putih
  final cardColor = Colors.grey[100]; // Card abu muda
  final textColor = const Color(0xFF333333); // warna teks utama

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeTimeZones();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeTimeZones() async {
    tz_data.initializeTimeZones();
    final location = tz.getLocation('Asia/Jakarta');
    tz.setLocalLocation(location);
  }

  Future<void> _loadData() async {
    await _getCurrentLocation();
    await _fetchJadwalHariIni();
    await _fetchRiwayatAbsensi();
  }

  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  Future<void> _getCurrentLocation() async {
    if (_isLoadingLocation) return;

    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Aktifkan layanan lokasi untuk melakukan absensi');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Izin lokasi diperlukan untuk absensi');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Izin lokasi ditolak permanen. Aktifkan di pengaturan');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _currentPosition = position);
    } catch (e) {
      debugPrint('Error getting location: $e');
      _showSnackBar('Gagal mendapatkan lokasi: ${e.toString()}');
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _fetchJadwalHariIni() async {
    if (_isLoadingJadwal) return;

    setState(() => _isLoadingJadwal = true);

    try {
      final now = tz.TZDateTime.now(tz.local);
      final startOfDay = tz.TZDateTime(tz.local, now.year, now.month, now.day);
      final endOfDay = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      );

      final response = await SupabaseService.client
          .from('jadwal_absensi')
          .select('''
            jadwal_id,
            nama_kegiatan,
            waktu_masuk_kelas,
            waktu_keluar_kelas,
            buffer_awal_absen,
            latitude,
            longitude,
            radius_meter,
            lokasi_absen
          ''')
          .gte('waktu_masuk_kelas', startOfDay.toUtc().toIso8601String())
          .lte('waktu_masuk_kelas', endOfDay.toUtc().toIso8601String())
          .order('waktu_masuk_kelas', ascending: true);

      setState(
        () => _jadwalHariIni = List<Map<String, dynamic>>.from(response),
      );
    } catch (e) {
      debugPrint('Error fetching jadwal: $e');
      _showSnackBar('Gagal memuat jadwal: ${e.toString()}');
    } finally {
      setState(() => _isLoadingJadwal = false);
    }
  }

  Future<void> _fetchRiwayatAbsensi() async {
    if (_isLoadingRiwayat) return;

    setState(() => _isLoadingRiwayat = true);

    try {
      final userId = await _getUserId();
      if (userId == null) return;

      final profilResponse =
          await SupabaseService.client
              .from('profil_asatid')
              .select('profil_id')
              .eq('user_id', userId)
              .maybeSingle();

      if (profilResponse == null || profilResponse['profil_id'] == null) {
        if (mounted) _showSnackBar('Profil asatid tidak ditemukan');
        return;
      }

      final profilId = profilResponse['profil_id'];

      final response = await SupabaseService.client
          .from('absensi_asatid')
          .select('''
            absensi_id,
            waktu_absen,
            status_absen,
            user_latitude,
            user_longitude,
            jadwal_absensi:jadwal_id (
              nama_kegiatan,
              waktu_masuk_kelas,
              waktu_keluar_kelas,
              lokasi_absen
            )
          ''')
          .eq('profil_id', profilId)
          .order('waktu_absen', ascending: false)
          .limit(30);

      setState(
        () => _riwayatAbsensi = List<Map<String, dynamic>>.from(response),
      );
    } catch (e) {
      debugPrint('Error fetching riwayat: $e');
      if (mounted) _showSnackBar('Gagal memuat riwayat: ${e.toString()}');
    } finally {
      setState(() => _isLoadingRiwayat = false);
    }
  }

  Future<bool> _checkAlreadyAbsen(String jadwalId) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return false;

      final profilResponse =
          await SupabaseService.client
              .from('profil_asatid')
              .select('profil_id')
              .eq('user_id', userId)
              .maybeSingle();

      if (profilResponse == null || profilResponse['profil_id'] == null) {
        return false;
      }

      final profilId = profilResponse['profil_id'];
      final now = tz.TZDateTime.now(tz.local);
      final startOfDay = tz.TZDateTime(tz.local, now.year, now.month, now.day);

      final response =
          await SupabaseService.client
              .from('absensi_asatid')
              .select()
              .eq('profil_id', profilId)
              .eq('jadwal_id', jadwalId)
              .gte('waktu_absen', startOfDay.toUtc().toIso8601String())
              .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error checking attendance: $e');
      return false;
    }
  }

  Future<void> _absen(String jadwalId) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final alreadyAbsen = await _checkAlreadyAbsen(jadwalId);
      if (alreadyAbsen) {
        _showSnackBar('Anda sudah melakukan absensi untuk jadwal ini hari ini');
        return;
      }

      if (_currentPosition == null) {
        _showSnackBar('Lokasi tidak ditemukan. Pastikan GPS aktif');
        return;
      }

      final userId = await _getUserId();
      if (userId == null) {
        _showSnackBar('Sesi habis, silakan login kembali');
        return;
      }

      final profilResponse =
          await SupabaseService.client
              .from('profil_asatid')
              .select('profil_id')
              .eq('user_id', userId)
              .maybeSingle();

      if (profilResponse == null || profilResponse['profil_id'] == null) {
        _showSnackBar('Profil asatid tidak ditemukan');
        return;
      }

      final profilId = profilResponse['profil_id'];
      final jadwalResponse =
          await SupabaseService.client
              .from('jadwal_absensi')
              .select('waktu_masuk_kelas')
              .eq('jadwal_id', jadwalId)
              .single();

      final waktuMulai = DateTime.parse(jadwalResponse['waktu_masuk_kelas']);
      final now = DateTime.now().toUtc();
      final status =
          now.isAfter(waktuMulai.add(const Duration(minutes: 15)))
              ? 'lambat'
              : 'hadir';

      await SupabaseService.client.from('absensi_asatid').insert({
        'jadwal_id': jadwalId,
        'profil_id': profilId,
        'user_latitude': _currentPosition!.latitude,
        'user_longitude': _currentPosition!.longitude,
        'status_absen': status,
        'waktu_absen': now.toIso8601String(),
        'tanggal_absen': now.toIso8601String().split('T')[0],
      });

      _showSnackBar('Absensi berhasil dicatat ($status)');
      await _fetchRiwayatAbsensi();
    } catch (e) {
      debugPrint('Error submitting attendance: $e');
      _showSnackBar('Gagal melakukan absensi: ${e.toString()}');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  bool _bisaAbsen(Map<String, dynamic> jadwal) {
    try {
      final now = tz.TZDateTime.now(tz.local);
      final waktuMulai = DateTime.parse(jadwal['waktu_masuk_kelas']).toLocal();
      final waktuSelesai =
          DateTime.parse(jadwal['waktu_keluar_kelas']).toLocal();
      final buffer = Duration(minutes: jadwal['buffer_awal_absen'] ?? 10);

      return now.isAfter(waktuMulai.subtract(buffer)) &&
          now.isBefore(waktuSelesai);
    } catch (e) {
      debugPrint('Error checking waktu absen: $e');
      return false;
    }
  }

  bool _dalamJarak(Map<String, dynamic> jadwal) {
    try {
      if (_currentPosition == null ||
          jadwal['latitude'] == null ||
          jadwal['longitude'] == null ||
          jadwal['radius_meter'] == null) {
        return false;
      }

      final jarak = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        (jadwal['latitude'] as num).toDouble(),
        (jadwal['longitude'] as num).toDouble(),
      );

      return jarak <= (jadwal['radius_meter'] as num).toDouble();
    } catch (e) {
      debugPrint('Error checking distance: $e');
      return false;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0, // Menghilangkan shadow
        centerTitle: true,
        title: Text(
          'Absensi Asatid',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorPrimary,
          labelColor: colorPrimary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(
              icon: Icon(Icons.fingerprint), // Ikon fingerprint untuk absensi
              text: 'Absensi',
            ),
            Tab(
              icon: Icon(
                Icons.assignment_turned_in,
              ), // Ikon checklist untuk riwayat
              text: 'Riwayat',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Absensi
          _buildAbsensiTab(),

          // Tab 2: Riwayat
          _buildRiwayatTab(),
        ],
      ),
    );
  }

  Widget _buildAbsensiTab() {
    if (_isLoadingJadwal || _isLoadingLocation) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5E81AC)),
        ),
      );
    }

    return _jadwalHariIni.isEmpty
        ? Center(
          child: Text(
            'Tidak ada jadwal absensi hari ini',
            style: TextStyle(color: textColor),
          ),
        )
        : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _jadwalHariIni.length,
          itemBuilder: (context, index) {
            final jadwal = _jadwalHariIni[index];
            final bisaAbsen = _bisaAbsen(jadwal);
            final dalamJarak = _dalamJarak(jadwal);
            final waktuMulai =
                DateTime.parse(jadwal['waktu_masuk_kelas']).toLocal();
            final waktuSelesai =
                DateTime.parse(jadwal['waktu_keluar_kelas']).toLocal();

            return Card(
              color: cardColor,
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 0, // Menghilangkan shadow
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            jadwal['nama_kegiatan'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        if (bisaAbsen)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'AKTIF',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.access_time,
                      '${DateFormat('HH:mm').format(waktuMulai)} - ${DateFormat('HH:mm').format(waktuSelesai)}',
                    ),
                    _buildInfoRow(
                      Icons.calendar_today,
                      DateFormat('EEEE, dd MMMM yyyy').format(waktuMulai),
                    ),
                    if (jadwal['lokasi_absen'] != null)
                      _buildInfoRow(Icons.location_on, jadwal['lokasi_absen']),
                    if (_currentPosition != null &&
                        jadwal['latitude'] != null &&
                        jadwal['longitude'] != null)
                      _buildInfoRow(
                        Icons.map,
                        'Jarak: ${Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, (jadwal['latitude'] as num).toDouble(), (jadwal['longitude'] as num).toDouble()).toStringAsFixed(1)}m (Radius: ${jadwal['radius_meter']}m)',
                        textColor: dalamJarak ? Colors.green : Colors.red,
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor:
                              bisaAbsen && dalamJarak
                                  ? colorPrimary
                                  : Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed:
                            !_isSubmitting && bisaAbsen && dalamJarak
                                ? () => _absen(jadwal['jadwal_id'])
                                : null,
                        child:
                            _isSubmitting
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text(
                                  'ABSEN SEKARANG',
                                  style: TextStyle(color: Colors.white),
                                ),
                      ),
                    ),
                    if (!dalamJarak)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Anda berada di luar radius yang ditentukan',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (!bisaAbsen)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Waktu absen: ${DateFormat('HH:mm').format(waktuMulai.subtract(Duration(minutes: jadwal['buffer_awal_absen'] ?? 10)))} - ${DateFormat('HH:mm').format(waktuSelesai)}',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
  }

  Widget _buildRiwayatTab() {
    if (_isLoadingRiwayat) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5E81AC)),
        ),
      );
    }

    return _riwayatAbsensi.isEmpty
        ? Center(
          child: Text(
            'Belum ada riwayat absensi',
            style: TextStyle(color: textColor),
          ),
        )
        : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _riwayatAbsensi.length,
          itemBuilder: (context, index) {
            final absensi = _riwayatAbsensi[index];
            final jadwal = absensi['jadwal_absensi'] ?? {};
            final waktuAbsen = DateTime.parse(absensi['waktu_absen']).toLocal();
            final waktuKegiatan =
                DateTime.parse(
                  jadwal['waktu_masuk_kelas'] ?? waktuAbsen.toString(),
                ).toLocal();
            final status = absensi['status_absen'];

            return Card(
              color: cardColor,
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 0, // Menghilangkan shadow
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            jadwal['nama_kegiatan'] ?? 'Kegiatan',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status?.toUpperCase() ?? 'UNKNOWN',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.calendar_today,
                      DateFormat('EEEE, dd MMMM yyyy').format(waktuKegiatan),
                    ),
                    _buildInfoRow(
                      Icons.access_time,
                      'Absen: ${DateFormat('HH:mm:ss').format(waktuAbsen)}',
                    ),
                    if (absensi['user_latitude'] != null &&
                        absensi['user_longitude'] != null)
                      _buildInfoRow(
                        Icons.location_pin,
                        'Lokasi: ${(absensi['user_latitude'] as num).toStringAsFixed(6)}, '
                        '${(absensi['user_longitude'] as num).toStringAsFixed(6)}',
                      ),
                  ],
                ),
              ),
            );
          },
        );
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor ?? Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'hadir':
        return Colors.green;
      case 'lambat':
        return Colors.orange;
      case 'alpa':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
