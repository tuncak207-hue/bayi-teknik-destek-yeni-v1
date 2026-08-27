import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

final isLoggedInProvider = FutureProvider<bool>((ref) {
  return ref.read(authRepositoryProvider).isLoggedIn();
});
