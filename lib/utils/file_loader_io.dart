import 'dart:io';

class FileLoader {
  Future<String?> readFile(String path) async {
    return File(path).readAsString();
  }
}
