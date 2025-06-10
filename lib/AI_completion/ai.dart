import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AiCompletion{
  Models model;
  bool cacheResponse;
  int debounceTime;
  
  AiCompletion({
    required this.model,
    this.cacheResponse = true,
    this.debounceTime = 1000,
  });
}

sealed class Models{
  String get url;
  String? get apiKey;
  String? get model;
  Map<String, String> get headers;

  Map<String, dynamic> buildRequest(String code, int cursorPosition);

  Future<String> completionResponse(String code, int cursorPosition) async{
    final uri = Uri.parse(url);
    final response = await http.post(uri, headers: headers, body: jsonEncode(buildRequest(code, cursorPosition)));
    if(response.statusCode == 200){
      return response.body;
    }
    throw HttpException("Failed to load AI suggetion \nStatus code: ${response.statusCode}\n error: ${response.body}");
  }
}

class Gemini extends Models {
  @override
  late final String url;
  @override
  final String  apiKey;
  @override
  final String model;
  @override
  Map<String, String> get headers => {'Content-Type': 'application/json'};
  int? temperature, maxOutputTokens, topP, topK, stopSequences;

  Gemini({
      required this.apiKey,
      this.model = 'gemini-2.5-flash',
      this.temperature,
      this.maxOutputTokens,
      this.topP,
      this.topK,
      this.stopSequences,
    }){
    url = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';
  }

  @override
  Map<String, dynamic> buildRequest(String code, int cursorPosition) {
    return {
      "systemInstruction": {
        "parts": [
          {
            "text": "You are a code completion engine. Given the provided code and cursor position, generate only the code that should be inserted at the cursor to complete the code. Do not provide explanations or any other text."
          }
        ]
      },
      "contents" : [
        {
          "parts":[
            {
              "text": "code: $code \n cursorPosition/index: $cursorPosition"
            }
          ]
        },
      ],
      "generationConfig": {
        "stopSequences": [
          "Title"
        ],
        "temperature": temperature ?? 1.0,
        "maxOutputTokens": maxOutputTokens ?? 800,
        "topP": topP ?? 0.8,
        "topK": topK ?? 10
      }
    };
  }
}

class OpenAI extends Models {
  @override
  final String url = 'https://api.openai.com/v1/responses', apiKey;
  @override
  final String model;

  OpenAI({required this.apiKey, required this.model});

  @override
  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $apiKey',
  };

  @override
  Map<String, dynamic> buildRequest(String code, int cursorPosition) {
    return {
      "model": model,
      "instructions": "You are a code completion engine. Given the provided code and cursor position, generate only the code that should be inserted at the cursor to complete the code. Do not provide explanations or any other text.",
      "input": "code: $code\n cursor position / index: $cursorPosition",
    };
  }
}

class Gork extends Models {
  @override
  final String url = 'https://api.x.ai/v1/chat/completions', apiKey;
  @override
  final String? model = null;

  Gork({required this.apiKey});

  @override
  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $apiKey',
  };

  @override
  Map<String, dynamic> buildRequest(String code, int cursorPosition) {
    return {
      "messages" : [
        {
          "role": "system",
          "content": "You are a code completion engine. Given the provided code and cursor position, generate only the code that should be inserted at the cursor to complete the code. Do not provide explanations or any other text."
        },
        {
          "role": "user",
          "content": "code: $code\ncursor position / index: $cursorPosition"
        }
      ]
    };
  }
}

class Claude extends Models {
  @override
  final String url = 'https://api.anthropic.com/v1/messages', apiKey;
  @override
  final String model;
  final String version;

  Claude({required this.apiKey, required this.version, required this.model});

  @override
  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'x-api-key': apiKey,
    'anthropic-version': version
  };

  @override
  Map<String, dynamic> buildRequest(String code, int cursorPosition) {
    return {
      "model": model,
      "max_tokens": 1024,
      "messages": [
        {
          "role": "assistant",
          "content": "You are a code completion engine. Given the provided code and cursor position, generate only the code that should be inserted at the cursor to complete the code. Do not provide explanations or any other text."
        },
        {
          "role": "user",
          "content": "code: $code\ncursor position / index: $cursorPosition"
        }
      ]
    };
  }
}

class CustomModel extends Models {
  @override
  final String url;
  @override
  final String? apiKey;
  @override
  final String? model;
  final String? apiKeyHeader;
  final bool apiKeyInQueryParams;
  final String httpMethod;
  final Map<String, String> customHeaders;
  final Map<String, dynamic> Function(String code, int cursorPosition)? requestBuilder;

  CustomModel({
    required this.url,
    this.apiKey,
    this.model,
    this.apiKeyHeader,
    this.apiKeyInQueryParams = false,
    this.httpMethod = 'POST',
    Map<String, String>? customHeaders,
    this.requestBuilder,
  }) : 
    customHeaders = customHeaders ?? {};

  @override
  Map<String, String> get headers {
    final headers = {
      'Content-Type': 'application/json',
      ...customHeaders,
    };

    if (apiKey != null && apiKeyHeader != null && !apiKeyInQueryParams) {
      headers[apiKeyHeader!] = apiKeyHeader!.toLowerCase().contains('bearer')
          ? 'Bearer $apiKey'
          : apiKey!;
    }

    return headers;
  }

  Uri get _uri {
    final uri = Uri.parse(url);
    if (apiKey != null && apiKeyInQueryParams) {
      return uri.replace(queryParameters: {
        ...uri.queryParameters,
        'api_key': apiKey!,
      });
    }
    return uri;
  }

  @override
  Map<String, dynamic> buildRequest(String code, int cursorPosition) {
    if (requestBuilder != null) {
      return requestBuilder!(code, cursorPosition);
    }

    return {
      if (model != null) 'model': model,
      'code': code,
      'cursor_position': cursorPosition,
      'parameters': {
        'instruction': 'Complete the code at the given position',
        'temperature': 0.2,
      }
    };
  }

  @override
  Future<String> completionResponse(String code, int cursorPosition) async {
    try {
      final uri = _uri;
      final response = httpMethod.toUpperCase() == 'GET'
        ? await http.get(uri, headers: headers)
        : await http.post(
            uri,
            headers: headers,
            body: jsonEncode(buildRequest(code, cursorPosition)),
          );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw HttpException(
          'Request failed with status ${response.statusCode}',
          uri: uri,
        );
      }
    } catch (e) {
      throw Exception('Failed to complete request: $e');
    }
  }
}