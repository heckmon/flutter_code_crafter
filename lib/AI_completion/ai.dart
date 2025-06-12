import 'dart:convert';
import 'dart:io';
import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;

class AiCompletion{
  Models model;
  bool enableCompletion;
  int debounceTime;
  
  AiCompletion({
    required this.model,
    this.debounceTime = 1000,
    this.enableCompletion =true
  });
}

sealed class Models{
  @protected String get url;
  String? get apiKey;
  String? get model;
  Map<String, String> get headers;

  @protected
  final String instruction = "You are a code completion engine. Given the provided code where the cursor is represented by the placeholder '<|CURSOR|>', generate only the code that should be inserted at that position. Do not include the placeholder or any explanations. Return only the code to insert.";

  Map<String, dynamic> buildRequest(String code);
  
  String responseParser(dynamic response);

  Future<String> completionResponse(String code) async{
    final uri = Uri.parse(url);
    final response = await http.post(uri, headers: headers, body: jsonEncode(buildRequest(code)));
    if(response.statusCode == 200){
      return _cleanCode(responseParser(jsonDecode(response.body)));
    }
    throw HttpException("Failed to load AI suggestion \nStatus code: ${response.statusCode}\n error: ${response.body}");
  }

  @protected
  String _cleanCode(String raw) {
    final codeBlockRegex = RegExp(r'```(?:\w+)?\n([\s\S]*?)\n```');
    final thinkRegex = RegExp(r'<think>[\s\S]*?<\/think>');
    raw = raw.replaceAll(thinkRegex, '').trim();
    final match = codeBlockRegex.firstMatch(raw);
    if (match != null) return match.group(1)!.trim();

    return raw.trim();
  }

}

abstract class OpenAiCompatible extends Models{
  String get baseUrl;
  @protected @override String get url => "$baseUrl/chat/completions";

  @override
  Map<String, String> get headers => {
    "Content-Type": "application/json",
    "Authorization": "Bearer $apiKey"
  };

  @override
  Map<String, dynamic> buildRequest(String code) {
    return {
      "model": model,
      "messages": [
        {
          "role": "system",
          "content" : instruction
        },
        {
          "role": "user",
          "content": code
          }
      ]
    };
  }

  @override
  String responseParser(dynamic response) {
    try {
      return response["choices"][0]["message"]["content"];
    } catch (e) {
      throw FormatException("Failed to parse AI response: $e \nResponse: $response");
    }
  }
}

class Gemini extends Models {
  @override final String url, apiKey, model;
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
  String responseParser(dynamic response) {
    try {
      return response["candidates"][0]["content"]["parts"][0]["text"];
    } catch (e) {
      throw FormatException("Failed to parse AI response: $e \nResponse: $response");
    }
  }

  @override
  Map<String, dynamic> buildRequest(String code) {
    return {
      "systemInstruction": {
        "parts": [
          {
            "text": instruction

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
  @override final String url = 'https://api.openai.com/v1/responses', apiKey, model;

  OpenAI({required this.apiKey, required this.model});

  @override
  String responseParser(dynamic response) {
    try {
      return response[0]["content"][0]["text"];
    } catch (e) {
      throw FormatException("Failed to parse AI response: $e \nResponse: $response");
    }
  }

  @override
  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $apiKey',
  };

  @override
  Map<String, dynamic> buildRequest(String code) {
    return {
      "model": model,
      "instructions": instruction,
      "input": code,
    };
  }
}

class Claude extends Models {
  @override final String url = 'https://api.anthropic.com/v1/messages', apiKey, model;
  final String version;

  Claude({required this.apiKey, required this.version, required this.model});

  @override
  String responseParser(dynamic response) {
    try {
      return response["content"][0]["text"];
    } catch (e) {
      throw FormatException("Failed to parse AI response: $e \nResponse: $response");
    }
  }

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
      "system": instruction,
      "messages": [
        {
          "role": "user",
          "content": code
        }
      ]
    };
  }
}

class Grok extends OpenAiCompatible{
  @override String get baseUrl => "https://api.x.ai/v1";
  @override final String apiKey, model;
  Grok({required this.apiKey, required this.model});
}

class DeepSeek extends OpenAiCompatible{
  @override String get baseUrl => "https://api.deepseek.com";
  @override final String apiKey, model;
  DeepSeek({required this.apiKey, required this.model});
}

class Gorq extends OpenAiCompatible{
  @override String get baseUrl => "https://api.groq.com/openai/v1";
  @override final String apiKey, model;
  Gorq({required this.apiKey, required this.model});
}

class TogetherAi extends OpenAiCompatible{
  @override String get baseUrl => "https://api.together.xyz/v1";
  @override final String apiKey, model;
  TogetherAi({required this.apiKey, required this.model});
}

class Sonar extends OpenAiCompatible{
  @override String get baseUrl => "https://api.perplexity.ai";
  @override final String apiKey, model;
  Sonar({required this.apiKey, required this.model});
}

class OpenRouter extends OpenAiCompatible{
  @override String get baseUrl => "https://openrouter.ai/api/v1";
  @override final String apiKey, model;
  OpenRouter({required this.apiKey, required this.model});
}

class FireWorks extends OpenAiCompatible{
  @override String get baseUrl => "https://api.fireworks.ai/inference/v1";
  @override final String apiKey, model;
  FireWorks({required this.apiKey, required this.model});
}

class CustomModel extends Models {
  @override
  final String url;
  @override
  String? get apiKey => null;
  @override
  String? get model => null;
  final String httpMethod;
  final Map<String, String> customHeaders;
  final Map<String, dynamic> Function(String code, String instruction)? requestBuilder;
  final String Function(dynamic response) customParser;

  CustomModel({
    required this.url,
    required this.customHeaders,
    required this.requestBuilder,
    required this.customParser,
    this.httpMethod = 'POST',
  });

  @override
  String responseParser(dynamic response) {
    try {
      return customParser(response);
    } catch (e) {
      throw FormatException("Failed to parse AI response: $e \nResponse: $response");
    }
  }

  @override
  Map<String, String> get headers {
    final headers = {
      'Content-Type': 'application/json',
      ...customHeaders,
    };

    return headers;
  }

  @override
  Map<String, dynamic> buildRequest(String code) {
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
      final uri = Uri.parse(url);
      final response = httpMethod.toUpperCase() == 'GET'
        ? await http.get(uri, headers: headers)
        : await http.post(
            uri,
            headers: headers,
            body: jsonEncode(buildRequest(code)),
          );

      if (response.statusCode == 200) {
        return responseParser(jsonDecode(response.body));
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