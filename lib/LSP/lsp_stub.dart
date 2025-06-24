import '../utils/utils.dart';

sealed class LspConfig {
  final String filePath;
  final String workspacePath;
  final String languageId;

  LspConfig({
    required this.filePath,
    required this.workspacePath,
    required this.languageId,
  });

  void dispose() {}

  Future<void> initialize() async {}
  Future<void> openDocument() async {}
  Future<void> updateDocument(String content) async {}
  Future<void> closeDocument() async {}
  Future<List<LspCompletion>> getCompletions(int line, int character) async =>
      [];
  Future<String> getHover(int line, int character) async => '';
  Future<String> getDefinition(int line, int character) async => '';
  Future<List<dynamic>> getReferences(int line, int character) async => [];
  Stream<Map<String, dynamic>> get responses => const Stream.empty();
}

class LspSocketConfig extends LspConfig {
  final String serverUrl;
  LspSocketConfig({
    required this.serverUrl,
    required super.filePath,
    required super.workspacePath,
    required super.languageId,
  });

  @override
  Future<void> initialize() async {}
  @override
  Future<void> openDocument() async {}
  @override
  Future<void> updateDocument(String content) async {}
  @override
  Future<void> closeDocument() async {}
  @override
  Stream<Map<String, dynamic>> get responses => const Stream.empty();

  Future<void> connect() async {}
}
