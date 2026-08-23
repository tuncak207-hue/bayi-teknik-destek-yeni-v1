class Citation {
  final String documentId;
  final String documentTitle;
  final String brand;
  final String model;
  final String version;
  final int page;

  Citation({
    required this.documentId,
    required this.documentTitle,
    required this.brand,
    required this.model,
    required this.version,
    required this.page,
  });

  factory Citation.fromJson(Map<String, dynamic> json) {
    final chunk = json['documentChunk'];
    final version = chunk['documentVersion'];
    final document = version['document'];
    return Citation(
      documentId: document['id'],
      documentTitle: document['title'],
      brand: document['brand'],
      model: document['model'],
      version: version['version'],
      page: json['page'],
    );
  }
}

enum SenderType { user, ai }

enum Confidence { high, low, none }

class ChatMessage {
  final String id;
  final String content;
  final SenderType senderType;
  final Confidence confidence;
  final List<Citation> citations;
  final String? attachmentUrl;
  final String? attachmentType;
  final DateTime createdAt;
  // Kullanıcı isteği: "doğrulama sürekli kalmalı" — bu AI mesajının
  // bağlı olduğu Teknik Hafıza kaydı ve doğrulanmış olup olmadığı,
  // artık backend'den her mesaj yüklendiğinde kalıcı olarak geliyor.
  final String? memoryId;
  final bool memoryIsVerified;

  ChatMessage({
    required this.id,
    required this.content,
    required this.senderType,
    required this.confidence,
    required this.citations,
    required this.createdAt,
    this.attachmentUrl,
    this.attachmentType,
    this.memoryId,
    this.memoryIsVerified = false,
  });

  /// Doğrulama sonrası, listedeki mesajı yerinde güncelleyebilmek için.
  ChatMessage copyWith({bool? memoryIsVerified}) {
    return ChatMessage(
      id: id,
      content: content,
      senderType: senderType,
      confidence: confidence,
      citations: citations,
      createdAt: createdAt,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      memoryId: memoryId,
      memoryIsVerified: memoryIsVerified ?? this.memoryIsVerified,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      content: json['content'],
      senderType: json['senderType'] == 'AI' ? SenderType.ai : SenderType.user,
      confidence: switch (json['confidence']) {
        'HIGH' => Confidence.high,
        'LOW' => Confidence.low,
        _ => Confidence.none,
      },
      citations: (json['citations'] as List<dynamic>? ?? [])
          .map((c) => Citation.fromJson(c as Map<String, dynamic>))
          .toList(),
      attachmentUrl: json['attachmentUrl'],
      attachmentType: json['attachmentType'],
      createdAt: DateTime.parse(json['createdAt']),
      memoryId: json['memoryId'] as String?,
      memoryIsVerified: json['memoryIsVerified'] == true,
    );
  }
}
