import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // TODO: Replace this with your actual API key from Google AI Studio
  static const String _apiKey = 'AIzaSyAO3IyeZbaQOCESHw0o3WnKsovm6LOBSts';

  late final GenerativeModel _model;
  late final ChatSession _chat;
  bool _isLoading = false;

  // We store messages as a map to track who sent what
  final List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    // 1. Setup the Gemini 1.5 Flash Model
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      // The system instruction gives your AI its "personality" and knowledge boundaries
      systemInstruction: Content.system(
          'You are MedicareBot, a helpful AI health assistant built into the Medicare app. '
              'Answer questions about medicines, health routines, and general medical inquiries. '
              'Be concise, friendly, and always remind the user to consult a real doctor for serious issues.'
      ),
    );

    // 2. Start a chat session so the AI remembers the conversation history
    _chat = _model.startChat();

    // 3. Add a welcome message to the UI
    _messages.add({
      'role': 'model',
      'text': 'Hello! I am your Medicare AI Assistant. How can I help you with your health or medications today?',
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_apiKey == 'YOUR_API_KEY_HERE') {
      _showError('Please put your Google API Key in the code first!');
      return;
    }

    // Add user message to UI
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      // Send message to Gemini API
      final response = await _chat.sendMessage(Content.text(text));

      // Add AI response to UI
      setState(() {
        _messages.add({
          'role': 'model',
          'text': response.text ?? 'I am not sure how to respond to that.',
        });
      });
    } catch (e) {
      // This prints the exact error to your Android Studio console (Run tab)
      print("GEMINI API ERROR: $e");
      // This shows the exact error in the red snackbar
      _showError('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Medicare AI Assistant"),
        backgroundColor: const Color(0xFF4CA1AF), // Your app's theme color
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // The Chat Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return _buildMessageBubble(msg['text']!, isUser);
              },
            ),
          ),

          // Loading Indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: Color(0xFF4CA1AF)),
            ),

          // The Input Field Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: "Ask about a medicine...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CA1AF),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () => _sendMessage(_textController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to draw the chat bubbles beautifully
  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF4CA1AF) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(0),
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(20),
          ),
          boxShadow: [
            if (!isUser) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF2C3E50),
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}