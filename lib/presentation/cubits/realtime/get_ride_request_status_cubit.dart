import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GetRideRequestStatusCubit extends Cubit<String> {
  GetRideRequestStatusCubit() : super("");
  final DatabaseReference _rideRequestsRef =
      FirebaseDatabase.instance.ref().child('ride_requests');

  StreamSubscription<DatabaseEvent>? _statusSubscription;

  // onValue on the status child delivers the current status immediately (onChildChanged did
  // not, so a reopened app never learned the ride was already pick_up/ongoing/completed), and
  // the previous listener is cancelled instead of piling up one per call.
  void listenToRouteStatus({required String rideId}) {
    _statusSubscription?.cancel();
    _statusSubscription =
        _rideRequestsRef.child(rideId).child('status').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value != null) emit(value.toString());
    });
  }

  void resetState() {
    _statusSubscription?.cancel();
    emit("");
  }

  @override
  Future<void> close() {
    _statusSubscription?.cancel();
    return super.close();
  }
}

class GetRideRequestPaymentCubit extends Cubit<Map<String, String>> {
  GetRideRequestPaymentCubit() : super({});

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  StreamSubscription<DatabaseEvent>? _subscription;

  void listenToPaymentStatusAndMethod({required String rideId}) {

    _subscription?.cancel();

    _subscription =
        _database.child('ride_requests').child(rideId).onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if(data==null){
       
        emit({
          'paymentStatus': "collected",
          'paymentMethod': "cash",
        });
        return;
      }

    
      // ignore: unnecessary_null_comparison
      if (data != null) {
        final paymentStatus = data['paymentStatus']?.toString() ?? '';
        final paymentMethod = data['paymentMethod']?.toString() ?? '';

        emit({
          'paymentStatus': paymentStatus,
          'paymentMethod': paymentMethod,
        });


      }
    });
  }

  void resetStatus() {
    emit({});
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
