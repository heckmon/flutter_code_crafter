import 'dart:io';

class FileLoader {
  Future<String?> readFile(String path) async {
    try {
      if (File(path).existsSync()) {
        String source = await File(path).readAsString();
        if (source.isNotEmpty) {
          return source;
        } else {
          return 'Your canvas is ready.\nWrite something amazing!';
        }
      }
    } catch (e) {
      return "Can't read file content.\n\n$e";
    }
    return "Can't read file content.";
  }
}
