import 'package:ride_on/app/route_settings.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:ride_on/core/utils/translate.dart';
import 'package:ride_on/presentation/screens/home/item_home_screen.dart';
import '../../core/utils/common_widget.dart';
import '../../core/utils/theme/project_color.dart';
import '../../core/utils/theme/theme_style.dart';
import '../cubits/book_ride_cubit.dart';
import '../cubits/location/get_nearby_drivers_cubit.dart';
import '../cubits/location/set_marker_cubit.dart';
import '../cubits/realtime/get_ride_request_status_cubit.dart';
import '../cubits/realtime/ride_request_cubit.dart';
import '../cubits/review/review_cubit.dart';
import 'custom_text_form_field.dart';

class CustomReviewWidget extends StatefulWidget {
  final String? bookingId;
  const CustomReviewWidget({super.key, this.bookingId});

  @override
  State<CustomReviewWidget> createState() => _CustomReviewWidgetState();
}

class _CustomReviewWidgetState extends State<CustomReviewWidget> {
  String totalTime = "";
  String driverName = "";
  String driverPhone = "";
  String vehicleInfo = "";

  @override
  void initState() {
    super.initState();
    fetchTotalTime(); // Call async method from initState
    fetchDriverDetails(); // Fetch driver name, phone, and vehicle info
  }

  Future<void> fetchDriverDetails() async {
    final rideId = context.read<RideRequestCubit>().state.rideId;
    final details = await getDriverDetailsFromRideRequest(rideId);

    if (details != null) {
      setState(() {
        driverName = details['driverName'] ?? "";
        driverPhone = details['driverPhone'] ?? "";
        vehicleInfo = details['vehicleInfo'] ?? "";
      });
    }
  }

  Future<Map<String, String>?> getDriverDetailsFromRideRequest(String rideId) async {
    try {
      final DatabaseReference rideRequestRef =
          FirebaseDatabase.instance.ref('ride_requests/$rideId');
      final DataSnapshot snapshot = await rideRequestRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        // Extract driver details from Firebase
        final driver = data['driver'] as Map<dynamic, dynamic>?;
        final vehicleDetails = data['vehicleDetails'] as Map<dynamic, dynamic>?;

        String name = "";
        String phone = "";
        String vehicle = "";

        if (driver != null) {
          name = driver['driverName']?.toString() ?? "";
          phone = driver['driverPhone']?.toString() ?? "";
        }

        if (vehicleDetails != null) {
          final make = vehicleDetails['vehicleMake']?.toString() ?? "";
          final model = vehicleDetails['vehicleModel']?.toString() ?? "";
          final number = vehicleDetails['vehicleNumber']?.toString() ?? "";

          if (make.isNotEmpty && model.isNotEmpty) {
            vehicle = "$make $model";
          } else if (number.isNotEmpty) {
            vehicle = number;
          }
        }

        // If Firebase data is empty, fallback to state data
        if (name.isEmpty) {
          try {
            final stateDriverName = context.read<RideRequestCubit>().state.acceptedDriverName.trim();
            if (stateDriverName.isNotEmpty) {
              name = stateDriverName;
            }
          } catch (_) {}
        }

        if (phone.isEmpty) {
          try {
            final statePhone = context.read<RideRequestCubit>().state.accepteDriverPhoneNumber.trim();
            if (statePhone.isNotEmpty) {
              phone = statePhone;
            }
          } catch (_) {}
        }

        if (vehicle.isEmpty) {
          try {
            final stateVehicle = context.read<RideRequestCubit>().state.acceptedDriverVechileName.isNotEmpty
                ? context.read<RideRequestCubit>().state.acceptedDriverVechileName
                : context.read<RideRequestCubit>().state.acceptedDriverVechileNumber;
            if (stateVehicle.isNotEmpty) {
              vehicle = stateVehicle;
            }
          } catch (_) {}
        }

        return {
          'driverName': name,
          'driverPhone': phone,
          'vehicleInfo': vehicle,
        };
      } else {
        return null;
      }
    } catch (error) {
      return null;
    }
  }

  Future<void> fetchTotalTime() async {
    final rideId = context.read<RideRequestCubit>().state.rideId;
    final time = await getTotalTimeFromRideRequest(rideId);

    if (time != null) {
      setState(() {
        totalTime = time;
      });

    }
  }

  Future<String?> getTotalTimeFromRideRequest(String rideId) async {
    try {
      final DatabaseReference rideRequestRef =
          FirebaseDatabase.instance.ref('ride_requests/$rideId');
      final DataSnapshot snapshot = await rideRequestRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        if (data.containsKey('totalTime')) {
          final totalTime = data['totalTime']?.toString();

          return totalTime;
        } else {

          return null;
        }
      } else {

        return null;
      }
    } catch (error) {

      return null;
    }
  }

  TextEditingController textEditingReviewController = TextEditingController();
  String ratingData = "";
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.75,
        maxChildSize: 0.75,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: ListView(
              controller: scrollController,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(),
                    Center(
                      child: Container(
                        width: 70,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(),
                  ],
                ),
                const SizedBox(height: 40),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () {

                        goBack();
                        setState(() {
                          clearAllRiderData(context);
                          goToWithClear(const ItemHomeScreen());

                        });
                      },
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              border: Border.all(width: 1, color: blackColor),
                              borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.center,
                          child:   Text("Skip".translate(context))),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BlocBuilder<RideRequestCubit, RideRequestState>(
                        builder: (context, state) {
                      return SizedBox(
                        height: 60,
                        width: 60,
                        child: state.acceptedDriverImageUrl.isNotEmpty
                            ? ClipOval(
                                child: myNetworkImage(
                                  state.acceptedDriverImageUrl,
                                ),
                              )
                            : Align(
                                alignment: Alignment.center,
                                child: Image.asset(
                                  "assets/images/drower_person.png",
                                  height: 100,
                                ),
                              ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 5),
                Column(children: [
                  BlocBuilder<RideRequestCubit, RideRequestState>(
                      builder: (context, state) {
                    // Use fetched driver name first, fallback to state data
                    final name = driverName.isNotEmpty 
                      ? driverName 
                      : state.acceptedDriverName.trim();
                    final phone = driverPhone.isNotEmpty 
                      ? driverPhone 
                      : state.accepteDriverPhoneNumber.trim();
                    
                    // Build dynamic driver display text with 3-tier fallback
                    String displayName = "Driver";
                    if (name.isNotEmpty) {
                      displayName = name;
                    } else if (phone.isNotEmpty) {
                      displayName = "Driver • $phone";
                    } else {
                      displayName = "Your Driver";
                    }
                    
                    return Text(
                        displayName,
                        style: regularBlack(context).copyWith(
                          fontSize: 14,
                        ));
                  }),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time_filled,
                        color: blackColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(totalTime, style: regular(context))
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Show vehicle details - use fetched vehicle info first
                  BlocBuilder<RideRequestCubit, RideRequestState>(
                      builder: (context, state) {
                    final displayVehicleInfo = vehicleInfo.isNotEmpty
                        ? vehicleInfo
                        : state.acceptedDriverVechileName.isNotEmpty
                            ? state.acceptedDriverVechileName
                            : state.acceptedDriverVechileNumber.isNotEmpty
                                ? state.acceptedDriverVechileNumber
                                : '';
                    
                    if (displayVehicleInfo.isNotEmpty) {
                      return Text(
                        displayVehicleInfo,
                        style: regular(context).copyWith(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  const SizedBox(height: 5),
                  Text("How was your trip?".translate(context),
                      style: regular2(context).copyWith(
                        fontSize: 16,
                      )),
                  const SizedBox(height: 5),
                  SizedBox(
                      height: 40,
                      child: RatingBar.builder(
                        initialRating: 0,
                        minRating: 1,
                        direction: Axis.horizontal,
                        allowHalfRating: false,
                        itemCount: 5,
                        itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                        itemBuilder: (context, _) => Icon(
                          Icons.star,
                          color: yelloColor,
                        ),
                        onRatingUpdate: (rating) {
                          final intRating = rating.toInt();

                          ratingData = intRating.toString();setState(() {

                          });

                        },
                      )),
                ]),
                const SizedBox(height: 30),
                TextFieldAdvance(
                    maxlines: 5,
                    backgroundColor: grey6,
                    txt: "Add a comment for the driver ...".translate(context),
                    textEditingControllerCommon: textEditingReviewController,
                    inputType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    inputAlignment: TextAlign.start),
                const SizedBox(height: 30),
                const SizedBox(height: 10),
                BlocConsumer<ReviewCubit, ReviewState>(builder: (context, state) {
                  return CustomsButtons(
                      text: "Submit",
                      backgroundColor: ratingData.isEmpty? grey4:themeColor,
                      textColor: ratingData.isEmpty? grey3:blackColor,
                      onPressed: () {
                        if(ratingData.isEmpty){
                          return;
                        }
                        context.read<ReviewCubit>().resetState();
                        context.read<ReviewCubit>().submitReview(
                            context: context,
                            bookingId: widget.bookingId!,
                            rating: ratingData,
                            message: textEditingReviewController.text);
                      });
                }, listener: (context, state) {
                  if (state is ReviewLoading) {
                    Widgets.showLoader(context);
                  }
                  if (state is ReviewSuceess) {
                    Widgets.hideLoder(context);
                    clearAllRiderData(context);
                    goToWithClear(const ItemHomeScreen());
                  }
                  if (state is ReviewFailure) {
                    Widgets.hideLoder(context);
                  }
                }),
                const SizedBox(
                  height: 300,
                )
              ],
            ),
          );
        },
      ),
    );
  }
}


void clearAllRiderData(BuildContext context){
  context.read<RideRequestCubit>().resetState();
  context.read<GetRideRequestPaymentCubit>().resetStatus();
  context.read<UserMarkerCubit>().clear();
  context.read<GetPolylineCubit>().resetPolylines();

  context.read<BookRideRealTimeDataBaseCubit>().resetState();

  context.read<RideRequestCubit>().removeProgressIndicator();
  context.read<RideRequestCubit>().removeRideMessage();
}