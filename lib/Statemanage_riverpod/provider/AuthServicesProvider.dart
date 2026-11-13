import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth services/AuthService.dart';


// object create aisa hoga
//final auth = ref.read(authServiceProvider);
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});