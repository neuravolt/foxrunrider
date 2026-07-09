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
      var response = await FirebasePhoneAuthService.instance.resendOtp(
        phoneNumber: phone ?? "",
        phoneCountry: phoneCountry ?? "",
      );

      if (response["status"] == 200) {
        emit(ResendOtpSuccess(""));
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
