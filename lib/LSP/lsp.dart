import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';

part 'lsp_socket.dart';
part 'lsp_stdio.dart';

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
      return;
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