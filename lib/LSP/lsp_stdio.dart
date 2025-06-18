part of 'lsp.dart';

class LspStdioConfig extends LspConfig {
  final String executable;
  final List<String>? args;
  late Process _process;
  final _buffer = <int>[];

  LspStdioConfig._({
    required this.executable,
    required super.filePath,
    required super.workspacePath,
    required super.languageId,
    this.args = const [],
  });

  static Future<LspStdioConfig> start({
    required String executable,
    required String filePath,
    required String workspacePath,
    required String languageId,
    List<String>? args
  }) async {
    final config = LspStdioConfig._(
      executable: executable,
      filePath: filePath,
      languageId: languageId,
      workspacePath: workspacePath,
      args: args,
    );
    await config._startProcess();
    return config;
  }
  
  Future<void> _startProcess() async {
    _process = await Process.start(executable, args ?? []);
    _process.stdout.listen(_handleStdoutData);
    _process.stderr.listen((data) => throw Exception('LSP process error: ${utf8.decode(data)}'));
  }

  void _handleStdoutData(List<int> data) {
    _buffer.addAll(data);
    while (_buffer.isNotEmpty) {
      final headerEnd = _findHeaderEnd();
      if (headerEnd == -1) return;
      final header = utf8.decode(_buffer.sublist(0, headerEnd));
      final contentLength = int.parse(
        RegExp(r'Content-Length: (\d+)').firstMatch(header)?.group(1) ?? '0'
      );
      if (_buffer.length < headerEnd + 4 + contentLength) return;
      final messageStart = headerEnd + 4;
      final messageEnd = messageStart + contentLength;
      final messageBytes = _buffer.sublist(messageStart, messageEnd);
      _buffer.removeRange(0, messageEnd);
      try {
        final json = jsonDecode(utf8.decode(messageBytes));
        _responseController.add(json);
      } catch (e) {
        throw FormatException('Invalid JSON message $e', utf8.decode(messageBytes));
      }
    }
  }

  int _findHeaderEnd() {
    final endSequence = [13, 10, 13, 10];
    for (var i = 0; i <= _buffer.length - endSequence.length; i++) {
      if (List.generate(endSequence.length, (j) => _buffer[i + j]).every((byte) => endSequence.contains(byte))) {
        return i;
      }
    }
    return -1;
  }

  @override
  Future<Map<String, dynamic>> _sendRequest({
    required String method,
    required Map<String, dynamic> params,
  }) async {
    final id = _nextId++;
    final request = {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    };
    await _sendLspMessage(request);
    
    return await _responseController.stream.firstWhere(
      (response) => response['id'] == id,
      orElse: () => throw TimeoutException('No response for request $id'),
    );
  }

  @override
  Future<void> _sendNotification({
    required String method,
    required Map<String, dynamic> params,
  }) async {
    await _sendLspMessage({
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
    });
  }

  Future<void> _sendLspMessage(Map<String, dynamic> message) async {
    final body = utf8.encode(jsonEncode(message));
    final header = 'Content-Length: ${body.length}\r\n\r\n';
     _process.stdin.add(utf8.encode(header));
    _process.stdin.add(body);
    await _process.stdin.flush();
  }

  @override
  void dispose() {
    _process.kill();
    _responseController.close();
  }
}