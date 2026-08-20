import 'package:ride_on/data/repositories/auth_repository.dart';
import 'package:ride_on/core/services/firebase_phone_auth_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class ResendOtpState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ResendOtpInitial extends ResendOtpState {}

class ResendOtpLoading extends ResendOtpState {}

class ResendOtpSuccess extends ResendOtpState {
  final String? otpValue;
  ResendOtpSuccess(this.otpValue);
  @override
  List<Object?> get props => [otpValue];
}

class ResendOtpFailure extends ResendOtpState {
  final String error;
  ResendOtpFailure(this.error);
  @override
  List<Object?> get props => [error];
}

class AuthResendOtpCubit extends Cubit<ResendOtpState> {
  final AuthRepository authRepository;
  AuthResendOtpCubit(this.authRepository) : super(ResendOtpInitial());

  Future<void> resendOtp({
    String? phone,
    String? phoneCountry,
  }) async {
    try {
      emit(ResendOtpLoading());

      // Primary: Firebase Phone Auth resend
      var response = await FirebasePhoneAuthService.instance.resendOtp(
        phoneNumber: phone ?? "",
        phoneCountry: phoneCountry ?? "",
      );

      // Fallback: Backend SMS resend if Firebase fails
      if (response["status"] != 200) {
        try {
          var backendRes = await authRepository.resendOtp(
            phone: phone,
            phoneCountry: phoneCountry,
          );
          if (backendRes["status"] == 200) {
            response = {"status": 200, "message": "OTP resent successfully"};
          }
        } catch (_) {}
      }

      if (response["status"] == 200) {
        emit(ResendOtpSuccess("OTP resent successfully"));
      } else {
        emit(ResendOtpFailure(
            response['error'] ?? "Unable to resend OTP."));
      }
    } catch (error) {
      emit(ResendOtpFailure(error.toString()));
    }
  }

  void resetState() {
    emit(ResendOtpInitial());
  }
}
