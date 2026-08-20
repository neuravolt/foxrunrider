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

abstract class OtpVerifyState extends Equatable {
  @override
  List<Object?> get props => [];
}

class OtpInitial extends OtpVerifyState {}

class OtpLoading extends OtpVerifyState {}

class OtpSuccess extends OtpVerifyState {
  final LoginModel loginModel;
  final String? successMessage;
  OtpSuccess(this.loginModel, {this.successMessage});
  @override
  List<Object?> get props => [loginModel, successMessage];
}

class OtpFailure extends OtpVerifyState {
  final String error;
  OtpFailure(this.error);
  @override
  List<Object?> get props => [error];
}

class AuthOtpVerifyCubit extends Cubit<OtpVerifyState> {
  final AuthRepository authRepository;

  AuthOtpVerifyCubit(this.authRepository) : super(OtpInitial());

  Future<void> otpVerification(
      {BuildContext? context,
      String? phone,
      String? otpValue,
      String? countryCode,
      String? email,
      String? resetToken,
      String? defaultCountry,
      bool? changeEmail,
      bool? changeMobile,
      bool? loginWithGoogle,
      String? backendOtpValue}) async {
    try {
      emit(OtpLoading());
      final firebaseResponse =
          await FirebasePhoneAuthService.instance.verifyOtp(otpValue ?? "");
      if (firebaseResponse["status"] != 200) {
        debugPrint("Firebase verifyOtp info: ${firebaseResponse["error"]}. Proceeding with backend OTP verification.");
      }

      final otpForBackend = otpValue ?? "";

      if (changeMobile == true || loginWithGoogle == true) {
        final response = await authRepository.forChangePhoneNumber(
            number: phone,
            cuntryCode: countryCode,
            otp: otpForBackend,
            defaultCountry: defaultCountry);
        if (response['status'] == 200) {
          loginModel = LoginModel.fromJson(response);
          UserData userObj = UserData();
          userObj.saveLoginData("UserData", jsonEncode(response));
          emit(OtpSuccess(LoginModel.fromJson(response),
              successMessage: response["message"]));
        } else {
          emit(OtpFailure(response['error']));
        }
      } else {
        final response = await authRepository.otpVerify(
            phone: phone,
            otpValue: otpForBackend,
            countryCode: countryCode,
            email: email,
            resetToken: otpForBackend,
            changeEmail: changeEmail,
            changeMobile: changeMobile,
            defaultCountry: defaultCountry);

        if (response["status"] == 200) {
          box.put('Remember', true);
          box.put('Firstuser', true);
          loginModel = LoginModel.fromJson(response);
          context?.read<BookRideRealTimeDataBaseCubit>().updateUserDetails(
              userName: loginModel!.data!.firstName,
              userPhoneNumber:
                  "${loginModel!.data!.phoneCountry} ${loginModel!.data!.phone}",
              userId: loginModel!.data!.id!.toInt());

          UserData userObj = UserData();

          userObj.saveLoginData("UserData", jsonEncode(response));
          emit(
            OtpSuccess(LoginModel.fromJson(response),
                successMessage: response["message"]),
          );
        } else {
          emit(OtpFailure(response['error']));
        }
      }
    } catch (e) {
      emit(OtpFailure("Something went wrong $e"));
    }
  }

  void resetState() {
    emit(OtpInitial());
  }
}
