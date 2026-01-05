import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GrokService {
  static final String _apiKey = dotenv.env['GROK_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  Future<String> getChatResponse(List<Map<String, String>> messages) async {
    if (_apiKey.isEmpty) {
      debugPrint('❌ Grok API Key is empty');
      return 'Error: GROK_API_KEY is not set. Please check your .env file.';
    }

    debugPrint('🚀 Sending request to Grok API...');
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': messages,
        }),
      );

      debugPrint('📥 Grok Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        debugPrint('❌ Error from Grok API: ${response.body}');
        return 'Error: ${response.statusCode} - ${response.reasonPhrase}';
      }
    } catch (e) {
      debugPrint('❌ Exception in GrokService: $e');
      return 'Exception: $e';
    }
  }
}
