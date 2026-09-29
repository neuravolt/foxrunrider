// ignore_for_file: empty_catches

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UpdateRideRequestParameterCubit extends Cubit<String> {
  UpdateRideRequestParameterCubit() : super("");
  final DatabaseReference _rideRequestsRef =
      FirebaseDatabase.instance.ref().child('ride_requests');

  // update() on a removed ride recreated it as a ghost node with just these fields
  // (seen live: nodes holding only paymentMethod / userImageUrl). Write only to live rides.
  Future<void> _updateIfExists(String rideId, Map<String, Object?> values) async {
    if (rideId.isEmpty) return;
    try {
      final ride = _rideRequestsRef.child(rideId);
      if (!(await ride.child('status').get()).exists) return;
      await ride.update(values);
    } catch (e) {}
  }

// Method to update the payment status using the ride ID
  void updatePaymentStatus(
      {required String rideId, required String paymentStatus}) {
    _rideRequestsRef.child(rideId).update({
      'paymentStatus': paymentStatus,
    }).then((_) {

    }).catchError((error) {

    });
    _rideRequestsRef.child(rideId).remove();
  }

  void updatePaymentMehod(
      {required String rideId, required String paymentMethod}) {
    _updateIfExists(rideId, {'paymentMethod': paymentMethod});
  }
  void updatePaymentAmountFirebase(
      {required String rideId, required String totalFare,required String couponApply,required String discountFare}) {
    _updateIfExists(rideId, {
      'travelCharges': totalFare,
      'couponApply': couponApply,
      'discountFare': discountFare
    });
  }

  Future<void> updateFirebaseUserParameter({
    required Map<String, dynamic> userParameter,
    required String rideId,
  }) async {
    await _updateIfExists(rideId, {...userParameter});
  }

  void resetState() {
    emit("");
  }
}
