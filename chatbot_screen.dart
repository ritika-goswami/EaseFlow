import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:easeflow_app/user_data.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  String _firstName = "there";

  GenerativeModel? _model;
  ChatSession? _chatSession;

  @override
  void initState() {
    super.initState();
    _initGemini();
    _setupGreeting();
  }

  void _initGemini() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    
    if (apiKey == null || apiKey.isEmpty) {
      print("❌ ERROR: API Key not found in .env file!");
      return;
    }

    // Pointing to your confirmed available model
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      requestOptions: const RequestOptions(apiVersion: 'v1beta'),
    );

    // THE FIX: We use a User -> Model handshake instead of 'system' 
    // to avoid the "Please use a valid role: user, model" error.
    _chatSession = _model!.startChat(
      history: [
        Content.text(
          "I am starting a session. You are the EaseFlow Assistant, a kind and empathetic health companion. "
          "You help users manage menstrual health and comfort. "
          "Keep your answers supportive, concise, and professional."
        ),
        Content.model([TextPart("Understood. I am the EaseFlow Assistant. How can I support you today?")]),
      ],
    );
  }

  Future<void> _setupGreeting() async {
    String fullName = await UserData.getUserName();
    if (mounted) {
      setState(() {
        _firstName = fullName.split(' ')[0];
        _messages.add({
          "text": "Hi $_firstName 💗\nHow are you feeling today?", 
          "isUser": false
        });
      });
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

  Future<void> _sendMessage() async {
    final userText = _controller.text.trim();
    if (userText.isEmpty || _chatSession == null) return;

    setState(() {
      _messages.add({
        "text": userText,
        "isUser": true,
      });
      _isTyping = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final response = await _chatSession!.sendMessage(Content.text(userText));
      
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            "text": response.text ?? "I'm here for you, but I couldn't process that message.",
            "isUser": false,
          });
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            "text": "Sorry, I'm having trouble connecting. Let's try again in a moment.", 
            "isUser": false,
          });
        });
        _scrollToBottom();
        print("Detailed AI Error: $e"); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              color: const Color(0xFFFDE4E4).withOpacity(0.5),
              child: Row(
                children: [
                  const Icon(Icons.smart_toy_outlined, size: 28, color: Colors.black),
                  const SizedBox(width: 10),
                  const Text(
                    "How may I help you?",
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold, 
                      fontFamily: 'Serif'
                    ),
                  ),
                  const Spacer(),
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 18,
                    child: Icon(Icons.person, color: Colors.black, size: 20),
                  ),
                ],
              ),
            ),

            // --- CHAT AREA ---
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isTyping) {
                    return _buildTypingIndicator();
                  }
                  
                  final msg = _messages[index];
                  return msg["isUser"] 
                    ? _buildUserBubble(msg["text"]) 
                    : _buildAIBubble(msg["text"]);
                },
              ),
            ),

            // --- INPUT FIELD ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 15), 
              child: Row(
                children: [
                  const Icon(Icons.add, color: Colors.grey, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5E6E6),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: _controller,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: "Type a message...",
                          hintStyle: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: const CircleAvatar(
                      backgroundColor: Color(0xFFE79AA2),
                      child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIBubble(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.smart_toy_outlined, size: 24, color: Colors.black),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(
                color: Color(0xFFFDE4E4),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Text(
                text, 
                style: const TextStyle(
                  color: Color(0xFF8B4513), 
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Serif'
                )
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBubble(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(
                color: Color(0xFFE79AA2),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.person, size: 24, color: Colors.black),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          const Icon(Icons.smart_toy_outlined, size: 24, color: Colors.black),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
            child: const Text("● ● ●", style: TextStyle(color: Color(0xFFE79AA2), fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
