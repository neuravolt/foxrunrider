import 'package:ride_on/core/services/http.dart';
import 'package:ride_on/core/extensions/workspace.dart';

import '../../core/services/config.dart';

class CouponRepository {
  Future<Map<String, dynamic>> getFirstBookingCoupon() async {
    try {
      var response = await httpGet(Config.getFirstBookingCoupon, {},
          context: navigatorKey.currentContext!);
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
