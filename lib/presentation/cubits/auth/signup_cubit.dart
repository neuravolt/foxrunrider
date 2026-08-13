// ignore_for_file: use_build_context_synchronously

import 'package:ride_on/domain/entities/login_data.dart';
import 'package:ride_on/data/repositories/auth_repository.dart';
import 'package:ride_on/core/services/data_store.dart';
import 'package:ride_on/core/extensions/workspace.dart';
import 'package:ride_on/core/services/firebase_phone_auth_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ride_on/presentation/cubits/auth/user_authenticate_cubit.dart';

import '../logout_cubit.dart';

abstract class AuthSignUpState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SignUpInitial extends AuthSignUpState {}

class SignUpLoading extends AuthSignUpState {}

class SignUpSuccess extends AuthSignUpState {
  final LoginModel loginModel;
  SignUpSuccess(this.loginModel);

  @override
  List<Object?> get props => [loginModel];
}

class SignUpFailure extends AuthSignUpState {
  final String error;
  SignUpFailure(this.error);
}

class AuthSignUpCubit extends Cubit<AuthSignUpState> {
  final AuthRepository repositorySignUp;
  AuthSignUpCubit(this.repositorySignUp) : super(SignUpInitial());

  Future<void> signUp(
      {required BuildContext context,
      String? name,
      String? phoneNumber,
      String? email,
      String? phoneCountry,
      String? defaultCountry}) async {
    try {
      box.delete('UserData');
      clearData(context);
      emit(SignUpLoading());
      final response = await repositorySignUp.signUp(
          email: email,
          name: name,
          phoneCountry: phoneCountry,
          phoneNumber: phoneNumber,
          defaultCountry: defaultCountry);
      if (response["status"] == 200) {
        loginModel = LoginModel.fromJson(response);

        token = loginModel!.data!.token!;
        final firebaseOtpResponse = await FirebasePhoneAuthService.instance.sendOtp(
          phoneCountry: phoneCountry ?? "",
          phoneNumber: phoneNumber ?? "",
        );
        if (firebaseOtpResponse["status"] != 200) {
          final hasBackendOtp = loginModel?.data?.resetToken != null || loginModel?.data?.otpValue != null;
          if (!hasBackendOtp) {
            emit(SignUpFailure(
                firebaseOtpResponse["error"] ?? "Unable to send OTP."));
            return;
          }
          debugPrint("Firebase Phone Auth info: ${firebaseOtpResponse["error"]}. Proceeding with backend OTP flow.");
        }
        context.read<SetCountryCubit>().reset();

        emit(SignUpSuccess(LoginModel.fromJson(response)));
      } else {
        emit(SignUpFailure(response["error"]));
      }
    } catch (err) {
      context.read<SetCountryCubit>().reset();
      emit(SignUpFailure("Something went wrong"));
    }
  }

  void resetState() {
    emit(SignUpInitial());
  }
}
