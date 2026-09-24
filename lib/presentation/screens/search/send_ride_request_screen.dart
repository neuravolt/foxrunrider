import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:geolocator/geolocator.dart';
import 'package:ride_on/core/services/data_store.dart';
import 'package:ride_on/core/extensions/workspace.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:ride_on/core/utils/translate.dart';
import 'package:ride_on/presentation/screens/home/item_home_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/config.dart';
import '../../../core/utils/common_widget.dart';
import '../../../core/utils/theme/project_color.dart';
import '../../../core/utils/theme/theme_style.dart';
import '../../cubits/book_ride_cubit.dart';
import '../../cubits/general_cubit.dart';
import '../../cubits/location/get_item_price_cubit.dart';
import '../../cubits/location/get_nearby_drivers_cubit.dart';
import '../../cubits/location/set_marker_cubit.dart';
import '../../cubits/realtime/get_ride_request_status_cubit.dart';
import '../../cubits/realtime/ride_request_cubit.dart';
import '../../cubits/vehicle_data/get_vehicle_cetgegory_cubit.dart';
import '../../cubits/location/user_current_location_cubit.dart';
import '../../widgets/sos_widget.dart';
import '../payment/rider_payment_screen.dart';

class SendRideRequestScreen extends StatefulWidget {
  final Map<String, dynamic> selectedVehicleData;

  final String statusOfRide;
  final String? pickUpOtp, rideId, bookingId, paymentUrl;

  const SendRideRequestScreen(
      {super.key,
      required this.selectedVehicleData,
      required this.statusOfRide,
      this.rideId,
      this.pickUpOtp,
      this.bookingId,
      this.paymentUrl});

  @override
  State<SendRideRequestScreen> createState() => _SendRideRequestScreenState();
}

class _SendRideRequestScreenState extends State<SendRideRequestScreen> {
  double dropLat = 0.0;
  double dropLng = 0.0;
  double pickLat = 0.0;
  double pickLng = 0.0;
  double driverLat = 0.0;
  double driverLng = 0.0;
  String fetchDistance = "";
  String fetchDuration = "";
  String otp = "";
  String rideId = "";
  String bookingId = "";
  String rideStatus = "";
  String paymentUrl = '';

  Set<Polyline> polylines = {};
  Set<Marker> markers = {};
  bool isSuccessFirst = false;
  bool isCurrentScreenActive = true;
  List<LatLng> polylineCoordinates = [];
  int currentPolylineIndex = 0;
  Timer? locationUpdateTimer;
  Timer? fetchTimer;
  StreamSubscription? _driverLocationSubscription;
  bool _isDriverCancelDialogShown = false;
  @override
  void initState() {
    super.initState();
    ScreenTracker.setCurrentScreen("RideTrackingScreen");
    isManuallyCancelled = false;
    isCurrentScreenActive = true;
    context.read<UserMarkerCubit>().clear();
    context.read<GetPolylineCubit>().resetPolylines();

    if (widget.statusOfRide.isEmpty) {
      getNearByDrivers();
      box.put('selected_vehicle', jsonEncode(widget.selectedVehicleData));
    } else if (widget.statusOfRide == "accepted") {
      setAllLatLang();
      _handleBookRideSuccess(context, widget.pickUpOtp.toString(),
          widget.rideId.toString(), widget.bookingId.toString());
      paymentUrl = widget.paymentUrl ?? "";
    } else if (widget.statusOfRide == "ongoing") {
      setAllLatLang();
      otp = widget.pickUpOtp.toString();
      rideId = widget.rideId.toString();
      bookingId = widget.bookingId.toString();
      rideStatus = widget.statusOfRide;
      paymentUrl = widget.paymentUrl ?? "";

      context
          .read<GetRideRequestStatusCubit>()
          .listenToRouteStatus(rideId: widget.rideId.toString());

      _handleLiveRideSuccess(context);
    }
  }

  Future<void> getNearByDrivers() async {
    final stateData = context.read<BookRideRealTimeDataBaseCubit>().state;
    await context.read<DriverNearByCubit>().getNearbyDrivers(
        checkRestart: false,
        pickupLat: double.tryParse(stateData.pickupAddressLatitude) ?? 0.0,
        pickupLng: double.tryParse(stateData.pickupAddressLongitude) ?? 0.0,
        vehicleTypeId: widget.selectedVehicleData["id"].toString(),
        distance: double.tryParse(
                context.read<LocationAccuracyThresholdCubit>().state.value ?? "3") ??
            3.0);
  }

  bool isInilize = false;

  Future<void> _initializeRideRequest(
      {required List<Map<String, dynamic>> nearbyDrivers,
      required bool checkRestart}) async {
    final stateData = context.read<BookRideRealTimeDataBaseCubit>().state;
    final rideRequestData = context.read<RideRequestCubit>().state;
    if (checkRestart == true) {
      rideId = rideRequestData.rideId;
    } else {
      if (isInilize) return;
      isInilize = true;
      rideId = FirebaseFirestore.instance.collection('temp').doc().id;
    }
    try {
      await context.read<RideRequestCubit>().createDriverData(
          rideId: rideId,
          checkRestart: checkRestart,
          durationForSearch: int.parse(
              context.read<DriverSearchIntervalCubit>().state.value ?? "60"),
          routeDistance: widget.selectedVehicleData["distance"].toString(),
          context: context,
          nearbyDrivers: nearbyDrivers,
          userId: stateData.userId.toString(),
          userName: stateData.userName,
          pickupLat: double.tryParse(stateData.pickupAddressLatitude) ?? 0.0,
          pickupLng: double.tryParse(stateData.pickupAddressLongitude) ?? 0.0,
          pickupAddress: stateData.pickupAddress,
          dropoffLat: double.tryParse(stateData.dropoffAddressLatitude) ?? 0.0,
          dropoffLng: double.tryParse(stateData.dropoffAddressLongitude) ?? 0.0,
          userPhoneNumber: loginModel?.data?.phone ?? "",
          dropoffAddress: stateData.dropoffAddress,
          travelCharges: widget.selectedVehicleData["fare"].toString(),
          routeStatus: "pending",
          userImageUrl: myImage,
          totalTime: widget.selectedVehicleData["duration"].toString());
      setState(() {
        pickLat = double.tryParse(stateData.pickupAddressLatitude) ?? 0.0;
        pickLng = double.tryParse(stateData.pickupAddressLongitude) ?? 0.0;
        dropLat = double.tryParse(stateData.dropoffAddressLatitude) ?? 0.0;
        dropLng = double.tryParse(stateData.dropoffAddressLongitude) ?? 0.0;
        driverLat = stateData.acceptedDriverLat;
        driverLng = stateData.acceptedDriverLng;
      });
    } catch (e) {
      debugPrint("Error initializing ride request: $e");
      showErrorToastMessage("Failed to send ride request.");
    }
  }

  void setAllLatLang() {
    final stateData = context.read<BookRideRealTimeDataBaseCubit>().state;
    setState(() {
      pickLat = double.tryParse(stateData.pickupAddressLatitude) ?? 0.0;
      pickLng = double.tryParse(stateData.pickupAddressLongitude) ?? 0.0;
      dropLat = double.tryParse(stateData.dropoffAddressLatitude) ?? 0.0;
      dropLng = double.tryParse(stateData.dropoffAddressLongitude) ?? 0.0;
      driverLat = context.read<RideRequestCubit>().state.acceptedDriverLat;
      driverLng = context.read<RideRequestCubit>().state.acceptedDriverLng;
    });
  }

  Future<void> _updateRide(
      {required String updatedRideId, required String upDatedBookingId}) async {
    if (updatedRideId.isEmpty || upDatedBookingId.isEmpty) {
      debugPrint("Invalid rideId or bookingId");
      return;
    }

    final rideRequestRef =
        FirebaseDatabase.instance.ref().child("ride_requests");
    try {
      await rideRequestRef.child(updatedRideId).update({
        'bookingId': upDatedBookingId,
        'status': 'accepted',
      });
      debugPrint("Ride updated successfully.");
    } catch (error) {
      debugPrint("Failed to update ride: $error");
      // showErrorToastMessage("Failed to update ride.");
    }
  }

  Future<void> _fetchDistanceAndTime({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    required bool beforePickUp,
  }) async {
    if (fromLat == 0.0 || fromLng == 0.0 || toLat == 0.0 || toLng == 0.0) {
      debugPrint("Invalid coordinates for distance/time fetch");
      return;
    }

    bool useGoogleApi = false;

    if (beforePickUp &&
        context.read<UseGoogleBeforePickupCubit>().state.value.toString() ==
            "1") {
      useGoogleApi = true;
    } else if (!beforePickUp &&
        context.read<UseGoogleAfterPickupCubit>().state.value.toString() ==
            "1") {
      useGoogleApi = true;
    }

    if (useGoogleApi) {
      debugPrint('📍 Fetching using Google Distance Matrix API (with traffic)');

      final url = 'https://maps.googleapis.com/maps/api/distancematrix/json?'
          'origins=$fromLat,$fromLng'
          '&destinations=$toLat,$toLng'
          '&departure_time=now'
          '&traffic_model=best_guess'
          '&mode=driving'
          '&key=${Config.googleKey}';

      try {
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          if (data['rows']?.isNotEmpty == true &&
              data['rows'][0]['elements'][0]['status'] == 'OK') {
            final element = data['rows'][0]['elements'][0];
            final distanceText = element['distance']?['text'] ?? '';
            final durationText = element['duration_in_traffic']?['text'] ??
                element['duration']?['text'] ??
                '';

            setState(() {
              fetchDistance = distanceText;
              fetchDuration = durationText;
            });

            debugPrint(
                '✅ Distance: $distanceText | Duration (with traffic): $durationText');
          } else {
            debugPrint('⚠️ Error: ${data['rows'][0]['elements'][0]['status']}');
          }
        } else {
          debugPrint('❌ Failed: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('❌ Exception fetching distance/time: $e');
      }
    } else {
      debugPrint('📍 Using Geolocator (approximation)');

      final meters = Geolocator.distanceBetween(fromLat, fromLng, toLat, toLng);
      final pretty = _formatDistanceAndEta(meters, avgSpeedKmph: 40);

      setState(() {
        fetchDistance = pretty['distanceText'] ?? "";
        fetchDuration = pretty['durationText'] ?? "";
      });
    }
  }

  Map<String, String> _formatDistanceAndEta(double meters,
      {double avgSpeedKmph = 40}) {
    final km = meters / 1000.0;

    final hours = km / avgSpeedKmph;
    final mins = (hours * 60).round().clamp(1, 999); // at least 1 min

    final distanceText = km >= 1
        ? '${km.toStringAsFixed(km < 10 ? 1 : 0)} km'
        : '${meters.toStringAsFixed(0)} m';
    final durationText =
        mins >= 60 ? '${(mins ~/ 60)} hr ${mins % 60} min' : '$mins min';

    return {
      'distanceText': distanceText,
      'durationText': durationText, // rough
    };
  }

  Timer? _distanceTimer;
  double updatedDriverLat = 0.0;
  double updatedDriverLng = 0.0;

  void startAutoDistanceTimer() {
    _distanceTimer?.cancel();
    _distanceTimer = Timer.periodic(
        Duration(
            seconds: int.parse(
                context.read<MinimumHitsTimeToUpdateTime>().state.value ??
                    "60")), (timer) {
      if (rideStatus == "ongoing") {
        stopAutoDistanceTimer();
        return;
      }
      _fetchDistanceAndTime(
          fromLat: double.tryParse(context
                  .read<BookRideRealTimeDataBaseCubit>()
                  .state
                  .pickupAddressLatitude) ??
              0.0,
          fromLng: double.tryParse(context
                  .read<BookRideRealTimeDataBaseCubit>()
                  .state
                  .pickupAddressLongitude) ??
              0.0,
          toLat: updatedDriverLat,
          toLng: updatedDriverLng,
          beforePickUp: true);

      setState(() {});
    });
  }

  void startAutoDistanceTimerForDropOff() {
    _distanceTimer?.cancel();
    _distanceTimer = Timer.periodic(
        Duration(
            seconds: int.parse(
                context.read<MinimumHitsTimeToUpdateTime>().state.value ??
                    "60")), (timer) {
      if (rideStatus == "complete") {
        stopAutoDistanceTimer();
        return;
      }
      _fetchDistanceAndTime(
          fromLat: updatedDriverLat,
          fromLng: updatedDriverLng,
          toLat: double.tryParse(context
                  .read<BookRideRealTimeDataBaseCubit>()
                  .state
                  .dropoffAddressLatitude) ??
              0.0,
          toLng: double.tryParse(context
                  .read<BookRideRealTimeDataBaseCubit>()
                  .state
                  .dropoffAddressLongitude) ??
              0.0,
          beforePickUp: false);

      setState(() {});
    });
  }

  void stopAutoDistanceTimer() {
    _distanceTimer?.cancel();
  }

  final DraggableScrollableController _draggableController =
      DraggableScrollableController();

  void _addUserMarker() {
    if (pickLat != 0.0 && pickLng != 0.0) {
      context.read<UserMarkerCubit>().addOrUpdateMarker(
            LatLng(pickLat, pickLng),
            'User Location',
            'User_marker',
            'assets/images/pickupmarker.png',
            85,
          );
    } else {
      debugPrint('Invalid pickup coordinates');
    }
  }

  void _addDropMarker() {
    if (dropLat != 0.0 && dropLng != 0.0) {
      context.read<UserMarkerCubit>().addOrUpdateMarker(
            LatLng(dropLat, dropLng),
            'Drop Location',
            'drop_marker',
            "assets/images/dropmarker.png",
            85,
          );
    } else {
      debugPrint('Invalid pickup coordinates');
    }
  }

  void _addDriverMarker() {
    final rideRequestState = context.read<RideRequestCubit>().state;
    final lat = rideRequestState.acceptedDriverLat;
    final lng = rideRequestState.acceptedDriverLng;

    context.read<UserMarkerCubit>().addOrUpdateMarker(
          LatLng(lat, lng),
          'Driver Location',
          'driver_marker',
          _vehicleMarkerAsset(),
          165,
        );
  }

  void _fetchPolylines() {
    final rideRequestState = context.read<RideRequestCubit>().state;
    final sourceLat = rideRequestState.acceptedDriverLat;
    final sourceLng = rideRequestState.acceptedDriverLng;

    if (pickLat != 0.0 && pickLng != 0.0) {
      context.read<GetPolylineCubit>().getPolyline(
          sourcelat: sourceLat,
          sourcelng: sourceLng,
          destinationlat: pickLat,
          destinationlng: pickLng,
          isPickupRoute: true);
    } else {
      debugPrint('Invalid coordinates for polyline');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        backgroundColor: notifires.getbgcolor,
        body: Stack(
          children: [
            _buildMapSection(),
            MultiBlocListener(
                listeners: [
                  BlocListener<GetRideRequestStatusCubit, String>(
                      listener: (context, status) {
                    final normalizedStatus = status.toLowerCase().trim();
                    if (normalizedStatus == "rejected" ||
                        normalizedStatus == "cancelled" ||
                        normalizedStatus == "canceled") {
                      if (isManuallyCancelled) return;
                      if (_isDriverCancelDialogShown) return;
                      _isDriverCancelDialogShown = true;
                      box.delete("rideId");
                      fetchTimer?.cancel();
                      locationUpdateTimer?.cancel();
                      stopAutoDistanceTimer();
                      otp = "";
                      showDriverCancelledRideDialog(context);
                      return;
                    }
                    setState(() => rideStatus = status);

                    if (rideStatus.toString() == "ongoing") {
                      _handleLiveRideSuccess(context);
                    } else if (status == "completed") {
                      stopAutoDistanceTimer();
                      fetchTimer?.cancel();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RiderPaymentScreen(
                            bookingId: bookingId,
                            rideId: rideId,
                            fare: widget.selectedVehicleData["fare"] ?? 00,
                            paymentUrl: paymentUrl,
                          ),
                        ),
                      );
                    }
                  }),
                  BlocListener<DriverNearByCubit, DriverNearByState>(
                      listener: (context, state) {
                    if (state is DriverUpdated) {
                      if (state.nearbyDrivers!.isEmpty) {
                        context
                            .read<DriverNearByCubit>()
                            .resetNearByDriverState();
                        return;
                      }

                      context.read<UserMarkerCubit>().addNearbyDrivers(
                            state.nearbyDrivers!,
                            _vehicleMarkerAsset(),
                          );

                      context.read<RideRequestCubit>().updateNearByDrivers(
                          nearbyDrivers: state.nearbyDrivers);
                      _initializeRideRequest(
                          nearbyDrivers: state.nearbyDrivers!,
                          checkRestart: state.checkRestart!);

                      context
                          .read<DriverNearByCubit>()
                          .resetNearByDriverState();
                    }

                    if (state is DriverError) {}
                  }),
                ],
                child: BlocBuilder<RideRequestCubit, RideRequestState>(
                  builder: (context, rideRequestState) {
                    if (rideRequestState.isSubmitting &&
                        // ignore: unrelated_type_equality_checks
                        rideRequestState.selectedDriverId != 0) {
                      _handleRideBooking(context, rideRequestState);
                    }
                    if (rideRequestState.rideMessage.isNotEmpty) {
                      showErrorToastMessage(rideRequestState.rideMessage);
                      context.read<RideRequestCubit>().removeRideMessage();
                    }

                    return BlocBuilder<BookRideUserCubit, BookRideUserState>(
                      builder: (context, bookRideState) {
                        if (bookRideState is BookRideUserSuccess &&
                            bookRideState.pikupOtp != null) {
                          context
                              .read<GetRideRequestStatusCubit>()
                              .listenToRouteStatus(
                                  rideId: bookRideState.rideId.toString());
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            paymentUrl = bookRideState.paymentUrl ?? "";
                            box.put("payment_url", paymentUrl);
                            _handleBookRideSuccess(
                                context,
                                bookRideState.pikupOtp.toString(),
                                bookRideState.rideId.toString(),
                                bookRideState.bookingId.toString());
                          });
                          context
                              .read<BookRideUserCubit>()
                              .removeBookRideState();
                        } else if (bookRideState is BookRideUserFailure) {
                          showErrorToastMessage(
                              bookRideState.error ?? "Failed to book ride.");
                          context
                              .read<BookRideUserCubit>()
                              .removeBookRideState();
                          box.delete("ride_data");
                          cancelRideRequest(
                              rideId: context
                                  .read<RideRequestCubit>()
                                  .state
                                  .rideId);
                        }

                        return _buildDraggableSheet(context);
                      },
                    );
                  },
                )),
          ],
        ),
      ),
    );
  }

  Future<void> cancelRideRequest({
    required String rideId,
  }) async {
    try {
      if (rideId.isEmpty) {
        throw Exception('Ride ID cannot be empty');
      }

      final DatabaseReference rideRequestsRef =
          FirebaseDatabase.instance.ref().child('ride_requests');
      final rideRef = rideRequestsRef.child(rideId);

      await rideRef.update({
        'status': 'cancelled',
      });
      final driversRef = FirebaseFirestore.instance.collection('drivers');
      final driverQuery =
          driversRef.where('ride_request.rideId', isEqualTo: rideId);
      final driverSnapshots = await driverQuery.get();

      final matchingDriverCount = driverSnapshots.docs.length;
      for (var doc in driverSnapshots.docs) {
        final driverId = doc.id;
        try {
          await driversRef.doc(driverId).update({
            'ride_request': {}, // Clear ride_request
            'rideStatus': 'available',
          });

          // ignore: empty_catches
        } catch (e) {}
      }

      await rideRef.remove();

      if (matchingDriverCount == 0) {}
    } catch (e) {
      // throw Exception('Failed to cancel ride request: $e');
    }
  }

  bool isRideBooking = false;

  void _handleRideBooking(BuildContext context, RideRequestState state) {
    if (isRideBooking) return;
    isRideBooking = true;
    final stateData = context.read<BookRideRealTimeDataBaseCubit>().state;
    final selectedItemTypeId =
        context.read<VehicleDataUpdateCubit>().state.vehicleSelectedId;
    final formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    context.read<BookRideUserCubit>().bookRide(
          context: context,
          itemId: state.itemId,
          totalFare: widget.selectedVehicleData["fare"].toString(),
          rideId: state.rideId,
          date: formattedDate,
          itemTypeId: selectedItemTypeId,
          estimatedDistance:
              context.read<GetDistanceRouteCubit>().state.distance.toString(),
          pickupAddress: stateData.pickupAddress,
          pickupLat: stateData.pickupAddressLatitude,
          pickupLng: stateData.pickupAddressLongitude,
          dropOffAddress: stateData.dropoffAddress,
          dropOffLat: stateData.dropoffAddressLatitude,
          dropOffLng: stateData.dropoffAddressLongitude,
          driverId: state.selectedDriverId.toString(),
          paymentMethod: "Cash",
        );
  }

  void _handleBookRideSuccess(
      BuildContext context, String pikupOtp, String rideID, String bookingID) {
    context
        .read<GetRideRequestStatusCubit>()
        .listenToRouteStatus(rideId: rideID.toString());
    _fetchDriverLocationFromRealtimeDB(rideID);

    if (isSuccessFirst) return;

    isSuccessFirst = true;
    _subscribeToDriverLocationRealtime(rideID);
    _updateRide(updatedRideId: rideID, upDatedBookingId: bookingID.toString());

    box.put("PickOtp", pikupOtp);
    box.put("bookingId", bookingID);

    if (widget.statusOfRide == "accepted") {
      paymentUrl = box.get("payment_url") ?? "";
    }

    otp = pikupOtp;
    bookingId = bookingID.toString();
    rideId = rideID.toString();
    context.read<UserMarkerCubit>().removeNearbyMarkers();
    _addUserMarker();
    _addDriverMarker();
    _fetchDistanceAndTime(
        fromLat: double.tryParse(context
                .read<BookRideRealTimeDataBaseCubit>()
                .state
                .pickupAddressLatitude) ??
            0.0,
        fromLng: double.tryParse(context
                .read<BookRideRealTimeDataBaseCubit>()
                .state
                .pickupAddressLongitude) ??
            0.0,
        toLat: context.read<RideRequestCubit>().state.acceptedDriverLat,
        toLng: context.read<RideRequestCubit>().state.acceptedDriverLng,
        beforePickUp: true);
    startAutoDistanceTimer();
    _fetchPolylines();
    setState(() {});
    context.read<BookRideUserCubit>().removeBookRideState();
  }

  bool isLiveRide = false;

  void _handleLiveRideSuccess(BuildContext context) {
    _fetchDriverLocationFromRealtimeDB(rideId);

    if (isLiveRide) return;
    _subscribeToDriverLocationRealtime(rideId);
    isLiveRide = true;
    context.read<UserMarkerCubit>().removeNearbyMarkers();
    context.read<UserMarkerCubit>().removeMarker("User_marker");
    _addDropMarker();
    _addDriverMarker();
    _fetchDistanceAndTime(
        fromLat: context.read<RideRequestCubit>().state.acceptedDriverLat,
        fromLng: context.read<RideRequestCubit>().state.acceptedDriverLng,
        toLat: double.tryParse(context
                .read<BookRideRealTimeDataBaseCubit>()
                .state
                .dropoffAddressLatitude) ??
            0.0,
        toLng: double.tryParse(context
                .read<BookRideRealTimeDataBaseCubit>()
                .state
                .dropoffAddressLongitude) ??
            0.0,
        beforePickUp: false);
    context.read<GetPolylineCubit>().resetPolylines();

    context.read<GetPolylineCubit>().getPolyline(
          sourcelat: context.read<RideRequestCubit>().state.acceptedDriverLat,
          sourcelng: context.read<RideRequestCubit>().state.acceptedDriverLng,
          isPickupRoute: false,
          destinationlat: double.tryParse(context
                  .read<BookRideRealTimeDataBaseCubit>()
                  .state
                  .dropoffAddressLatitude) ??
              0.0,
          destinationlng: double.tryParse(context
                  .read<BookRideRealTimeDataBaseCubit>()
                  .state
                  .dropoffAddressLongitude) ??
              0.0,
        );
    startAutoDistanceTimerForDropOff();
  }

  GoogleMapController? mapController;
  Completer<GoogleMapController> completeController = Completer();
  void zoomIn() {
    mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void zoomOut() {
    mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  ///fro live tracking

  void _subscribeToDriverLocationRealtime(String targetRideId) {
    if (targetRideId.isEmpty) return;
    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = FirebaseDatabase.instance
        .ref()
        .child('ride_requests')
        .child(targetRideId)
        .child('driverLocation')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final locationData = event.snapshot.value as Map?;
      if (locationData == null) return;

      final newLat = locationData['lat']?.toDouble();
      final newLng = locationData['lng']?.toDouble();
      updatedDriverLat = newLat;
      updatedDriverLng = newLng;
      if (newLat == null || newLng == null) return;
      if (newLat == driverLat && newLng == driverLng) return;

      if (driverLat == 0.0 || driverLng == 0.0) {
        driverLat = newLat;
        driverLng = newLng;
        _updateDriverMarkerPosition(newLat, newLng);
        return;
      }

      final nextPosition = LatLng(newLat, newLng);
      final currentPosition = LatLng(driverLat, driverLng);

      _animateMarkerToNextPosition(currentPosition, nextPosition);
    });
  }

  void _fetchDriverLocationFromRealtimeDB(String rideId) async {
    try {
      if (rideId.isEmpty) {
        return;
      }

      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('ride_requests')
          .child(rideId)
          .child('driverLocation')
          .once();

      final locationData = snapshot.snapshot.value as Map?;

      if (locationData == null) return;

      final newLat = locationData['lat']?.toDouble();
      final newLng = locationData['lng']?.toDouble();
      updatedDriverLat = newLat;
      updatedDriverLng = newLng;
      if (newLat == null || newLng == null) return;

      if (newLat == driverLat && newLng == driverLng) return;

      final nextPosition = LatLng(newLat, newLng);
      final currentPosition = LatLng(driverLat, driverLng);

      _animateMarkerToNextPosition(currentPosition, nextPosition);
      // ignore: empty_catches
    } catch (e) {}
  }

  void _updateDriverMarkerPosition(double lat, double lng) {
    context.read<UserMarkerCubit>().addOrUpdateMarker(
          LatLng(lat, lng),
          'Driver Location',
          'driver_marker',
          _vehicleMarkerAsset(),
          165,
          rotation: _driverMarkerRotation,
        );
  }

  double _driverMarkerRotation = 0.0;

  String _vehicleMarkerAsset() {
    final vehicleName = (widget.selectedVehicleData['vehicleName'] ?? '')
        .toString()
        .toLowerCase();

    if (vehicleName.contains('bike') || vehicleName.contains('motor')) {
      return 'assets/images/BIKE.png';
    }

    if (vehicleName.contains('auto') || vehicleName.contains('rickshaw')) {
      return 'assets/images/AUTO.png';
    }

    return 'assets/images/CAB.png';
  }

  @override
  void dispose() {
    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = null;
    fetchTimer?.cancel();
    locationUpdateTimer?.cancel();
    locationUpdateTimer = null;
    fetchTimer = null;
    isCurrentScreenActive = true;
    super.dispose();
  }

// Animate marker to the next position with 60 FPS fast updates
  void _animateMarkerToNextPosition(LatLng current, LatLng next) {
    const int animationDurationMs = 1000;
    const int steps = 20;

    final double latStep = (next.latitude - current.latitude) / steps;
    final double lngStep = (next.longitude - current.longitude) / steps;

    // Smooth angle difference to prevent 360 degree spin flips
    final double targetBearing = _bearingBetween(current, next);
    final angleDiff = ((targetBearing - _driverMarkerRotation + 540) % 360) - 180;

    int currentStep = 0;
    locationUpdateTimer?.cancel();

    locationUpdateTimer = Timer.periodic(
      const Duration(milliseconds: animationDurationMs ~/ steps),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (currentStep >= steps) {
          timer.cancel();
          driverLat = next.latitude;
          driverLng = next.longitude;
          _driverMarkerRotation = targetBearing;
          context.read<UserMarkerCubit>().updateDriverMarkerFast(
            next,
            _driverMarkerRotation,
          );
          return;
        }

        final double t = currentStep / steps;
        final interpolatedLat = current.latitude + latStep * currentStep;
        final interpolatedLng = current.longitude + lngStep * currentStep;
        final currentRotation = (_driverMarkerRotation + angleDiff * t + 360) % 360;

        driverLat = interpolatedLat;
        driverLng = interpolatedLng;

        context.read<UserMarkerCubit>().updateDriverMarkerFast(
          LatLng(interpolatedLat, interpolatedLng),
          currentRotation,
        );
        currentStep++;
      },
    );
  }

  double _bearingBetween(LatLng start, LatLng end) {
    final lat1 = _degreesToRadians(start.latitude);
    final lon1 = _degreesToRadians(start.longitude);
    final lat2 = _degreesToRadians(end.latitude);
    final lon2 = _degreesToRadians(end.longitude);

    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (_radiansToDegrees(math.atan2(y, x)) + 360) % 360;
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;

  double _radiansToDegrees(double radians) => radians * 180.0 / math.pi;

  Widget _buildMapSection() {
    final rideState = context.read<BookRideRealTimeDataBaseCubit>().state;

    // Safely parse latitude and longitude
    final double latitude = double.tryParse(rideState.pickupAddressLatitude) ??
        28.6139; // default Delhi
    final double longitude =
        double.tryParse(rideState.pickupAddressLongitude) ?? 77.2090;
    return Positioned(
      bottom: 300,
      left: 0,
      right: 0,
      top: 0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PersistentGoogleMap(
            initialPosition: LatLng(
              latitude,
              longitude,
            ),
            markers: otp.isEmpty ? {} : markers,
            polylines: otp.isEmpty ? {} : polylines,
            myLocationEnabled: false,
            onMapCreated: (controller) {
              if (!completeController.isCompleted) {
                completeController.complete(controller);
                mapController = controller;
              }
            },
          ),
          if (otp.isEmpty) const PulsingCircle(),
        ],
      ),
    );
  }

  Widget _buildDraggableSheet(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _draggableController,
      initialChildSize: 0.5,
      minChildSize: 0.5,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return SafeArea(
          bottom: false,
          child: Stack(
            children: [
              rideStatus == "ongoing"
                  ? const SosButtonWidget()
                  : const SizedBox(),
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          spreadRadius: 2),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildDragHandle(),
                      if (rideStatus == "accepted")
                        _buildDriverInfoSection(context)
                      else if (otp.isEmpty)
                        _buildFindingDriverSection(context)
                      else
                        _buildDriverInfoSection(context),
                      _buildBookingDetails(context),
                      _buildRideDetails(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 50,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  String _getSelectedVehicleImage(BuildContext context) {
    if (widget.selectedVehicleData.isNotEmpty) {
      final img = widget.selectedVehicleData["image"] ??
          widget.selectedVehicleData["vehicleImage"] ??
          widget.selectedVehicleData["icon"];
      if (img != null && img.toString().isNotEmpty) {
        return img.toString();
      }
    }
    try {
      final selectedId =
          context.read<VehicleDataUpdateCubit>().state.vehicleSelectedId;
      final categoryState = context.read<SetVehicleCategoryCubit>().state;
      if (categoryState.itemList.isNotEmpty) {
        final match = categoryState.itemList.firstWhere(
          (item) => item.id == selectedId,
          orElse: () => categoryState.itemList.first,
        );
        if (match.image != null && match.image!.isNotEmpty) {
          return match.image!;
        }
      }
    } catch (_) {}
    return "";
  }

  Widget _buildVehicleImageWidget(String imagePath) {
    if (imagePath.isEmpty) {
      return Image.asset(
        "assets/images/search_loading.gif",
        height: 70,
        fit: BoxFit.contain,
      );
    }

    if (imagePath.endsWith('.svg')) {
      if (imagePath.startsWith('http')) {
        return SvgPicture.network(
          imagePath,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            ),
          ),
        );
      }
      return SvgPicture.asset(imagePath, fit: BoxFit.contain);
    }

    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        headers: const {"ngrok-skip-browser-warning": "true"},
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Image.asset(
          "assets/images/search_loading.gif",
          fit: BoxFit.contain,
        ),
      );
    }

    return Image.asset(
      imagePath,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Image.asset(
        "assets/images/search_loading.gif",
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildFindingDriverSection(BuildContext context) {
    final vehicleImage = _getSelectedVehicleImage(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Finding your driver...".translate(context),
                    textAlign: TextAlign.start,
                    style: heading3Grey1(context).copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "We’re looking for the best match for you!".translate(context),
                    textAlign: TextAlign.start,
                    style: regular(context).copyWith(color: grey1, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F4),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _buildVehicleImageWidget(vehicleImage),
            ),
          ],
        ),
        const SizedBox(height: 15),
        const CountdownSegmentedBar(),
        const SizedBox(height: 15),
      ]
    );
  }

  Widget _buildDriverInfoSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rideStatus == ""
                      ? "Driver on the way".translate(context)
                      : "Reaching".translate(context),
                  style: heading3Grey1(context).copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fetchDistance.isEmpty
                      ? "Calculating...".translate(context)
                      : "$fetchDistance ${"away".translate(context)}",
                  style: regular(context).copyWith(color: grey1, fontSize: 13),
                ),
              ],
            ),
            const Spacer(),
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25), color: const Color(0xFFFCBB2C)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.black87),
                  const SizedBox(width: 6),
                  Text(
                    fetchDuration.isEmpty ? "..." : fetchDuration,
                    style: heading2(context)
                        .copyWith(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (rideStatus != "ongoing") ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCBB2C).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_outline, size: 16, color: Color(0xFFE89A00)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Start your ride with PIN".translate(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: regular(context).copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Directionality(
                  textDirection: ui.TextDirection.ltr,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(otp.length, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.all(2),
                        width: 24,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9ED),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          otp[index],
                          style: regular2(context).copyWith(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
        _buildDriverCard(context),
      ],
    );
  }

  Widget _buildDriverCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF9F2),
            Color(0xFFFFF0D6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: BlocBuilder<RideRequestCubit, RideRequestState>(
        builder: (context, state) {
          return Row(
            children: [
              state.acceptedDriverImageUrl.isEmpty
                  ? Container(
                      height: 65,
                      width: 65,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFCBB2C).withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(CupertinoIcons.profile_circled,
                          color: themeColor, size: 50),
                    )
                  : Container(
                      height: 65,
                      width: 65,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFCBB2C).withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: myNetworkImage(state.acceptedDriverImageUrl),
                      ),
                    ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.acceptedDriverName,
                      style: heading3Grey1(context).copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.accepteDriverPhoneNumber,
                      style: regular(context).copyWith(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      state.acceptedDriverVechileNumber,
                      style: regular(context).copyWith(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Color(0xFFFCBB2C), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          state.driverRating,
                          style: regularBlack(context).copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final phone = state.accepteDriverPhoneNumber;
                      final Uri launchUri = Uri(scheme: 'tel', path: phone);
                      if (await canLaunchUrl(launchUri)) {
                        await launchUrl(launchUri);
                      }
                    },
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.phone, color: Color(0xFFFCBB2C), size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBookingDetails(BuildContext context) {
    final stateData = context.read<BookRideRealTimeDataBaseCubit>().state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
              child: Icon(Icons.receipt_long_outlined, size: 16, color: yelloColor2),
            ),
            const SizedBox(width: 12),
            Text("Booking Details".translate(context),
                style: heading3Grey1(context).copyWith(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
        const SizedBox(height: 15),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF6F8F6),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const SizedBox(height: 6),
                  Container(
                    height: 26,
                    width: 26,
                    decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.circle, color: Colors.green.shade600, size: 10),
                  ),
                  const SizedBox(height: 4),
                  Column(
                    children: List.generate(4, (index) => Container(
                      width: 1.5,
                      height: 4,
                      color: Colors.grey.withOpacity(0.4),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                    )),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 26,
                    width: 26,
                    decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.location_on, color: Colors.red.shade400, size: 14),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            stateData.pickupAddress,
                            style: regularBlack(context).copyWith(fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                          child: Text("Pickup", style: TextStyle(color: Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey.withOpacity(0.2), height: 1),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            stateData.dropoffAddress,
                            style: regularBlack(context).copyWith(fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                          child: Text("Drop", style: TextStyle(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRideDetails(BuildContext context) {
    final fare = widget.selectedVehicleData["fare"]?.toString() ?? "0";
    final distance = widget.selectedVehicleData["distance"]?.toString() ?? "";
    final duration = widget.selectedVehicleData["duration"]?.toString() ?? "";
    final vehicleName = widget.selectedVehicleData["vehicleName"]?.toString() ?? "Ride";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        
        // Header: Price Breakdown
        Row(
          children: [
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.receipt_long_rounded, size: 16, color: yelloColor2),
            ),
            const SizedBox(width: 12),
            Text(
              "Price Breakdown".translate(context),
              style: heading3Grey1(context).copyWith(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),

        // Price Breakdown Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F8F6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Trip Fare / Base Fare
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        "$vehicleName Trip Fare".translate(context),
                        style: regular(context).copyWith(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (distance.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          "($distance km)",
                          style: regular(context).copyWith(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    "$currency $fare",
                    style: regular(context).copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Estimated Duration
              if (duration.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Estimated Time".translate(context),
                      style: regular(context).copyWith(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      duration,
                      style: regular(context).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // Taxes and Fees
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Taxes & Fees".translate(context),
                    style: regular(context).copyWith(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    "Included".translate(context),
                    style: regular(context).copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Divider(color: Colors.grey.withValues(alpha: 0.2), height: 1),
              const SizedBox(height: 12),

              // Total Amount Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total Fare".translate(context),
                    style: heading3Grey1(context).copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    "$currency $fare",
                    style: heading2(context).copyWith(
                      color: themeColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        if (rideStatus != "ongoing") _buildCancelRideButton(context),
      ],
    );
  }

  Widget _buildVehicleDetails(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCBB2C).withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 55,
            height: 45,
            child: Image.network(
              widget.selectedVehicleData["image"] ?? "",
              headers: const {"ngrok-skip-browser-warning": "true"},
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => SvgPicture.asset("assets/images/car.svg"),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.selectedVehicleData["vehicleName"] ?? "Unknown",
                  style: heading3Grey1(context).copyWith(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, color: yelloColor2, size: 14),
                    const SizedBox(width: 4),
                    Text("1 Rider", style: regular(context).copyWith(fontSize: 11, color: grey1)),
                  ],
                ),
              ],
            ),
          ),
          Container(width: 1, height: 30, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "${widget.selectedVehicleData["duration"] ?? "00"}",
                style: heading3Grey1(context).copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                "ETA",
                style: regular(context).copyWith(fontSize: 11, color: grey1),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 30, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "₹${widget.selectedVehicleData["fare"] ?? ""}",
                style: heading3Grey1(context).copyWith(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                "(${widget.selectedVehicleData["distance"] ?? "00"} Km)",
                style: regular(context).copyWith(fontSize: 11, color: grey1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCancelRideButton(BuildContext context) {
    return Column(
      children: [
        SlideToCancelButton(
          text: "Cancel Ride".translate(context),
          onCancel: () => _showCancelRideBottomSheet(context),
        ),
        const SizedBox(height: 8),
        Text(
          "Swipe right to cancel ride".translate(context),
          style: regular(context).copyWith(fontSize: 11, color: grey1, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_user, color: Colors.green, size: 16),
            const SizedBox(width: 6),
            Text("Your safety is our priority", style: regular(context).copyWith(fontSize: 12, color: grey1)),
          ],
        ),
      ],
    );
  }

  void _showCancelRideBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: notifires.getbgcolor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber, color: themeColor, size: 35),
              const SizedBox(height: 10),
              Text(
                "Are you sure you want to cancel your ride?".translate(context),
                style: heading2Grey1(context),
                textAlign: TextAlign.center,
              ),
              Text(
                "If you cancel now, your current ride request will be aborted."
                    .translate(context),
                style: regular(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () {
                      isManuallyCancelled = true;
                      box.delete("ride_data");
                      if (bookingId.isNotEmpty) {
                        context
                            .read<UpdateRideStatusInDatabaseCubit>()
                            .updateRideStatus(
                              context: context,
                              bookingId: bookingId,
                              rideStatus: "Cancelled",
                            );
                      }

                      cancelRideRequest(
                          rideId:
                              context.read<RideRequestCubit>().state.rideId);

                      if (widget.statusOfRide.isEmpty) {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      } else {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ItemHomeScreen()),
                          (Route<dynamic> route) => false,
                        );
                        stopAutoDistanceTimer();
                      }
                    },
                    child: Container(
                      alignment: Alignment.center,
                      height: 50,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 5),
                      decoration: BoxDecoration(
                        color: themeColor,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Text(
                        "Cancel Ride".translate(context),
                        style: regular2(context).copyWith(
                            color: blackColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 25),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      alignment: Alignment.center,
                      height: 50,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 5),
                      decoration: BoxDecoration(
                        color: notifires.getBoxColor,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Text(
                        "Keep Ride".translate(context),
                        style: regular2(context).copyWith(
                            color: grey1, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void showDriverCancelledRideDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Colors.white,
        title: Column(
          children: [
            const Icon(
              Icons.car_crash,
              color: Colors.redAccent,
              size: 50,
            ),
            const SizedBox(height: 10),
            Text(
              "Driver Cancelled Ride".translate(context),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: Text(
          "The driver has unexpectedly cancelled the ride.\n\nWe're sorry for the inconvenience.\nYou can go back to the home screen and request another ride."
              .translate(context),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          InkWell(
            onTap: () {
              goBack();
              context.read<RideRequestCubit>().resetState();
              context.read<GetRideRequestStatusCubit>().resetState();
              box.delete("ride_data");
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const ItemHomeScreen(),
                ),
                (Route<dynamic> route) => false, // Remove all previous routes
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.home, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    "Go Home".translate(context),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CountdownSegmentedBar extends StatefulWidget {
  const CountdownSegmentedBar({super.key});

  @override
  State<CountdownSegmentedBar> createState() => _CountdownSegmentedBarState();
}

class _CountdownSegmentedBarState extends State<CountdownSegmentedBar>
    with WidgetsBindingObserver {
  int totalSeconds = 60;
  int segmentCount = 6;
  Timer? _timer;
  DateTime? _startTime;

  double get _elapsedSecondsPrecise {
    if (_startTime == null) return 0.0;
    final ms = DateTime.now().difference(_startTime!).inMilliseconds;
    return (ms / 1000.0).clamp(0.0, totalSeconds.toDouble());
  }

  int get remainingSeconds =>
      (totalSeconds - _elapsedSecondsPrecise.floor()).clamp(0, totalSeconds);

  double get totalRemainingProgress =>
      (1.0 - _elapsedSecondsPrecise / totalSeconds).clamp(0.0, 1.0);

  double getSegmentProgress(int index) {
    final double segmentStart = index / segmentCount;
    final double segmentEnd = (index + 1) / segmentCount;
    final p = totalRemainingProgress;
    if (p <= segmentStart) return 0.0;
    if (p >= segmentEnd) return 1.0;
    return (p - segmentStart) / (segmentEnd - segmentStart);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final durationFromCubit =
        context.read<DriverSearchIntervalCubit>().state.value;
    totalSeconds = int.tryParse(durationFromCubit ?? "60") ?? 60;
    segmentCount = 6;
    _startCountdown();
  }

  void _startCountdown() {
    _startTime = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      final elapsed = _elapsedSecondsPrecise;

      if (elapsed >= totalSeconds) {
        _timer?.cancel();
        setState(() {});
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) showBottomSheetMessage();
        });
      } else {
        setState(() {});
      }
    });
  }

  void _resetCountdown() {
    _timer?.cancel();
    setState(() {
      _startTime = DateTime.now();
    });
    _startCountdown();
  }

  void _stopCountdown() {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCountdown();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  void showBottomSheetMessage() {
    showModalBottomSheet(
      context: context,
      backgroundColor: notifires.getbgcolor,
      builder: (context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.maxFinite,
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                "Driver has not accepted your ride.".translate(context),
                textAlign: TextAlign.center,
                style: heading2Grey1(context),
              ),
              const SizedBox(height: 8),
              Text(
                "Try again or choose a different ride. Don't worry, we're here to help!"
                    .translate(context),
                textAlign: TextAlign.center,
                style: heading3Grey1(context),
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: () {
                  box.delete("ride_data");
                  Navigator.pop(context);
                  _resetCountdown(); // Restart timer
                  final state =
                      context.read<BookRideRealTimeDataBaseCubit>().state;

                  context.read<DriverNearByCubit>().getNearbyDrivers(
                        checkRestart: true,
                        distance: 15,
                        pickupLat: double.parse(state.pickupAddressLatitude),
                        pickupLng: double.parse(state.pickupAddressLongitude),
                        vehicleTypeId: context
                            .read<VehicleDataUpdateCubit>()
                            .state
                            .vehicleSelectedId
                            .toString(),
                      );
                  isManuallyCancelled = false;
                },
                child: Container(
                  height: 40,
                  width: 120,
                  alignment: Alignment.center,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  decoration: BoxDecoration(
                    color: notifires.getBoxColor,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Text(
                    "Retry".translate(context),
                    style: TextStyle(color: grey1, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showNoDriverFoundBottomSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      builder: (context) => PopScope(
        canPop: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_off_rounded,
                    size: 55,
                    color: Colors.yellow.shade800,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "No nearby drivers found".translate(context),
                  textAlign: TextAlign.center,
                  style: heading2Grey1(context).copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "We couldn’t find any drivers around your pickup location. Please try again after a moment."
                      .translate(context),
                  textAlign: TextAlign.center,
                  style: heading3Grey1(context).copyWith(
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 26),
                CustomsButtons(
                    text: "Try again",
                    backgroundColor: themeColor,
                    onPressed: () {
                      Navigator.pop(context);
                      _resetCountdown();

                      final state =
                          context.read<BookRideRealTimeDataBaseCubit>().state;

                      context.read<DriverNearByCubit>().getNearbyDrivers(
                            checkRestart: false,
                            distance: 15,
                            pickupLat:
                                double.parse(state.pickupAddressLatitude),
                            pickupLng:
                                double.parse(state.pickupAddressLongitude),
                            vehicleTypeId: context
                                .read<VehicleDataUpdateCubit>()
                                .state
                                .vehicleSelectedId
                                .toString(),
                          );
                      setState(() {});
                    }),
                const SizedBox(height: 14),
                CustomsButtons(
                    text: "Cancel Ride",
                    backgroundColor: redColor2,
                    textColor: whiteColor,
                    onPressed: () {
                      Navigator.pop(context);
                      isManuallyCancelled = true;
                      goBack();
                    }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DriverNearByCubit, DriverNearByState>(
      listener: (context, state) {
        if (state is DriverUpdated) {
          if (state.nearbyDrivers!.isEmpty) {
            _stopCountdown();
            context.read<UserMarkerCubit>().removeNearbyMarkers();
            showNoDriverFoundBottomSheet();

            context.read<DriverNearByCubit>().resetNearByDriverState();
            return;
          }
        }
      },
      child: Column(
        children: [
          Row(
            children: List.generate(segmentCount, (index) {
              final targetProgress = getSegmentProgress(index);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: index != segmentCount - 1 ? 6.0 : 0.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 7,
                      color: Colors.grey[200],
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 1.0, end: targetProgress),
                        duration: const Duration(milliseconds: 100),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: value.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFCBB2C),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time, color: const Color(0xFFFCBB2C), size: 16),
              const SizedBox(width: 6),
              Text(
                "${(remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(remainingSeconds % 60).toString().padLeft(2, '0')} ${"min".translate(context)}",
                style: regular(context).copyWith(
                    color: Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                "Searching nearby drivers...".translate(context),
                style: regular(context).copyWith(color: grey1, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PulsingCircle extends StatefulWidget {
  const PulsingCircle({super.key});

  @override
  State<PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<PulsingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000), // Slower, majestic feel
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The radar waves
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: RadarPainter(_controller.value),
                size: const Size(320, 320),
              );
            },
          ),
          // Inner breathing, glowing dot
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Breathe: uses sin wave for smooth in-out pulse
              final breath = math.sin(_controller.value * math.pi * 4); 
              final scale = 1.0 + (breath * 0.05); // Toned down: 1.0 to 1.05
              
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.shade500,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.4),
                        blurRadius: 4 + (breath * 2),
                        spreadRadius: 1 + (breath * 1),
                      ),
                      const BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        spreadRadius: 1,
                      )
                    ]
                  ),
                ),
              );
            }
          ),
        ],
      ),
    );
  }
}

class RadarPainter extends CustomPainter {
  final double animationValue;

  RadarPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // 1. Draw expanding rings
    for (int i = 0; i < 3; i++) {
      double progress = animationValue - (i * 0.33);
      if (progress < 0) {
        progress += 1.0;
      }
      
      // Use easeOut curve for expanding radius so it slows down near the edge
      final double curveProgress = Curves.easeOut.transform(progress);
      final double radius = maxRadius * curveProgress;
      
      // Fade out heavily towards the end
      final double opacity = (1.0 - progress).clamp(0.0, 1.0);

      // Radial gradient for the shockwave fill
      final ringPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.green.withValues(alpha: 0.0),
            Colors.green.withValues(alpha: opacity * 0.1),
            Colors.green.withValues(alpha: opacity * 0.4),
          ],
          stops: const [0.0, 0.8, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius > 0 ? radius : 1))
        ..style = PaintingStyle.fill;

      if (radius > 0) {
         canvas.drawCircle(center, radius, ringPaint);
      }

      // Crisp outer ring border
      final borderPaint = Paint()
        ..color = Colors.green.withValues(alpha: opacity * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
        
      if (radius > 0) {
        canvas.drawCircle(center, radius, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class PersistentGoogleMap extends StatefulWidget {
  final LatLng initialPosition;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final bool myLocationEnabled;
  final Function(GoogleMapController) onMapCreated;

  const PersistentGoogleMap({
    super.key,
    required this.initialPosition,
    required this.markers,
    required this.polylines,
    required this.myLocationEnabled,
    required this.onMapCreated,
  });

  @override
  PersistentGoogleMapState createState() => PersistentGoogleMapState();
}

class PersistentGoogleMapState extends State<PersistentGoogleMap> {
  GoogleMapController? _mapController;
  Set<Marker> markers = {};
  Set<Polyline> polyline = {};

  @override
  void initState() {
    super.initState();
    markers = widget.markers;
    polyline = widget.polylines;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GetPolylineCubit, GetPolylineState>(
      builder: (context, polylineState) {
        if (polylineState is GetPolylineUpdated) {
          polyline = polylineState.polylines ?? {};
          if (polyline.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _moveCameraToFitPolylineAndMarkers();
            });
          }
          context.read<GetPolylineCubit>().resetPolylines();
        }

        return BlocBuilder<UserMarkerCubit, UserMarkerState>(
            builder: (context, markerState) {
          if (markerState is UserMarkerUpdated) {
            markers = markerState.markers;
          }
          return GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialPosition,
              zoom: 15,
            ),
            myLocationEnabled: widget.myLocationEnabled,
            markers: markers,
            polylines: polyline,
            onMapCreated: (controller) {
              if (_mapController == null) {
                _mapController = controller;
                widget.onMapCreated(controller);
              }
            },
          );
        });
      },
    );
  }

  void _moveCameraToFitPolylineAndMarkers() {
    if (_mapController == null || polyline.isEmpty) return;

    LatLngBounds bounds;
    final points = polyline.expand((p) => p.points).toList();

    if (points.isEmpty) return;

    final southwestLat =
        points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final southwestLng =
        points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final northeastLat =
        points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final northeastLng =
        points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

    bounds = LatLngBounds(
      southwest: LatLng(southwestLat, southwestLng),
      northeast: LatLng(northeastLat, northeastLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 150), // 150 = padding
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class ScreenTracker {
  static String? currentScreen;

  static void setCurrentScreen(String screenName) {
    currentScreen = screenName;
  }

  static bool isScreenActive(String screenName) {
    return currentScreen == screenName;
  }
}

class SlideToCancelButton extends StatefulWidget {
  final VoidCallback onCancel;
  final String text;

  const SlideToCancelButton({super.key, required this.onCancel, required this.text});

  @override
  State<SlideToCancelButton> createState() => _SlideToCancelButtonState();
}

class _SlideToCancelButtonState extends State<SlideToCancelButton> {
  double _dragPosition = 0;
  bool _isCancelled = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag = constraints.maxWidth - 55;

        return Container(
          width: double.infinity,
          height: 55,
          decoration: BoxDecoration(
            color: const Color(0xFFFCBB2C),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  widget.text,
                  style: const TextStyle(fontSize: 15, color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Icon(Icons.arrow_forward, color: Colors.black.withOpacity(0.3), size: 20),
                ),
              ),
              Positioned(
                left: _dragPosition,
                top: 5.5,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_isCancelled) return;
                    setState(() {
                      _dragPosition += details.delta.dx;
                      if (_dragPosition < 0) _dragPosition = 0;
                      if (_dragPosition > maxDrag) _dragPosition = maxDrag;
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_isCancelled) return;
                    if (_dragPosition > maxDrag * 0.8) {
                      setState(() {
                        _dragPosition = maxDrag;
                        _isCancelled = true;
                      });
                      widget.onCancel();
                    } else {
                      setState(() {
                        _dragPosition = 0;
                      });
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(left: 5.5),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.close, color: Colors.black, size: 20),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
