import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:ride_on/core/utils/translate.dart';
import '../../../core/services/data_store.dart';
import '../../../core/utils/common_widget.dart';
import '../../../core/utils/theme/project_color.dart';
import '../../../core/utils/theme/theme_style.dart';
import '../../cubits/book_ride_cubit.dart';
import '../../cubits/location/user_current_location_cubit.dart';
import 'loading_nearby_search_screen.dart';
import 'search_map_screen.dart';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class UserSearchLocation extends StatefulWidget {
  final String? currentAddress;
  const UserSearchLocation({super.key, this.currentAddress});

  @override
  State<UserSearchLocation> createState() => _UserSearchLocationState();
}

class _UserSearchLocationState extends State<UserSearchLocation> {
  final focusNode1 = FocusNode();
  final focusNode2 = FocusNode();
  bool isPickUp = true;
  Timer? _debounce;
  bool showButton = true;
  List<Map<String, String>> recentDropLocations = [];

  @override
  void dispose() {
    _debounce?.cancel();
    focusNode1.dispose();
    focusNode2.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final cubit = context.read<SelectedAddressCubit>();
    cubit.pickupAddressController.text = widget.currentAddress ?? "";
    cubit.dropOffAddressController.text = "";
    _loadRecentDropLocations();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GetSuggestionAddressCubit>().getSuggestions("");
    });
  }

  @override
  Widget build(BuildContext context) {
    notifires = Provider.of<ColorNotifires>(context, listen: true);
    final isDark = notifires.isDark;
    return Scaffold(
      backgroundColor: isDark ? darkmode : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: MultiBlocListener(
          listeners: [
            BlocListener<GetCordinatesCubit, GetCordinatesState>(
              listener: _handleCoordinateUpdate,
            )
          ],
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildHeaderSection(isDark),
                    const SizedBox(height: 20),
                    _buildLocationFields(),
                    const SizedBox(height: 16),
                    _buildSelectFromMapButton(),
                    const SizedBox(height: 24),
                    _buildSuggestionsOrRecentList(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildLocationFields() {
    final cubit = context.read<SelectedAddressCubit>();
    final isDark = notifires.isDark;
    bool dropTextFilled = cubit.dropOffAddressController.text.isNotEmpty;

    return BlocBuilder<SelectedAddressCubit, SelectedAddressState>(
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2226) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 18),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 46,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          4,
                          (index) => Container(
                            width: 2,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF282F37)
                            : const Color(0xFFF2FBF7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isPickUp
                              ? const Color(0xFF10B981)
                              : const Color(0xFFA7F3D0),
                          width: 1,
                        ),
                      ),
                      child: TextFormField(
                        controller: cubit.pickupAddressController,
                        focusNode: focusNode1,
                        style: heading3Grey1(context).copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          setState(() => isPickUp = true);
                          cubit.updateIsSelectePickupdAddress(
                              isCheckedSelectedPickup: true);
                          cubit.updateIsSelectedDropOffAddress(
                              isCheckedSelectedDropOff: false);
                          context
                              .read<GetSuggestionAddressCubit>()
                              .removeAddress();
                        },
                        onChanged: (query) {
                          setState(() {});
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          _debounce =
                              Timer(const Duration(milliseconds: 800), () {
                            if (query.length >= 2) {
                              context
                                  .read<GetSuggestionAddressCubit>()
                                  .getSuggestions(query);
                            }
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "Enter pickup location".translate(context),
                          hintStyle: regular2(context).copyWith(
                            fontSize: 13.5,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade400,
                          ),
                          prefixIcon: const Icon(
                            Icons.near_me_outlined,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 8),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: getCurrentLocationAndAddress,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.gps_fixed_rounded,
                                    color: Color(0xFF10B981),
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF16191D)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: !isPickUp
                              ? const Color(0xFFEF4444)
                              : (isDark ? Colors.white12 : Colors.grey.shade200),
                          width: 1,
                        ),
                      ),
                      child: TextFormField(
                        controller: cubit.dropOffAddressController,
                        focusNode: focusNode2,
                        style: heading3Grey1(context).copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          setState(() => isPickUp = false);
                          cubit.updateIsSelectePickupdAddress(
                              isCheckedSelectedPickup: false);
                          cubit.updateIsSelectedDropOffAddress(
                              isCheckedSelectedDropOff: true);
                          context
                              .read<GetSuggestionAddressCubit>()
                              .removeAddress();
                        },
                        onChanged: (query) {
                          setState(() {});
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          _debounce =
                              Timer(const Duration(milliseconds: 800), () {
                            if (query.length >= 2) {
                              context
                                  .read<GetSuggestionAddressCubit>()
                                  .getSuggestions(query);
                              dropTextFilled = cubit
                                  .dropOffAddressController.text.isNotEmpty;
                            }
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "Enter drop location".translate(context),
                          hintStyle: regular2(context).copyWith(
                            fontSize: 13.5,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade400,
                          ),
                          prefixIcon: const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 8),
                          suffixIcon: dropTextFilled
                              ? IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.grey.shade300,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  onPressed: () {
                                    cubit.dropOffAddressController.clear();
                                    setState(() {});
                                    context
                                        .read<GetSuggestionAddressCubit>()
                                        .removeAddress();
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectFromMapButton() {
    return PopupMenuButton<int>(
      color: notifires.isDark ? const Color(0xFF1E2226) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      offset: const Offset(0, 56),
      onSelected: (value) {
        FocusScope.of(context).unfocus();
        final checkStatus = (value == 1);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchMapScreen(checkStatus: checkStatus),
          ),
        );
      },
      itemBuilder: (context) => [
        PopupMenuItem<int>(
          value: 1,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Select Pickup Location".translate(context),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: notifires.isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<int>(
          value: 2,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.flag_rounded, color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Select Drop-off Location".translate(context),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: notifires.isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.map_outlined, color: Colors.black87, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Select From Map".translate(context),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.black87,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsOrRecentList() {
    return BlocBuilder<GetSuggestionAddressCubit, GetSuggestionAddressState>(
      builder: (context, state) {
        final suggestions = (state is GetSuggestionAddressSuccess)
            ? state.suggestions ?? []
            : [];

        if (suggestions.isNotEmpty) {
          return _buildSuggestionsList(suggestions);
        }

        return _buildRecentDropSearches();
      },
    );
  }

  Widget _buildRecentDropSearches() {
    final isDark = notifires.isDark;
    final cubit = context.read<SelectedAddressCubit>();

    if (cubit.dropOffAddressController.text.isNotEmpty && showButton) {
      return Container(
        margin: const EdgeInsets.only(top: 16, bottom: 24),
        child: CustomsButtons(
          text: "Find nearby drivers".translate(context),
          textColor: blackColor,
          backgroundColor: themeColor,
          onPressed: _proceedToNearbyDrivers,
        ),
      );
    }

    if (recentDropLocations.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.history,
                  size: 20,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                Text(
                  "Recent Drop Searches".translate(context),
                  style: heading3Grey1(context).copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                box.delete('recent_drop_locations');
                setState(() {
                  recentDropLocations.clear();
                });
              },
              child: Text(
                "Clear All".translate(context),
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentDropLocations.length,
          itemBuilder: (context, index) {
            final item = recentDropLocations[index];
            final fullAddr = item['address'] ?? "";
            final parts = fullAddr.split(',');
            final mainTitle = parts.first.trim();
            final subTitle = parts.length > 1
                ? parts.sublist(1).join(',').trim()
                : "";

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2226) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    showButton = false;
                    context
                        .read<SelectedAddressCubit>()
                        .dropOffAddressController
                        .text = item['address'] ?? "";
                    context
                        .read<BookRideRealTimeDataBaseCubit>()
                        .updateDropOffLatAndLng(
                          dropoffAddressLatitude: item['lat'] ?? "",
                          dropoffAddressLongitude: item['lng'] ?? "",
                        );

                    final selected = context.read<SelectedAddressCubit>();
                    final bookRide =
                        context.read<BookRideRealTimeDataBaseCubit>();

                    if (selected.pickupAddressController.text.isEmpty ||
                        selected.dropOffAddressController.text.isEmpty) {
                      showErrorToastMessage(
                          "Please select both addresses".translate(context));
                      return;
                    }

                    bookRide.updatePickupAddress(
                      pickupAddress: selected.pickupAddressController.text,
                    );
                    bookRide.updateDropOffAddress(
                      dropoffAddress: selected.dropOffAddressController.text,
                    );

                    if (bookRide.state.pickupAddress.isNotEmpty &&
                        bookRide.state.dropoffAddress.isNotEmpty &&
                        bookRide.state.pickupAddressLatitude.isNotEmpty &&
                        bookRide.state.pickupAddressLongitude.isNotEmpty &&
                        bookRide.state.dropoffAddressLatitude.isNotEmpty &&
                        bookRide.state.dropoffAddressLongitude.isNotEmpty) {
                      goTo(const LoadingNearbySearchScreen());
                      showButton = true;
                    }

                    setState(() {});
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF7ED),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: Color(0xFFF59E0B),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mainTitle,
                                style: heading3Grey1(context).copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (subTitle.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  subTitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.3,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_outward_rounded,
                          size: 20,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSuggestionsList(List<dynamic> suggestions) {
    final isDark = notifires.isDark;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: suggestions.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 68,
        endIndent: 16,
        color: isDark ? Colors.white12 : Colors.grey.shade200,
      ),
      itemBuilder: (_, index) {
        final address = suggestions[index];
        final parts = address.split(',');
        final mainTitle = parts.first.trim();
        final subTitle =
            parts.length > 1 ? parts.sublist(1).join(',').trim() : '';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              showButton = false;
              final selectedCubit = context.read<SelectedAddressCubit>();
              final isPickup =
                  selectedCubit.state.isCheckedSelectedPickup;

              if (isPickup) {
                selectedCubit.pickupAddressController.text = address;
              } else {
                selectedCubit.dropOffAddressController.text = address;
              }

              context.read<GetSuggestionAddressCubit>().removeAddress();
              context
                  .read<GetCordinatesCubit>()
                  .getCoordinates(address: address);

              setState(() {});
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF7ED),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFFF59E0B),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mainTitle,
                          style: heading3Grey1(context).copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subTitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subTitle,
                            style: regular(context).copyWith(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : grey2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 18,
                    color: isDark
                        ? Colors.grey.shade500
                        : Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleCoordinateUpdate(BuildContext context, GetCordinatesState state) {
    final addressCubit = context.read<SelectedAddressCubit>();
    final bookRideCubit = context.read<BookRideRealTimeDataBaseCubit>();

    if (state is GetCordinatesSuccess) {
      final isPickup = addressCubit.state.isCheckedSelectedPickup;

      if (isPickup) {
        bookRideCubit.updatePickupLatAndLng(
          pickupAddressLatitude: state.lattiude.toString(),
          pickupAddressLongitude: state.longitude.toString(),
        );
        focusNode1.unfocus();
      } else {
        bookRideCubit.updateDropOffLatAndLng(
          dropoffAddressLatitude: state.lattiude.toString(),
          dropoffAddressLongitude: state.longitude.toString(),
        );
        focusNode2.unfocus();
        _proceedToNearbyDrivers();
      }

      context.read<GetSuggestionAddressCubit>().removeAddress();
    }
  }

  Future<void> getCurrentLocationAndAddress() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();

        if (permission != LocationPermission.always &&
            permission != LocationPermission.whileInUse) {
          await Geolocator.openAppSettings();
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
          // ignore: deprecated_member_use
          desiredAccuracy: LocationAccuracy.high);
      final lat = position.latitude;
      final lng = position.longitude;

      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      Placemark place = placemarks.first;

      String fullAddress = [
        if (place.subThoroughfare != null &&
            place.subThoroughfare!.trim().isNotEmpty)
          place.subThoroughfare,
        if (place.thoroughfare != null && place.thoroughfare!.trim().isNotEmpty)
          place.thoroughfare,
        if (place.subLocality != null && place.subLocality!.trim().isNotEmpty)
          place.subLocality,
        if (place.locality != null && place.locality!.trim().isNotEmpty)
          place.locality,
        if (place.subAdministrativeArea != null &&
            place.subAdministrativeArea!.trim().isNotEmpty)
          place.subAdministrativeArea,
        if (place.administrativeArea != null &&
            place.administrativeArea!.trim().isNotEmpty)
          place.administrativeArea,
        if (place.postalCode != null && place.postalCode!.trim().isNotEmpty)
          place.postalCode,
        if (place.country != null && place.country!.trim().isNotEmpty)
          place.country,
      ].join(", ");

      // ignore: use_build_context_synchronously
      final selectedCubit = context.read<SelectedAddressCubit>();
      // ignore: use_build_context_synchronously
      final bookRide = context.read<BookRideRealTimeDataBaseCubit>();

      selectedCubit.pickupAddressController.text = fullAddress;
      bookRide.updatePickupLatAndLng(
        pickupAddressLatitude: lat.toString(),
        pickupAddressLongitude: lng.toString(),
      );
      bookRide.updatePickupAddress(pickupAddress: fullAddress);

      setState(() {});
    } catch (e) {
      // showErrorToastMessage("Unable to fetch location: $e");
    }
  }

  void _loadRecentDropLocations() {
    final storedList = box.get('recent_drop_locations', defaultValue: []);
    if (storedList is List) {
      recentDropLocations =
          storedList.map((e) => Map<String, String>.from(e)).toList();
    }
    setState(() {});
  }

  void _addRecentDropLocation(String address, String lat, String lng) {
    recentDropLocations.removeWhere((item) => item['address'] == address);
    recentDropLocations.insert(0, {
      "address": address,
      "lat": lat,
      "lng": lng,
    });

    if (recentDropLocations.length > 3) {
      recentDropLocations = recentDropLocations.sublist(0, 3);
    }

    box.put('recent_drop_locations', recentDropLocations);
  }

  void _proceedToNearbyDrivers() {
    final selected = context.read<SelectedAddressCubit>();
    final bookRide = context.read<BookRideRealTimeDataBaseCubit>();

    if (selected.pickupAddressController.text.isEmpty ||
        selected.dropOffAddressController.text.isEmpty) {
      showErrorToastMessage("Please select both addresses".translate(context));
      return;
    }

    bookRide.updatePickupAddress(
      pickupAddress: selected.pickupAddressController.text,
    );
    bookRide.updateDropOffAddress(
      dropoffAddress: selected.dropOffAddressController.text,
    );

    if (bookRide.state.pickupAddress.isNotEmpty &&
        bookRide.state.dropoffAddress.isNotEmpty &&
        bookRide.state.pickupAddressLatitude.isNotEmpty &&
        bookRide.state.pickupAddressLongitude.isNotEmpty &&
        bookRide.state.dropoffAddressLatitude.isNotEmpty &&
        bookRide.state.dropoffAddressLongitude.isNotEmpty) {
      _addRecentDropLocation(
        selected.dropOffAddressController.text,
        bookRide.state.dropoffAddressLatitude.toString(),
        bookRide.state.dropoffAddressLongitude.toString(),
      );
      showButton = true;
      goTo(const LoadingNearbySearchScreen());
      setState(() {});
    }
  }

  Widget _buildHeaderSection(bool isDark) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: -10,
          top: 0,
          child: HeaderArtworkWidget(isDark: isDark),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2226) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "${"Where are you".translate(context)} ",
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    TextSpan(
                      text: "going?".translate(context),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Enter your drop location to\ncontinue your ride.".translate(context),
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class HeaderArtworkWidget extends StatelessWidget {
  final bool isDark;
  const HeaderArtworkWidget({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          CustomPaint(
            size: const Size(140, 140),
            painter: HeaderIllustrationPainter(isDark: isDark),
          ),
          Positioned(
            right: 16,
            top: 10,
            child: CustomPaint(
              size: const Size(38, 52),
              painter: LocationPinPainter(
                pinColor: isDark
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.85)
                    : const Color(0xFFF59E0B),
                centerColor: isDark ? darkmode : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LocationPinPainter extends CustomPainter {
  final Color pinColor;
  final Color centerColor;

  LocationPinPainter({
    required this.pinColor,
    required this.centerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final radius = width / 2;

    final pinPaint = Paint()
      ..color = pinColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path();
    path.moveTo(radius, height);
    path.cubicTo(
      width * 0.08,
      height * 0.55,
      0,
      height * 0.42,
      0,
      radius,
    );
    path.arcTo(
      Rect.fromLTWH(0, 0, width, width),
      3.14159,
      3.14159,
      false,
    );
    path.cubicTo(
      width,
      height * 0.42,
      width * 0.92,
      height * 0.55,
      radius,
      height,
    );
    path.close();

    canvas.drawPath(path, pinPaint);

    final centerPaint = Paint()
      ..color = centerColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(Offset(radius, radius), radius * 0.38, centerPaint);
  }

  @override
  bool shouldRepaint(covariant LocationPinPainter oldDelegate) =>
      oldDelegate.pinColor != pinColor || oldDelegate.centerColor != centerColor;
}

class HeaderIllustrationPainter extends CustomPainter {
  final bool isDark;
  HeaderIllustrationPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (isDark) return;

    final buildingPaint = Paint()
      ..color = const Color(0xFFFFFBEB)
      ..style = PaintingStyle.fill;

    final windowPaint = Paint()
      ..color = const Color(0xFFFEF3C7)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.25, size.height * 0.20, 22, 65),
        const Radius.circular(4),
      ),
      buildingPaint,
    );
    for (int y = 0; y < 4; y++) {
      canvas.drawRect(
        Rect.fromLTWH(size.width * 0.25 + 4, size.height * 0.23 + (y * 12), 4, 5),
        windowPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(size.width * 0.25 + 13, size.height * 0.23 + (y * 12), 4, 5),
        windowPaint,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.48, size.height * 0.08, 30, 90),
        const Radius.circular(5),
      ),
      buildingPaint,
    );
    for (int y = 0; y < 6; y++) {
      canvas.drawRect(
        Rect.fromLTWH(size.width * 0.48 + 5, size.height * 0.12 + (y * 13), 5, 6),
        windowPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(size.width * 0.48 + 18, size.height * 0.12 + (y * 13), 5, 6),
        windowPaint,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.78, size.height * 0.28, 22, 60),
        const Radius.circular(4),
      ),
      buildingPaint,
    );

    final roadPaint = Paint()
      ..color = const Color(0xFFFEF3C7).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final roadPath = Path();
    roadPath.moveTo(0, size.height * 0.98);
    roadPath.cubicTo(
      size.width * 0.35, size.height * 0.98,
      size.width * 0.45, size.height * 0.72,
      size.width * 0.75, size.height * 0.68,
    );
    roadPath.lineTo(size.width * 0.82, size.height * 0.70);
    roadPath.cubicTo(
      size.width * 0.50, size.height * 0.75,
      size.width * 0.40, size.height * 0.99,
      size.width * 0.05, size.height * 0.99,
    );
    roadPath.close();
    canvas.drawPath(roadPath, roadPath == roadPath ? roadPaint : roadPaint);

    final treePaint = Paint()
      ..color = const Color(0xFFD1FAE5)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.88), 16, treePaint);
    canvas.drawCircle(Offset(size.width * 0.34, size.height * 0.85), 13, treePaint);

    final birdPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final bird1 = Path();
    bird1.moveTo(size.width * 0.15, size.height * 0.20);
    bird1.quadraticBezierTo(size.width * 0.19, size.height * 0.14, size.width * 0.23, size.height * 0.19);
    bird1.quadraticBezierTo(size.width * 0.27, size.height * 0.14, size.width * 0.31, size.height * 0.20);
    canvas.drawPath(bird1, birdPaint);
  }

  @override
  bool shouldRepaint(covariant HeaderIllustrationPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
