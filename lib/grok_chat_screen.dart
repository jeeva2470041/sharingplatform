import 'package:flutter/material.dart';
import 'services/grok_service.dart';
import 'app_theme.dart';
import 'constants/assistant_prompts.dart';


class GrokChatScreen extends StatefulWidget {
  const GrokChatScreen({super.key});

  @override
  State<GrokChatScreen> createState() => _GrokChatScreenState();
}

class _GrokChatScreenState extends State<GrokChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {
      'role': 'system',
      'content': AssistantPrompts.campusShareAssistant,
    },
    {
      'role': 'assistant',
      'content': AssistantPrompts.initialGreeting,
    },
  ];
  final GrokService _grokService = GrokService();
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final userMessage = _controller.text.trim();
    setState(() {
      _messages.add({'role': 'user', 'content': userMessage});
      _controller.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    final response = await _grokService.getChatResponse(_messages);

    setState(() {
      _messages.add({'role': 'assistant', 'content': response});
      _isLoading = false;
    });

    _scrollToBottom();
  }

  Widget _emojiButton(String emoji) {
    return InkWell(
      onTap: () {
        _controller.text += emoji;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.bottomRight,
      insetPadding: const EdgeInsets.all(AppTheme.spacing16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: AppTheme.isMobile(context) ? double.infinity : 400,
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '🤖 Campus Assistant ✨',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppTheme.fontSizeLabel,
                        fontWeight: AppTheme.fontWeightBold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppTheme.spacing16),
                itemCount: _messages.length - 1, // Skip system message
                itemBuilder: (context, index) {
                  final message = _messages[index + 1];
                  final isUser = message['role'] == 'user';

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing12,
                        vertical: AppTheme.spacing8,
                      ),
                      decoration: BoxDecoration(
                        color: isUser ? AppTheme.primary : AppTheme.border,
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      ),
                      constraints: BoxConstraints(
                        maxWidth: (AppTheme.isMobile(context) ? MediaQuery.of(context).size.width : 400) * 0.75,
                      ),
                      child: Text(
                        message['content'] ?? '',
                        style: TextStyle(
                          color: isUser ? Colors.white : AppTheme.textPrimary,
                          fontSize: AppTheme.fontSizeLabel,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(AppTheme.spacing8),
                child: CircularProgressIndicator(),
              ),
            // Quick Emojis
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing12),
              child: Row(
                children: [
                  _emojiButton('👋'),
                  _emojiButton('🙋‍♂️'),
                  _emojiButton('📦'),
                  _emojiButton('🤝'),
                  _emojiButton('⭐'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(fontSize: AppTheme.fontSizeLabel),
                      decoration: InputDecoration(
                        hintText: 'Type a message... 💬',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing12,
                          vertical: AppTheme.spacing8,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primary,
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
