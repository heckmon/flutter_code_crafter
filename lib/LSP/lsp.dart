import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';

sealed class LspConfig {
  final String filePath, languageId, workspacePath;
  final StreamController<Map<String, dynamic>> _responseController = StreamController.broadcast();
  int _nextId = 1;
  final _openDocuments = <String, int>{};

  LspConfig({
    required this.filePath,
    required this.workspacePath,
    required this.languageId
  });

  void dispose();

  Future<Map<String, dynamic>> _sendRequest({
    required String method,
    required Map<String, dynamic> params,
  });

  Future<void> _sendNotification({
    required String method,
    required Map<String, dynamic> params,
  });

  Future<void> initialize() async {
    final response = await _sendRequest(
      method: 'initialize',
      params: {
        'processId': pid,
        'workspaceFolders': [
          {'uri': Uri.file(workspacePath).toString(), 'name': 'workspace'}
        ],
        'capabilities': {
          'textDocument': {
            'completion': {'completionItem': {'snippetSupport': false}}
          },
          'hover': {'contentFormat': ['markdown']}
        },
      },
    );

    if (response['error'] != null) {
      throw Exception('Initialization failed: ${response['error']}');
    }

    await _sendNotification(method: 'initialized', params: {});
  }

  Map<String, dynamic> _commonParams(int line, int character) {
    return {
      'textDocument': {'uri': Uri.file(filePath).toString()},
      'position': {'line': line, 'character': character},
    };
  }

  Future<void> openDocument() async {
    final version = (_openDocuments[filePath] ?? 0) + 1;
    _openDocuments[filePath] = version;
    await _sendNotification(
      method: 'textDocument/didOpen',
      params: {
        'textDocument': {
          'uri': Uri.file(filePath).toString(),
          'languageId': languageId,
          'version': version,
          'text': await File(filePath).readAsString(),
        }
      },
    );
    await Future.delayed(Duration(milliseconds: 300));
  }

  Future<void> updateDocument(String content) async {
    if (!_openDocuments.containsKey(filePath)) {
      throw StateError('Document must be opened first');
    }
    
    final version = _openDocuments[filePath]! + 1;
    _openDocuments[filePath] = version;
    
    await _sendNotification(
      method: 'textDocument/didChange',
      params: {
        'textDocument': {
          'uri': Uri.file(filePath).toString(),
          'version': version,
        },
        'contentChanges': [
          {
            'text': content,
          }
        ]
      },
    );
  }

  Future<void> closeDocument() async {
    if (!_openDocuments.containsKey(filePath)) return;
    
    await _sendNotification(
      method: 'textDocument/didClose',
      params: {
        'textDocument': {
          'uri': Uri.file(filePath).toString(),
        }
      },
    );
    _openDocuments.remove(filePath);
  }

  Future<List<String>> getCompletions(int line, int character) async {
    final response = await _sendRequest(
      method: 'textDocument/completion',
      params: _commonParams(line, character)
    );

    return (response['result']['items'] as List?)
        ?.map((item) => item['label'] as String)
        .toList() ?? [];
  }

  Future<String> getHover(int line, int character) async {
    final response = await _sendRequest(
      method: 'textDocument/hover',
      params: _commonParams(line, character)
    );
    return response['result']['contents']['value'] ?? '';
  }

  Future<String> getDefinition(int line, int character) async {
    final response= await _sendRequest(
      method: 'textDocument/definition',
      params: _commonParams(line, character)
    );
    return response['result'][1]['uri'] ?? '';
  }

  Future<List<dynamic>> getReferences(int line, int character) async {
    final params = _commonParams(line, character);
    params['context'] = {'includeDeclaration': true};
    final response = await _sendRequest(
      method: 'textDocument/references',
      params: params
    );
    return response['result'];
  }

  Stream<Map<String, dynamic>> get responses => _responseController.stream;
}


class LspSocketConfig extends LspConfig {
  final String serverUrl;
  final WebSocketChannel _channel;

  LspSocketConfig({
    required super.filePath,
    required super.workspacePath,
    required super.languageId,
    required this.serverUrl,
  }):_channel = WebSocketChannel.connect(Uri.parse(serverUrl));

  Future<void> connect() async {
    _channel.stream.listen((data) {
      try {
        final json = jsonDecode(data as String);
        _responseController.add(json);
      } catch (e) {
        throw FormatException('Invalid JSON response: $data', e);
      }
    });
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

    _channel.sink.add(jsonEncode(request));
    
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
    _channel.sink.add(jsonEncode({
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
    }));
  }

  @override
  void dispose() {
    _channel.sink.close();
    _responseController.close();
  }
}


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