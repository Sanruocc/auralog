import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../features/journal/models/journal_entry.dart';

class StorageService {
  final SupabaseClient _supabase;
  final _uuid = const Uuid();

  StorageService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<String> uploadAttachment({
    required File file,
    required String userId,
    required String entryId,
    required AttachmentType type,
  }) async {
    try {
      final fileExt = path.extension(file.path);
      final fileName = '${_uuid.v4()}$fileExt';
      final storagePath = _getStoragePath(userId, entryId, type, fileName);

      final response =
          await _supabase.storage.from('attachments').upload(storagePath, file);

      final fileUrl =
          _supabase.storage.from('attachments').getPublicUrl(storagePath);

      return fileUrl;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<bool> deleteAttachment({
    required String userId,
    required String entryId,
    required AttachmentType type,
    required String fileName,
  }) async {
    try {
      final storagePath = _getStoragePath(userId, entryId, type, fileName);

      await _supabase.storage.from('attachments').remove([storagePath]);

      return true;
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  String _getStoragePath(
      String userId, String entryId, AttachmentType type, String fileName) {
    return '$userId/$entryId/${type.name}/$fileName';
  }

  Future<void> initStorage() async {
    try {
      // Check if the 'attachments' bucket exists, create if not
      final buckets = await _supabase.storage.listBuckets();
      final exists = buckets.any((bucket) => bucket.name == 'attachments');

      if (!exists) {
        await _supabase.storage.createBucket(
          'attachments',
          const BucketOptions(
            public: false,
            fileSizeLimit: '50000000', // 50MB limit
          ),
        );

        // Set up security policies
        await _supabase.storage
            .from('attachments')
            .createSignedUrl('test.txt', 60);
      }
    } catch (e) {
      print('Error initializing storage: $e');
    }
  }
}
