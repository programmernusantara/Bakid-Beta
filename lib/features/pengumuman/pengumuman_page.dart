import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final pengumumanProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final response = await Supabase.instance.client
          .from('pengumuman')
          .select('*')
          .order('tanggal_dibuat', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    });

class PengumumanPage extends ConsumerWidget {
  const PengumumanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pengumumanAsync = ref.watch(pengumumanProvider);

    return Scaffold(
      backgroundColor: Colors.white, // Latar belakang putih
      appBar: AppBar(
        title: const Text('Info'),
        centerTitle: true,
        backgroundColor: Colors.grey[100], // Navbar putih
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.blue), // Ikon biru
      ),
      body: pengumumanAsync.when(
        loading:
            () => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
        error:
            (error, _) => Center(
              child: Text(
                'Terjadi kesalahan: $error',
                style: TextStyle(color: Colors.red[800]),
              ),
            ),
        data: (pengumumanList) {
          if (pengumumanList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.megaphone,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada pengumuman',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemCount: pengumumanList.length,
            itemBuilder: (context, index) {
              final item = pengumumanList[index];
              final tanggal = DateTime.parse(item['tanggal_dibuat']);
              final formattedDate = DateFormat(
                'dd MMM yyyy, HH:mm',
              ).format(tanggal);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50], // Card abu muda soft
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.blue[100],
                          child: Icon(
                            LucideIcons.user,
                            size: 18,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Admin',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Judul
                    Text(
                      item['judul'] ?? 'Tanpa Judul',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Gambar (dengan tampilan fullscreen saat diklik)
                    if (item['lampiran_url'] != null &&
                        item['lampiran_url'].toString().isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => FullScreenImagePage(
                                    imageUrl: item['lampiran_url'],
                                  ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item['lampiran_url'],
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => Container(
                                  height: 200,
                                  color: Colors.grey[200],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        LucideIcons.imageOff,
                                        size: 40,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Gambar tidak dapat dimuat',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Isi
                    Text(
                      item['isi'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Halaman untuk melihat gambar dalam tampilan fullscreen
class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImagePage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder:
                    (context, error, stackTrace) => const Center(
                      child: Text(
                        'Gambar tidak dapat dimuat',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
