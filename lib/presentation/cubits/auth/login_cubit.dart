// ignore_for_file: use_build_context_synchronously

import 'package:ride_on/domain/entities/login_data.dart';
import 'package:ride_on/data/repositories/auth_repository.dart';
import 'package:ride_on/core/extensions/workspace.dart';
import 'package:ride_on/core/services/firebase_phone_auth_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ride_on/presentation/cubits/auth/user_authenticate_cubit.dart';

abstract class AuthLoginState extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoginInitial extends AuthLoginState {}

class LoginLoading extends AuthLoginState {}

class LoginSuccess extends AuthLoginState {
  final LoginModel loginModel;
  LoginSuccess(this.loginModel);
  @override
  List<Object?> get props => [loginModel];
}

class LoginFailure extends AuthLoginState {
  final String error;
  LoginFailure(this.error);
  @override
  List<Object?> get props => [error];
}

class LoginCloseLoading extends AuthLoginState {}

class AuthLoginCubit extends Cubit<AuthLoginState> {
  final AuthRepository authRepository;
  AuthLoginCubit(this.authRepository) : super(LoginInitial());

  Future<void> login(
      {required BuildContext context,
      required String phoneNumber,
      required String phoneCountry}) async {
    try {
      emit(LoginLoading());
      var response = await authRepository.login(
          phoneCountry: phoneCountry, phoneNumber: phoneNumber);

      // If phone number is not found (new user), auto-fallback to signUp API
      if (response['status'] != 200) {
        response = await authRepository.signUp(
          phoneNumber: phoneNumber,
          phoneCountry: phoneCountry,
          name: "",
          email: "",
        );
      }

      if (response['status'] == 200) {
        loginModel = LoginModel.fromJson(response);
        if (loginModel != null && loginModel!.data != null) {
          token = loginModel!.data!.token ?? '';
        }

        // Attempt Firebase Phone Auth to capture verification ID and send SMS
        try {
          await FirebasePhoneAuthService.instance.sendOtp(
            phoneCountry: phoneCountry,
            phoneNumber: phoneNumber,
          );
        } catch (e) {
          debugPrint("Firebase Phone Auth sendOtp info: $e");
        }

        // Note: Do NOT call resendOtp here — it regenerates the backend OTP
        // and invalidates the reset_token we need for userMobileLogin

        context.read<SetCountryCubit>().reset();

        emit(LoginSuccess(LoginModel.fromJson(response)));
      } else {
        emit(LoginFailure(response['error'] ?? "Unable to proceed"));
      }
    } catch (e) {
      context.read<SetCountryCubit>().reset();
      emit(LoginFailure('Something went wrong: $e'));
    }
  }

  void resetState() {
    emit(LoginInitial());
  }
}
