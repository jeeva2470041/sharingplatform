import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GrokService {
  static final String _apiKey = dotenv.env['GROK_API_KEY'] ?? '';
  
  // Use proxy server for web, direct API for mobile/desktop
  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api/groq/chat';
    }
    return 'https://api.groq.com/openai/v1/chat/completions';
  }

  Future<String> getChatResponse(List<Map<String, String>> messages) async {
    if (!kIsWeb && _apiKey.isEmpty) {
      debugPrint('❌ Grok API Key is empty');
      return 'Error: GROK_API_KEY is not set. Please check your .env file.';
    }

    debugPrint('🚀 Sending request to Grok API... (Web: $kIsWeb)');
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      // Only add Authorization header for non-web platforms
      if (!kIsWeb) {
        headers['Authorization'] = 'Bearer $_apiKey';
      }

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
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
