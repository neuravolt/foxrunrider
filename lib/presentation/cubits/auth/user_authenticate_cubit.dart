// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:ride_on/domain/entities/login_data.dart';
import 'package:ride_on/data/repositories/auth_repository.dart';
import 'package:ride_on/core/services/data_store.dart';
import 'package:ride_on/core/extensions/workspace.dart';
import 'package:ride_on/core/services/firebase_phone_auth_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../book_ride_cubit.dart';
import '../logout_cubit.dart';

abstract class AuthUserAuthenticateState extends Equatable {
  @override
  List<Object?> get props => [];
}

class UserInitial extends AuthUserAuthenticateState {}

class UserLoading extends AuthUserAuthenticateState {}

class UserSucesss extends AuthUserAuthenticateState {
  final LoginModel loginModel;
  UserSucesss(this.loginModel);
  @override
  List<Object?> get props => [loginModel];
}

class UserFailure extends AuthUserAuthenticateState {
  final String error;
  UserFailure(this.error);
  @override
  List<Object?> get props => [error];
}

class AuthUserAuthenticateCubit extends Cubit<AuthUserAuthenticateState> {
  AuthRepository authRepository;
  AuthUserAuthenticateCubit(this.authRepository) : super(UserInitial());

  Future<void> userAuthenticate(
      {required BuildContext context,
      required String phoneNumber,
      required String phoneCountry,
      required String otpValue,
      String? backendOtpValue}) async {
    try {
      clearData(context);
      emit(UserLoading());

      debugPrint("=== OTP DEBUG ===");
      debugPrint("otpValue (user typed): $otpValue");
      debugPrint("backendOtpValue (reset_token): $backendOtpValue");

      // Step 1: Verify user-typed SMS code with Firebase Auth
      final firebaseResponse =
          await FirebasePhoneAuthService.instance.verifyOtp(otpValue);

      if (firebaseResponse["status"] == 200) {
        // Step 2: Firebase confirmed the SMS code is correct.
        // Send the backend's reset_token to authorize the session.
        final String tokenForBackend = (backendOtpValue?.isNotEmpty ?? false)
            ? backendOtpValue!
            : otpValue;

        var response = await authRepository.userAuthenticateLogin(
            phoneNumber: phoneNumber,
            phoneCountry: phoneCountry,
            otpValue: tokenForBackend);

        if (response["status"] == 200) {
          _saveUserDataAndEmit(context, response);
          return;
        } else {
          emit(UserFailure(response["error"] ?? "Wrong OTP"));
        }
      } else {
        final errorMsg = firebaseResponse["error"]?.toString() ?? "Wrong OTP";
        emit(UserFailure(errorMsg));
      }
    } catch (e) {
      emit(UserFailure("Something went wrong $e "));
    }
  }

  void _saveUserDataAndEmit(BuildContext context, Map<String, dynamic> response) {
    box.put('Remember', true);
    box.put('Firstuser', true);
    UserData userObj = UserData();
    loginModel = LoginModel.fromJson(response);
    context.read<BookRideRealTimeDataBaseCubit>().updateUserDetails(
        userName: loginModel!.data!.firstName,
        userPhoneNumber:
            "${loginModel!.data!.phoneCountry} ${loginModel!.data!.phone}",
        userId: loginModel!.data!.id!.toInt());
    userObj.saveLoginData("UserData", jsonEncode(response));
    if (loginModel != null && loginModel!.data != null) {
      token = loginModel!.data!.token ?? '';
    }

    emit(UserSucesss(LoginModel.fromJson(response)));
  }

  void resetState() {
    emit(UserInitial());
  }
}

// set_country_cubit.dart

class SetCountryState extends Equatable {
  final String dialCode; // e.g., +91
  final String countryCode; // e.g., IN

  const SetCountryState({
    required this.dialCode,
    required this.countryCode,
  });

  SetCountryState copyWith({
    String? dialCode,
    String? countryCode,
  }) {
    return SetCountryState(
      dialCode: dialCode ?? this.dialCode,
      countryCode: countryCode ?? this.countryCode,
    );
  }

  @override
  List<Object?> get props => [dialCode, countryCode];
}

class SetCountryCubit extends Cubit<SetCountryState> {
  SetCountryCubit()
      : super(const SetCountryState(
          dialCode: "+91",
          countryCode: "IN",
        ));

  void setCountry({required String dialCode, required String countryCode}) {
    emit(SetCountryState(dialCode: dialCode, countryCode: countryCode));
  }

  void reset() {
   }void clear() {
    emit(const SetCountryState(dialCode: "+91", countryCode: "IN"));
  }
}
