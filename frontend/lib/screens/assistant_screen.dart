// lib/screens/assistant_screen.dart
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../themes/app_colors.dart';

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late stt.SpeechToText _speech;
  bool _isAvailable = false;

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _hasText = false;
  bool _isListening = false;
  String _lastRecognizedWords = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() {
          _hasText = hasText;
        });
      }
    });
  }

  void _initSpeech() async {
    _speech = stt.SpeechToText();
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' && _isListening) {
          _stopListeningAndSend();
        }
      },
      onError: (error) => setState(() => _isListening = false),
    );
    setState(() {
      _isAvailable = available;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _sendMessage(String textToSend) async {
    final text = textToSend.trim();
    if (text.isEmpty) return;

    // Pulisce subito la barra del prompt e resetta lo stato
    _controller.clear();
    setState(() {
      _hasText = false;
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    _scrollToBottom();

    // Simulazione risposta dell'agente LLM
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _messages.add(
        ChatMessage(
          text: 'Ho elaborato la tua richiesta: "$text". Ecco le informazioni aggiornate!',
          isUser: false,
        ),
      );
    });

    _scrollToBottom();
  }

  void _startListening() async {
    if (!_isAvailable) return;

    setState(() {
      _isListening = true;
      _lastRecognizedWords = '';
      _controller.text = "";
    });

    await _speech.listen(
      localeId: 'it_IT',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 2), // Silenzio ridotto a 2 secondi
      onResult: (result) {
        setState(() {
          _lastRecognizedWords = result.recognizedWords;
          // Mostriamo temporaneamente l'ascolto nel campo solo come feedback visivo se necessario, 
          // ma evitiamo di lasciarlo sporco all'invio.
        });
        
        if (result.finalResult) {
          _stopListeningAndSend();
        }
      },
    );
  }

  void _stopListeningAndSend() {
    if (!_isListening) return;

    _speech.stop();
    setState(() {
      _isListening = false;
    });

    final textToSend = _lastRecognizedWords.isNotEmpty 
        ? _lastRecognizedWords 
        : _controller.text.trim();

    if (textToSend.isNotEmpty) {
      _sendMessage(textToSend);
    }
    
    _lastRecognizedWords = '';
    _controller.clear();
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListeningAndSend();
    } else {
      _startListening();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AuraColors.primaryGreenDark : AuraColors.primaryGreen;
    final mutedColor = isDark ? AuraColors.textMutedDark : AuraColors.textMuted;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty && !_isLoading
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          'Hey User, hai bisogno di un aiuto nel fare la raccolta differenziata?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AuraColors.textMainDark : AuraColors.textMain,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? AuraColors.darkCard : AuraColors.lightCard,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Aura sta pensando...',
                                    style: TextStyle(
                                      color: mutedColor,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final msg = _messages[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Align(
                            alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: msg.isUser
                                    ? (isDark ? AuraColors.accentCottoDark.withOpacity(0.25) : AuraColors.accentCotto.withOpacity(0.15))
                                    : (isDark ? AuraColors.darkCard : AuraColors.lightCard),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                msg.text,
                                style: TextStyle(color: isDark ? AuraColors.textMainDark : AuraColors.textMain),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 85),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AuraColors.darkCard : AuraColors.lightCard,
            borderRadius: BorderRadius.circular(24),
            border: _isListening
                ? Border.all(color: isDark ? AuraColors.accentCottoDark : AuraColors.accentCotto, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Icon(Icons.add, color: mutedColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_isListening,
                  maxLines: 5,
                  minLines: 1,
                  style: TextStyle(
                    color: _isListening
                        ? (isDark ? AuraColors.accentCottoDark : AuraColors.accentCotto)
                        : (isDark ? AuraColors.textMainDark : AuraColors.textMain),
                    fontStyle: _isListening ? FontStyle.italic : FontStyle.normal,
                  ),
                  decoration: InputDecoration(
                    hintText: _isListening ? 'In ascolto (parla o attendi 2s)...' : 'Chiedi a Aura o cerca luoghi...',
                    hintStyle: TextStyle(color: mutedColor),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: GestureDetector(
                  onTap: _toggleListening,
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening
                        ? (isDark ? AuraColors.accentCottoDark : AuraColors.accentCotto)
                        : mutedColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: GestureDetector(
                  onTap: _hasText ? () => _sendMessage(_controller.text) : null,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _hasText ? primaryColor : Colors.grey.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_upward, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}