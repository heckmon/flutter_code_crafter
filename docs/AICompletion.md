# CodeCrafter AI Completion

You can use the AI code completion feature in CodeCrafter to get code suggestions based on the context of your code. CodeCrafter supports all providers with valid API.

## Usage

### `AiCompletion` class
#### required parameters:
- `model`: An instance of the `Models` class, which can be one of the built-in AI models or a custom model.
#### optional parameters:
- `enableCompletion`: A boolean value to enable or disable AI code completion. Defaults to `true`.

create an instance of the `AiCompletion` class with any of the [built-in AI models](#built-in-ai-models) or [custom model](#custom-ai-model) and pass it to the `CodeCrafter` widget.
Example of using Gemini AI completion:

```dart
import 'package:flutter/material.dart';
import 'package:code_crafter/code_crafter.dart';

final aiCompletion = AiCompletion(
    model: Gemini(
        apiKey: "Your API Key",
    )
)
```

Then pass the `aiCompletion` instance to the `CodeCrafter` widget:

```dart
CodeCrafter(
    controller: controller,
    theme: anOldHopeTheme,
    aiCompletion: aiCompletion, // Pass the AI completion instance here
),
```

## Styling AI Completion Text
pass the `aiCompletionTextStyle` parameter to the `CodeCrafter` widget to style the AI completion text. This is a `TextStyle` object that will be applied to the AI completion text. Recommended to leave it null as default style, which is similar to VSCode completion style.

```dart
CodeCrafter(
    controller: controller,
    theme: anOldHopeTheme,
    aiCompletion: aiCompletion,
    aiCompletionTextStyle: TextStyle(
        color: Colors.grey, // Change the color of the AI completion text
        fontStyle: FontStyle.italic, // Make the AI completion text italic
    ),
),
```

## Built-in AI Models

### 1. `Gemini()`
#### required parameter:
- `apiKey`: Your Gemini API key.
#### optional parameters:
- `model` : The model to use for completion. Defaults to `gemini-2.0-flash`.
- `temperature` : The temperature to use for completion. Defaults to `null`.
- `maxOutPutTokens` : The maximum number of tokens to generate. Defaults to `null`.
- `TopP` : The top P value to use for completion. Defaults to `null`.
- `TopK` : The top K value to use for completion. Defaults to `null`.
- `stopSequences` : The stop sequences to use for completion. Defaults to `null`.

### 2. `OpenAI()`
#### required parameters:
- `apiKey` : Your OpenAI API key.
- `model` : The model to use for completion.

### 3. `Claude()`
#### required parameters:
- `apiKey` : Your Claude API key.
- `model` : The model to use for completion.
- `version` : The version of the Claude model to use.

### 4. `Grok()`
#### required parameters:
- `apiKey` : Your OpenAI API key.
- `model` : The model to use for completion.

### 5. `DeepSeek()`
#### required parameters:
- `apiKey` : Your OpenAI API key.
- `model` : The model to use for completion.

### 6. `Gorq()`
#### required parameters:
- `apiKey` : Your OpenAI API key.
- `model` : The model to use for completion.

### 7. `TogetherAi()`
#### required parameters:
- `apiKey` : Your OpenAI API key.
- `model` : The model to use for completion.

### 8. `Sonar()`
#### required parameters:
- `apiKey` : Your OpenAI API key.
- `model` : The model to use for completion.

### 9. `OpenRouter()`
#### required parameters:
- `apiKey` : Your OpenAI API key.
- `model` : The model to use for completion.

### 10. `FireWorks()`
#### required parameters:
- `apiKey` : Your OpenAI API key.
- `model` : The model to use for completion.

## Custom AI Model

If want to use a custom AI model that running on your own server or a third party service not listed above, you can create an instance of the `CustomModel` class and pass it to the `AiCompletion` class. 

#### required parameters
- `url` : The URL of the AI model endpoint.
- `customHeaders` : The custom headers to use for the request.
`String` content.
- `requestBuilder` : The request builds the request and return the response. This is a function that takes two `String` parameters code and instruction as input and returns a `Map<String, dynamic>`.
- `customParser` : A function that parse the json response and returns 

#### Example of using a custom AI model using TogetherAI:

```dart
late final Models model;

  @override
  void initState() {
    model = CustomModel(
      url: "https://api.together.xyz/v1/chat/completions",
      customHeaders: {
        "Authorization": "Bearer ${your_api_key}",
        "Content-Type": "application/json"
      },
      requestBuilder: (code, instruction){
        return {
          "model": "deepseek-ai/DeepSeek-V3",
          "messages": [
            {
              "role": "system",
              "content": instruction
            },
            {
              "role": "user",
              "content": code
            }
          ]
        };
      },
      customParser: (response) => response['choices'][0]['message']['content']
    );
    controller = CodeCrafterController();
    controller.language = python;
    super.initState();
  }
```
Then pass the `model` instance to the `AiCompletion` class:

```dart
 @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: CodeCrafter(
          editorTheme: anOldHopeTheme,
          controller: controller,
          aiCompletion: AiCompletion(
            model: model // Pass the custom model here
          ),
        )
      ),
    );
  }
```