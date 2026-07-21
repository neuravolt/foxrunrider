import 'package:flutter/material.dart';
import '../../core/services/config.dart';
import '../../core/services/http.dart';

class WalletRepository {
  Future<Map<String, dynamic>> getWallet({required BuildContext context}) async {
    try {
      final response = await httpGet(
        Config.getWallet,
        {},
        context: context,
      );
      return response;
    } catch (error) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getWalletTransactions({
    required BuildContext context,
    int limit = 15,
    int offset = 0,
  }) async {
    try {
      final response = await httpGet(
        Config.getWalletTransactions,
        {'limit': limit, 'offset': offset},
        context: context,
      );
      return response;
    } catch (error) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addMoney({
    required BuildContext context,
    required double amount,
    String currency = 'INR',
  }) async {
    try {
      final response = await httpPost(
        Config.addMoney,
        {'amount': amount, 'currency': currency},
        context: context,
      );
      return response;
    } catch (error) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyPayment({
    required BuildContext context,
    required String orderId,
    required String paymentId,
    required String signature,
    required double amount,
    String currency = 'INR',
  }) async {
    try {
      final response = await httpPost(
        Config.verifyPayment,
        {
          'razorpay_order_id': orderId,
          'razorpay_payment_id': paymentId,
          'razorpay_signature': signature,
          'amount': amount,
          'currency': currency,
        },
        context: context,
      );
      return response;
    } catch (error) {
      rethrow;
    }
  }
}
