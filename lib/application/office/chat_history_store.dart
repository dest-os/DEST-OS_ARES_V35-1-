import 'package:flutter/foundation.dart';

import '../../infrastructure/storage/json_file_store.dart';

/// Sohbetteki tek bir mesaj.
class ChatMessageData {
  const ChatMessageData({
    required this.text,
    required this.fromUser,
    this.isError = false,
    this.agent = '',
  });

  final String text;
  final bool fromUser;
  final bool isError;

  /// Cevabı hazırlayan ajan/ekip (kullanıcı mesajlarında boş).
  final String agent;

  Map<String, Object?> toJson() => <String, Object?>{
        'text': text,
        'fromUser': fromUser,
        'isError': isError,
        'agent': agent,
      };

  static ChatMessageData fromJson(Map<String, dynamic> json) {
    return ChatMessageData(
      text: json['text'] is String ? json['text'] as String : '',
      fromUser: json['fromUser'] == true,
      isError: json['isError'] == true,
      agent: json['agent'] is String ? json['agent'] as String : '',
    );
  }
}

/// Kaydedilmiş bir sohbet.
class ChatConversation {
  ChatConversation({required this.id, required this.title, required this.startedAt, required this.messages});

  final String id;
  String title;
  final DateTime startedAt;
  final List<ChatMessageData> messages;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'title': title,
        'startedAt': startedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  static ChatConversation? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final started = json['startedAt'] is String ? DateTime.tryParse(json['startedAt'] as String) : null;
    if (id is! String || started == null) return null;
    final messages = <ChatMessageData>[];
    final raw = json['messages'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) messages.add(ChatMessageData.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return ChatConversation(
      id: id,
      title: json['title'] is String ? json['title'] as String : '',
      startedAt: started,
      messages: messages,
    );
  }
}

/// Sohbet geçmişini diskte saklar.
class ChatHistoryStore extends ChangeNotifier {
  ChatHistoryStore({required JsonFileStore store}) : _store = store;

  static const String _fileName = 'chat_history';
  static const int _maxConversations = 40;
  static const int _maxMessages = 120;

  final JsonFileStore _store;
  final List<ChatConversation> _items = <ChatConversation>[];

  /// En yeni sohbet başta.
  List<ChatConversation> get items => List<ChatConversation>.unmodifiable(_items);

  Future<void> load() async {
    final raw = await _store.read(_fileName);
    _items.clear();
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          try {
            final c = ChatConversation.fromJson(Map<String, dynamic>.from(item));
            if (c != null) _items.add(c);
          } catch (_) {
            // Bozuk kayıt atlanır.
          }
        }
      }
    }
    _items.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    notifyListeners();
  }

  Future<void> save(ChatConversation conversation) async {
    if (conversation.messages.length > _maxMessages) {
      conversation.messages.removeRange(0, conversation.messages.length - _maxMessages);
    }
    final index = _items.indexWhere((c) => c.id == conversation.id);
    if (index >= 0) {
      _items[index] = conversation;
    } else {
      _items.insert(0, conversation);
    }
    if (_items.length > _maxConversations) _items.removeRange(_maxConversations, _items.length);
    await _store.write(_fileName, _items.map((c) => c.toJson()).toList());
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _items.removeWhere((c) => c.id == id);
    await _store.write(_fileName, _items.map((c) => c.toJson()).toList());
    notifyListeners();
  }
}
