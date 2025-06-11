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

  Map<String, dynamic> buildRequest(String code);

  Future<String> completionResponse(String code) async{
    final uri = Uri.parse(url);
    final response = await http.post(uri, headers: headers, body: jsonEncode(buildRequest(code)));
    if(response.statusCode == 200){
      return response.body;
    }
    throw HttpException("Failed to load AI suggestion \nStatus code: ${response.statusCode}\n error: ${response.body}");
  }
}

class Gemini extends Models {
  @override
  final String url;
  @override
  final String  apiKey;
  @override
  final String model;
  @override
  Map<String, String> get headers => {'Content-Type': 'application/json'};
  int? temperature, maxOutputTokens, topP, topK, stopSequences;

  Gemini({
      required this.apiKey,
      this.model = 'gemini-2.0-flash',
      this.temperature,
      this.maxOutputTokens,
      this.topP,
      this.topK,
      this.stopSequences,
    }):url = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

  @override
  Map<String, dynamic> buildRequest(String code) {
    return {
      "systemInstruction": {
        "parts": [
          {
            "text": "You are a code completion engine. Given the provided code where the cursor is represented by the placeholder '|CURSOR|', generate only the code that should be inserted at that position. Do not include the placeholder or any explanations. Return only the code to insert."

          }
        ]
      },
      "contents" : [
        {
          "parts":[
            {
              "text": code
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
  Map<String, dynamic> buildRequest(String code) {
    return {
      "model": model,
      "instructions": "You are a code completion engine. Given the provided code where the cursor is represented by the placeholder '|CURSOR|', generate only the code that should be inserted at that position. Do not include the placeholder or any explanations. Return only the code to insert.",
      "input": code,
    };
  }
}

class Gork extends Models {
  @override
  final String url = 'https://api.x.ai/v1/chat/completions', apiKey;
  @override
  String? get model => null;

  Gork({required this.apiKey});

  @override
  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $apiKey',
  };

  @override
  Map<String, dynamic> buildRequest(String code) {
    return {
      "messages" : [
        {
          "role": "system",
          "content": "You are a code completion engine. Given the provided code where the cursor is represented by the placeholder '|CURSOR|', generate only the code that should be inserted at that position. Do not include the placeholder or any explanations. Return only the code to insert."
        },
        {
          "role": "user",
          "content": code
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
  Map<String, dynamic> buildRequest(String code) {
    return {
      "model": model,
      "max_tokens": 1024,
      "system": "You are a code completion engine. Given the provided code where the cursor is represented by the placeholder '|CURSOR|', generate only the code that should be inserted at that position. Do not include the placeholder or any explanations. Return only the code to insert.",
      "messages": [
        {
          "role": "user",
          "content": code
        }
      ]
    };
  }
}

class DeepSeek extends Models{
  @override
  final String url = "https://api.deepseek.com/chat/completions", apiKey, model;
  DeepSeek({required this.apiKey, required this.model});

  @override
  Map<String, String> get headers => {
    "Content-Type": "application/json",
    "Authorization": "Bearer $apiKey"
  };

  @override
  Map<String, dynamic> buildRequest(String code) {
    return {
      "model": model,
      "messages":[
        {"role" : "system", "content":"You are a code completion engine. Given the provided code where the cursor is represented by the placeholder '|CURSOR|', generate only the code that should be inserted at that position. Do not include the placeholder or any explanations. Return only the code to insert."},
        {"role" : "user", "content":code},
      ],
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
  final Map<String, dynamic> Function(String code, String instruction)? requestBuilder;

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
  Map<String, dynamic> buildRequest(String code) {
    const String instruction = "You are a code completion engine. Given the provided code where the cursor is represented by the placeholder '|CURSOR|', generate only the code that should be inserted at that position. Do not include the placeholder or any explanations. Return only the code to insert.";
    if (requestBuilder != null) {
      return requestBuilder!(code, instruction);
    }
    return {
      if (model != null) 'model': model,
      'code': code,
      'parameters': {
        'instruction': instruction,
        'temperature': 0.2,
      }
    };
  }


  @override
  Future<String> completionResponse(String code) async {
    try {
      final uri = _uri;
      final response = httpMethod.toUpperCase() == 'GET'
        ? await http.get(uri, headers: headers)
        : await http.post(
            uri,
            headers: headers,
            body: jsonEncode(buildRequest(code)),
          );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw HttpException(
          'Request failed with status ${response.statusCode}\n ${response.body}',
          uri: uri,
        );
      }
    } catch (e) {
      throw Exception('Failed to complete request: $e');
    }
  }
}