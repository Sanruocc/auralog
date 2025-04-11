import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import '../../features/journal/models/journal_entry.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// Provider for uploading attachments
final attachmentUploadProvider = FutureProvider.family<
    String,
    ({
      File file,
      String userId,
      String entryId,
      AttachmentType type,
    })>((ref, params) async {
  final storageService = ref.watch(storageServiceProvider);
  return storageService.uploadAttachment(
    file: params.file,
    userId: params.userId,
    entryId: params.entryId,
    type: params.type,
  );
});

// Provider for deleting attachments
final attachmentDeleteProvider = FutureProvider.family<
    bool,
    ({
      String userId,
      String entryId,
      AttachmentType type,
      String fileName,
    })>((ref, params) async {
  final storageService = ref.watch(storageServiceProvider);
  return storageService.deleteAttachment(
    userId: params.userId,
    entryId: params.entryId,
    type: params.type,
    fileName: params.fileName,
  );
});
