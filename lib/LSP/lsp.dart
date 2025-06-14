import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';

sealed class LspConfig {
  final String filePath, languageId;
  final StreamController<Map<String, dynamic>> _responseController = StreamController.broadcast();
  var _nextId = 1;

  LspConfig({
    required this.filePath,
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
        'capabilities': {
          'textDocument': {
            'completion': {'completionItem': {'snippetSupport': false}}
          }
        },
      },
    );

    if (response['error'] != null) {
      throw Exception('Initialization failed: ${response['error']}');
    }

    await _sendNotification(method: 'initialized', params: {});
  }

  Future<void> openDocument() async {
    await _sendNotification(
      method: 'textDocument/didOpen',
      params: {
        'textDocument': {
          'uri': Uri.file(filePath).toString(),
          'languageId': languageId,
          'version': 1,
          'text': await File(filePath).readAsString(),
        }
      },
    );
    await Future.delayed(Duration(milliseconds: 300));
  }

  Future<List<String>> getCompletions(int line, int character) async {
    final response = await _sendRequest(
      method: 'textDocument/completion',
      params: {
        'textDocument': {'uri': Uri.file(filePath).toString()},
        'position': {'line': line, 'character': character},
      },
    );

    return (response['result']['items'] as List?)
        ?.map((item) => item['label'] as String)
        .toList() ?? [];
  }

  Future<List<String>> getHover(int line, int character) async {
    final response = await _sendRequest(
      method: 'textDocument/hover',
      params: {
        'textDocument': {'uri': Uri.file(filePath).toString()},
        'position': {'line': line, 'character': character},
      },
    );
    return (response['result']['items'] as List?)
        ?.map((item) => item['label'] as String)
        .toList() ?? [];
  }

  Future<List<String>> getDefinition(int line, int character) async {
    final response = await _sendRequest(
      method: 'textDocument/definition',
      params: {
        'textDocument': {'uri': Uri.file(filePath).toString()},
        'position': {'line': line, 'character': character},
      },
    );
    return (response['result']['items'] as List?)
        ?.map((item) => item['label'] as String)
        .toList() ?? [];
  }

  Future<List<String>> getReferences(int line, int character) async {
    final response = await _sendRequest(
      method: 'textDocument/references',
      params: {
        'textDocument': {'uri': Uri.file(filePath).toString()},
        'position': {'line': line, 'character': character},
        'context': {'includeDeclaration': true},
      },
    );
    return (response['result']['items'] as List?)
        ?.map((item) => item['label'] as String)
        .toList() ?? [];
  }

  Stream<Map<String, dynamic>> get responses => _responseController.stream;
}


class LspSocketConfig extends LspConfig {
  final String serverUrl;
  final WebSocketChannel _channel;

  LspSocketConfig({
    required super.filePath,
    required super.languageId,
    required this.serverUrl,
  }):_channel = WebSocketChannel.connect(Uri.parse(serverUrl));

  Future<void> connect() async {
    _channel.stream.listen((data) {
      try {
        final json = jsonDecode(data as String);
        _responseController.add(json);
      } catch (e) {
        print('Error parsing response: $e');
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
    required super.languageId,
    this.args = const [],
  });

  static Future<LspStdioConfig> start({
    required String executable,
    required String filePath,
    required String languageId,
    List<String>? args
  }) async {
    final config = LspStdioConfig._(
      executable: executable,
      filePath: filePath,
      languageId: languageId,
      args: args,
    );
    await config._startProcess();
    return config;
  }
  
  Future<void> _startProcess() async {
    _process = await Process.start(executable, args ?? []);
    _process.stdout.listen(_handleStdoutData);
    _process.stderr.listen((data) => print('STDERR: ${utf8.decode(data)}'));
  }

  void _handleStdoutData(List<int> data) {
    _buffer.addAll(data);
    while (_buffer.isNotEmpty) {
      // Look for header
      final headerEnd = _findHeaderEnd();
      if (headerEnd == -1) return;

      // Parse Content-Length
      final header = utf8.decode(_buffer.sublist(0, headerEnd));
      final contentLength = int.parse(
        RegExp(r'Content-Length: (\d+)').firstMatch(header)?.group(1) ?? '0'
      );

      // Check if complete message is available
      if (_buffer.length < headerEnd + 4 + contentLength) return;

      // Extract and parse message
      final messageStart = headerEnd + 4;
      final messageEnd = messageStart + contentLength;
      final messageBytes = _buffer.sublist(messageStart, messageEnd);
      _buffer.removeRange(0, messageEnd);

      try {
        final json = jsonDecode(utf8.decode(messageBytes));
        _responseController.add(json);
      } catch (e) {
        print('Error parsing message: $e');
      }
    }
  }

  int _findHeaderEnd() {
    final endSequence = [13, 10, 13, 10]; // \r\n\r\n
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