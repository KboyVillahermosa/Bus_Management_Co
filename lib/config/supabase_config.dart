import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class SupabaseService {
  // Replace with your Supabase URL and key
  static const String supabaseUrl = 'https://mplqmbipjciemrlzfths.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1wbHFtYmlwamNpZW1ybHpmdGhzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg3NzM3NzgsImV4cCI6MjA2NDM0OTc3OH0.Uxja_q-TQvPN7zODXlO2zW25Bp1MQBoMnNJO09cKOKg';
  
  static late SupabaseClient _client;
  static bool _initialized = false;
  
  static Future<void> initialize() async {
    // If already initialized, just return
    if (_initialized) {
      print('Supabase already initialized, skipping initialization');
      return;
    }
    
    try {
      // Check if Supabase is already initialized by the Flutter package
      try {
        // If this succeeds, Supabase is already initialized
        _client = Supabase.instance.client;
        _initialized = true;
        print('Supabase was already initialized externally');
        return;
      } catch (e) {
        // Supabase is not initialized yet, continue with initialization
        print('Initializing Supabase for the first time');
      }
      
      // Check internet connectivity first
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw Exception('No internet connection');
        }
      } on SocketException catch (e) {
        print('Network error: $e');
        throw Exception('Please check your internet connection');
      }
      
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: true,
      );
      _client = Supabase.instance.client;
      _initialized = true;
      print('Supabase initialized successfully');
      
      // Verify the connection by making a simple request
      await _client.from('_dummy_').select().limit(1).maybeSingle();
      print('Supabase connection verified');
    } catch (e) {
      print('Supabase initialization error: $e');
      _initialized = false;
      throw Exception('Failed to initialize Supabase: $e');
    }
  }
  
  static SupabaseClient get client {
    if (!_initialized) {
      throw Exception('Supabase not initialized. Call SupabaseService.initialize() first.');
    }
    return _client;
  }
}

// For easier access throughout the app
SupabaseClient get supabase => SupabaseService.client;