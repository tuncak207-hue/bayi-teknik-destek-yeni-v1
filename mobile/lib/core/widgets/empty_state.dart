import 'package:flutter/material.dart';
import 'app_components.dart';

/// Geriye dönük uyumluluk sarmalayıcısıdır. Eski ekranlar bu sınıfı
/// kullanmaya devam etse de artık yeni AppEmptyState görselini alır.
class EmptyState extends AppEmptyState {
  const EmptyState({
    super.key,
    required super.icon,
    required super.title,
    super.description,
    super.actionLabel,
    super.onAction,
  });
}
