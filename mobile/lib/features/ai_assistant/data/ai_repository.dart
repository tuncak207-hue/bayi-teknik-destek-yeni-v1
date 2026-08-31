import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/events/stats_refresh_bus.dart';
import '../domain/chat_message.dart';

class AiRepository {
  final Dio _dio = ApiClient().dio;

  Future<({String conversationId, ChatMessage message, bool fromMemory, String? memoryId})> ask({
    required String question,
    String? conversationId,
    String? brand,
    String? model,
  }) async {
    final res = await _dio.post('/ai/ask', data: {
      'question': question,
      if (conversationId != null) 'conversationId': conversationId,
      if (brand != null) 'brand': brand,
      if (model != null) 'model': model,
    });
    StatsRefreshBus.bump();
    return (
      conversationId: res.data['conversationId'] as String,
      message: ChatMessage.fromJson(res.data['message']),
      fromMemory: res.data['fromMemory'] == true,
      memoryId: res.data['memoryId'] as String?,
    );
  }

  Future<({String conversationId, ChatMessage message, bool fromMemory, String? memoryId})> askWithImage({
    required File image,
    String? question,
    String? conversationId,
  }) async {
    final formData = FormData.fromMap({
      'question': question ?? '',
      if (conversationId != null) 'conversationId': conversationId,
      'image': await MultipartFile.fromFile(image.path),
    });
    final res = await _dio.post('/ai/ask-with-image', data: formData);
    StatsRefreshBus.bump();
    return (
      conversationId: res.data['conversationId'] as String,
      message: ChatMessage.fromJson(res.data['message']),
      fromMemory: res.data['fromMemory'] == true,
      memoryId: res.data['memoryId'] as String?,
    );
  }

  Future<List<dynamic>> listConversations() async {
    final res = await _dio.get('/chat/conversations');
    return (res.data as List).where((c) => c['type'] == 'AI').toList();
  }

  Future<List<ChatMessage>> listMessages(String conversationId) async {
    final res = await _dio.get('/chat/conversations/$conversationId/messages');
    return (res.data as List).map((m) => ChatMessage.fromJson(m)).toList();
  }

  Future<String> createNewConversation() async {
    final res = await _dio.post('/ai/conversations/new');
    return res.data['id'] as String;
  }

  Future<void> toggleFavorite(String messageId) => _dio.post('/chat/messages/$messageId/favorite');

  Future<void> verifyMemory(String memoryId) => _dio.patch('/ai/technical-memory/$memoryId/verify');
}
