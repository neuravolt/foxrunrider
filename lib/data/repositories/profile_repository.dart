import 'package:ride_on/core/services/http.dart';
import 'package:ride_on/core/extensions/workspace.dart';
import 'package:flutter/material.dart';
import 'package:ride_on/core/utils/translate.dart';

import '../../core/services/config.dart';
import '../../core/services/data_store.dart';

class ProfileRepository {
  Future<Map<String, dynamic>> editProfile(
      {required Map<String, dynamic> postData}) async {
    try {
      var response = await httpPost(Config.editProfile, postData,
          context: navigatorKey.currentContext!);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      var response = await httpPost(Config.deleteAccount, {},
          context: navigatorKey.currentState!.context);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadProfileImage(
      {required Map<String, dynamic> postData}) async {
    try {
      var response = await httpPost(Config.uploadProfileImage, postData,
          context: navigatorKey.currentContext!);
      return response;
    } catch (e) {
      rethrow;
    }
  }
  Future<Map<String, dynamic>> getSosData(
      {required Map<String, dynamic> postData}) async {
    try {
      var response = await httpGet(Config.sos, postData,
          context: navigatorKey.currentContext!);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getStaticPage(
      BuildContext context, String data) async {
    try {
      dynamic response;
      final lower = data.toLowerCase();
      String pageId = "4"; // Default to Help & Support

      if (lower.contains("about") || lower.contains("हमारे बारे")) {
        pageId = "2";
      } else if (lower.contains("help") ||
          lower.contains("support") ||
          lower.contains("सहायता") ||
          lower.contains("समर्थन")) {
        pageId = "4";
      } else if (lower.contains("feedback") || lower.contains("प्रतिक्रिया")) {
        pageId = "25";
      } else if (lower.contains("terms") ||
          lower.contains("privacy") ||
          lower.contains("condition") ||
          lower.contains("नियम") ||
          lower.contains("शर्त")) {
        pageId = "11";
      }

      final langCode = lanBox.get('lCode') ?? 'en';
      response = await httpGet(
        Config.staticPage,
        {"id": pageId, "lang": langCode, "lang_code": langCode},
        context: context,
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getGeneralData(
      {required Map<String, dynamic> postData}) async {
    try {
      var response = await httpGet(Config.getgeneralSettings, postData,
          context: navigatorKey.currentContext!);
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
