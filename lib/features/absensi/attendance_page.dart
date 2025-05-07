import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bakid/core/services/supabase_service.dart';

class AttendancePage extends StatefulWidget {
  final String userId;
  const AttendancePage({super.key, required this.userId});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _canAttend = false;
  String _statusMessage = 'Memeriksa lokasi dan waktu...';
  String _timeStatus = '';
  Position? _currentPosition;
  Map<String, dynamic>? _attendanceSettings;
  final supabase = Supabase.instance.client;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _checkAttendanceAvailability();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<void> _checkAttendanceAvailability() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _statusMessage = 'Lokasi tidak aktif. Aktifkan GPS.';
        _canAttend = false;
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _statusMessage = 'Izin lokasi ditolak.';
          _canAttend = false;
          return;
        }
      }

      _currentPosition = await Geolocator.getCurrentPosition();

      final settings =
          await SupabaseService.client
              .from('attendance_settings')
              .select()
              .eq('pesantren_id', widget.userId)
              .maybeSingle();

      if (settings == null) {
        _statusMessage = 'Setting absensi belum tersedia.';
        _canAttend = false;
        return;
      }

      _attendanceSettings = settings;
      final now = DateTime.now();
      final startTime = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(_parseTime(settings['start_time']));
      final endTime = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(_parseTime(settings['end_time']));

      if (now.isBefore(startTime)) {
        _timeStatus = 'Absensi dibuka pukul ${settings['start_time']}';
        _canAttend = false;
      } else if (now.isAfter(endTime)) {
        _timeStatus = 'Waktu absensi berakhir (${settings['end_time']})';
        _canAttend = false;
      } else {
        _timeStatus =
            'Waktu absensi: ${settings['start_time']} - ${settings['end_time']}';
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          settings['latitude'],
          settings['longitude'],
        );

        if (distance > settings['radius']) {
          _statusMessage =
              'Di luar radius absensi (${distance.toStringAsFixed(0)}m)';
          _canAttend = false;
        } else {
          _statusMessage = 'Anda bisa absen sekarang';
          _canAttend = true;
        }
      }
    } catch (e) {
      _statusMessage = 'Terjadi kesalahan: $e';
      _canAttend = false;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Duration _parseTime(String time) {
    final parts = time.split(":");
    return Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1]));
  }

  Future<void> _recordAttendance() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final startTime = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(_parseTime(_attendanceSettings!['start_time']));
      final status =
          now.difference(startTime) > const Duration(minutes: 15)
              ? 'late'
              : 'ontime';

      await SupabaseService.client.from('attendance_records').insert({
        'user_id': widget.userId,
        'status': status,
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Absensi berhasil')));

      setState(() {
        _canAttend = false;
        _statusMessage = 'Anda sudah absen hari ini';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal absen: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAttendance(bool isMonthly) async {
    final response = await supabase
        .from('attendance_records')
        .select()
        .eq('user_id', widget.userId)
        .order('attendance_time', ascending: false);
    final allData = List<Map<String, dynamic>>.from(response);
    return isMonthly
        ? _groupBy(allData, 'yyyy-MM')
        : _groupBy(allData, 'yyyy-MM-dd');
  }

  List<Map<String, dynamic>> _groupBy(
    List<Map<String, dynamic>> records,
    String format,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var r in records) {
      final key = DateFormat(
        format,
      ).format(DateTime.parse(r['attendance_time']));
      grouped.putIfAbsent(key, () => []).add(r);
    }
    return grouped.entries
        .map((e) => {'date': e.key, 'records': e.value})
        .toList();
  }

  Widget _buildAttendanceInfo() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Card(
          color: Colors.grey.shade200, // Warna abu muda pada Card
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  _timeStatus,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: _canAttend ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: CircularProgressIndicator(),
          )
        else if (_canAttend)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ElevatedButton(
              onPressed: _recordAttendance,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // Warna tombol biru
              ),
              child: const Text('Absen Sekarang'),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryTab(bool isMonthly) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchAttendance(isMonthly),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (_, i) {
            final item = data[i];
            final records = List<Map<String, dynamic>>.from(item['records']);
            return ExpansionTile(
              title: Text('Tanggal: ${item['date']}'),
              subtitle: Text('Total absen: ${records.length}'),
              children:
                  records
                      .map(
                        (r) => ListTile(
                          title: Text('Status: ${r['status']}'),
                          subtitle: Text(
                            'Waktu: ${DateFormat("HH:mm:ss").format(DateTime.parse(r['attendance_time']))}',
                          ),
                        ),
                      )
                      .toList(),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Colors.white;
    final textColor = Colors.black;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 1,
          centerTitle: true,
          title: Text('Absensi', style: TextStyle(color: textColor)),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.blue,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.check_circle_outline), text: 'Absen'),
              Tab(icon: Icon(Icons.history), text: 'Harian'),
              Tab(icon: Icon(Icons.calendar_view_month), text: 'Bulanan'),
            ],
          ),
        ),
        body: Container(
          color: bgColor, // Latar belakang putih untuk body
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAttendanceInfo(),
              _buildHistoryTab(false),
              _buildHistoryTab(true),
            ],
          ),
        ),
      ),
    );
  }
}
