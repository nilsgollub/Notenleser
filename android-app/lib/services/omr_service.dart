import 'dart:io';
import '../models/song.dart';

enum OmrProvider { claude, gemini, backend }

class OmrException implements Exception {
  final String message;
  OmrException(this.message);
  @override
  String toString() => message;
}

abstract class OmrService {
  Future<Song> recognize({required String apiKey, required File imageFile});
}
