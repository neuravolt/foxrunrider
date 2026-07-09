import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class FirebasePhoneAuthService {
  FirebasePhoneAuthService._();
  static final FirebasePhoneAuthService instance = FirebasePhoneAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  int? _resendToken;
  PhoneAuthCredential? _autoCredential;

  Future<Map<String, dynamic>> sendOtp({
    required String phoneCountry,
    required String phoneNumber,
    int? forceResendingToken,
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    final fullPhoneNumber =
        _normalizePhoneNumber(phoneCountry: phoneCountry, phoneNumber: phoneNumber);

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: forceResendingToken,
        verificationCompleted: (PhoneAuthCredential credential) {
          _autoCredential = credential;
          if (!completer.isCompleted) {
            completer.complete({
              "status": 200,
              "message": "OTP auto verification available",
            });
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            completer.complete({
              "status": 400,
              "error": _mapFirebaseError(e),
            });
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          if (!completer.isCompleted) {
            completer.complete({
              "status": 200,
              "message": "OTP sent successfully",
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );

      return await completer.future.timeout(
        const Duration(seconds: 65),
        onTimeout: () => {
          "status": 408,
          "error": "OTP request timed out. Please try again.",
        },
      );
    } catch (e) {
      return {
        "status": 500,
        "error": "Unable to send OTP. Please try again.",
      };
    }
  }

  Future<Map<String, dynamic>> resendOtp({
    required String phoneCountry,
    required String phoneNumber,
  }) async {
    return sendOtp(
      phoneCountry: phoneCountry,
      phoneNumber: phoneNumber,
      forceResendingToken: _resendToken,
    );
  }

  Future<Map<String, dynamic>> verifyOtp(String otpCode) async {
    try {
      final PhoneAuthCredential credential;

      if (_autoCredential != null) {
        credential = _autoCredential!;
      } else {
        if (_verificationId == null || _verificationId!.isEmpty) {
          return {
            "status": 400,
            "error": "OTP session expired. Please resend OTP.",
          };
        }
        credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: otpCode,
        );
      }

      await _auth.signInWithCredential(credential);
      return {
        "status": 200,
        "message": "OTP verified successfully",
      };
    } on FirebaseAuthException catch (e) {
      return {
        "status": 400,
        "error": _mapFirebaseError(e),
      };
    } catch (_) {
      return {
        "status": 500,
        "error": "OTP verification failed. Please try again.",
      };
    }
  }

  String _normalizePhoneNumber({
    required String phoneCountry,
    required String phoneNumber,
  }) {
    var country = phoneCountry.trim();
    if (!country.startsWith("+")) {
      country = "+$country";
    }
    final number = phoneNumber.replaceAll(RegExp(r"\s+"), "");
    return "$country$number";
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case "invalid-phone-number":
        return "Invalid phone number format.";
      case "invalid-verification-code":
        return "Invalid OTP. Please enter the correct code.";
      case "session-expired":
      case "code-expired":
      case "invalid-verification-id":
        return "OTP expired. Please resend OTP.";
      case "quota-exceeded":
        return "Too many OTP requests. Please try again later.";
      case "network-request-failed":
        return "Network error. Please check your internet connection.";
      case "too-many-requests":
        return "Too many attempts. Please try again later.";
      default:
        return e.message ?? "OTP operation failed. Please try again.";
    }
  }
}
