part of 'lsp.dart';

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