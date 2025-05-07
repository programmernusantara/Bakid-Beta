import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bakid/core/services/supabase_service.dart';

class JurnalPage extends StatefulWidget {
  const JurnalPage({super.key});

  @override
  State<JurnalPage> createState() => _JurnalPageState();
}

class _JurnalPageState extends State<JurnalPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();
  File? _selectedImage;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _riwayatJurnal = [];
  late TabController _tabController;

  final colorPrimary = const Color(0xFF5E81AC); // warna utama biru
  final bgColor = const Color(0xFFFFFFFF); // warna latar belakang putih
  final cardColor = Colors.grey[100]; // Card abu muda
  final textColor = const Color(0xFF333333); // warna teks utama

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRiwayatJurnal();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<String?> _getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _submitJurnal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final userId = await _getStoredUserId();
    if (!mounted) return;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID tidak ditemukan. Silakan login kembali'),
        ),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    String? imageUrl;
    if (_selectedImage != null) {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final fileExt = _selectedImage!.path.split('.').last;
      final filePath = 'jurnal/$fileName.$fileExt';

      await SupabaseService.client.storage
          .from('jurnal')
          .upload(filePath, _selectedImage!);
      imageUrl = SupabaseService.client.storage
          .from('jurnal')
          .getPublicUrl(filePath);
    }

    try {
      await SupabaseService.client.from('jurnal_asatid').insert({
        'user_id': userId,
        'judul': _judulController.text.trim(),
        'deskripsi': _deskripsiController.text.trim(),
        'tanggal': DateTime.now().toIso8601String(),
        'gambar_url': imageUrl,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Jurnal berhasil dikirim')));

      _judulController.clear();
      _deskripsiController.clear();
      setState(() => _selectedImage = null);
      await _fetchRiwayatJurnal();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengirim jurnal: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _fetchRiwayatJurnal() async {
    final userId = await _getStoredUserId();
    if (userId == null || !mounted) return;

    try {
      final response = await SupabaseService.client
          .from('jurnal_asatid')
          .select()
          .eq('user_id', userId)
          .order('tanggal', ascending: false);

      if (mounted) {
        setState(
          () => _riwayatJurnal = List<Map<String, dynamic>>.from(response),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil data jurnal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 1,
        centerTitle: true,
        title: Text('Jurnal', style: TextStyle(color: textColor)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note), text: 'Buat Jurnal'),
            Tab(icon: Icon(Icons.history), text: 'Riwayat Jurnal'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Buat Jurnal
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _judulController,
                    decoration: const InputDecoration(
                      labelText: 'Judul Jurnal',
                      border: OutlineInputBorder(),
                    ),
                    validator:
                        (value) => value!.isEmpty ? 'Judul harus diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _deskripsiController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi',
                      border: OutlineInputBorder(),
                    ),
                    validator:
                        (value) =>
                            value!.isEmpty ? 'Deskripsi harus diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  if (_selectedImage != null)
                    Image.file(_selectedImage!, height: 150),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(
                      Icons.image,
                      color: Colors.white,
                    ), // Warna ikon putih
                    label: const Text(
                      'Pilih Gambar',
                      style: TextStyle(
                        color: Colors.white,
                      ), // Teks tombol berwarna putih
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue, // Warna latar belakang biru
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitJurnal,
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white,
                    ), // Warna ikon putih
                    label: Text(
                      _isSubmitting ? 'Mengirim...' : 'Kirim Jurnal',
                      style: const TextStyle(
                        color: Colors.white,
                      ), // Teks tombol berwarna putih
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue, // Warna latar belakang biru
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tab 2: Riwayat Jurnal
          _riwayatJurnal.isEmpty
              ? const Center(child: Text('Belum ada jurnal.'))
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _riwayatJurnal.length,
                itemBuilder: (context, index) {
                  final jurnal = _riwayatJurnal[index];
                  final tanggal =
                      DateTime.tryParse(
                        jurnal['tanggal'] ?? '',
                      )?.toLocal().toString().split(' ')[0] ??
                      'Tanggal tidak valid';

                  return Card(
                    color: cardColor, // Menggunakan warna abu muda untuk card
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Judul jurnal dan tanggal
                          Text(
                            jurnal['judul'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black, // Warna teks judul hitam
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.black, // Warna ikon hitam
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tanggal,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color:
                                      Colors.black, // Warna teks tanggal hitam
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Gambar jurnal
                          if (jurnal['gambar_url'] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Image.network(
                                jurnal['gambar_url'],
                                height: 150,
                                fit: BoxFit.cover,
                              ),
                            ),

                          // Deskripsi jurnal
                          Text(
                            jurnal['deskripsi'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black, // Warna teks deskripsi hitam
                            ),
                            maxLines: 3,
                            overflow:
                                TextOverflow
                                    .ellipsis, // Membatasi panjang deskripsi
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}
