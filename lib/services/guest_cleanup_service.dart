import 'package:supabase_flutter/supabase_flutter.dart';

class GuestCleanupService {
  static const guestEmail = 'invitado@demo.com';

  static Future<void> cleanupGuestData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.email == guestEmail) {
      final userId = user.id;
      await Supabase.instance.client.from('transactions').delete().eq('user_id', userId);
      await Supabase.instance.client.from('clients').delete().eq('user_id', userId);
    }
  }
}
