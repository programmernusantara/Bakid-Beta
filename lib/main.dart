import 'package:bakid/core/providers/auth_provider.dart';
import 'package:bakid/core/services/supabase_service.dart';
import 'package:bakid/features/auth/login_page.dart';
import 'package:bakid/features/dashboard/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();

  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('userId'); // Retrieve stored userId

  runApp(ProviderScope(child: MyApp(userId: userId)));
}

class MyApp extends ConsumerWidget {
  final String? userId;
  const MyApp({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Asatid App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: authState.when(
        data: (state) {
          // Check if user is logged in or not
          if (userId != null) {
            return DashboardPage(userId: userId!);
          } else {
            return const LoginPage();
          }
        },
        loading:
            () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
        error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      ),
    );
  }
}
