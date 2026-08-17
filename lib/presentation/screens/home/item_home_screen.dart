import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_on/core/services/config.dart';
import 'package:ride_on/core/services/http.dart';
import 'package:ride_on/core/utils/theme/project_color.dart';
import 'package:ride_on/core/utils/translate.dart';
import 'package:ride_on/core/extensions/helper/push_notifications.dart';
import 'package:ride_on/core/utils/common_widget.dart';
import 'package:ride_on/core/utils/theme/theme_style.dart';
import 'package:ride_on/domain/entities/catrgory.dart';
import 'package:ride_on/core/extensions/workspace.dart';
import 'package:ride_on/presentation/screens/search/loading_nearby_search_screen.dart';
import 'package:ride_on/presentation/screens/search/route_location_screen.dart';
import 'package:ride_on/presentation/widgets/drawer_custom.dart';
import '../auth/signup_screen.dart';
import '../../../core/services/data_store.dart';
import '../../cubits/book_ride_cubit.dart';
import '../../cubits/general_cubit.dart';
import '../../cubits/location/user_current_location_cubit.dart';
import '../../cubits/profile/edit_profile_cubit.dart';
import '../../cubits/realtime/update_ride_request_parameter.dart';
import '../../cubits/vehicle_data/get_vehicle_cetgegory_cubit.dart';

class ItemHomeScreen extends StatefulWidget {
  const ItemHomeScreen({super.key});

  @override
  State<ItemHomeScreen> createState() => _ItemHomeScreenState();
}

class _ItemHomeScreenState extends State<ItemHomeScreen>
    with WidgetsBindingObserver {
  bool _isLocationServiceDialogShowing = false;
  final ValueNotifier<LatLng> _selectedLocation =
      ValueNotifier(const LatLng(0, 0));
  Timer? _debounceTimer; // San Francisco
  Timer? _bannerTimer;
  final PageController _promoBannerController = PageController();
  List<Map<String, dynamic>> _promoBanners = [];
  bool showAlert = false;
  GoogleMapController? _homeMapController;
  double _mapCenterLat = 0;
  double _mapCenterLng = 0;
  String _selectedDropAddress = "";
  bool _isFetchingDropAddress = false;
  Timer? _dropAddressDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    getFCMToken();
    _loadRecentDropLocations();
    context.read<MyImageCubit>().updateMyImage(myImage);
    context
        .read<BookRideRealTimeDataBaseCubit>()
        .updateUserImageUrl(userImageUrl: myImage);
    context.read<UpdateRideRequestParameterCubit>().updateFirebaseUserParameter(
        rideId: context.read<BookRideRealTimeDataBaseCubit>().state.rideId,
        userParameter: {"userImageUrl": myImage});
    context.read<NameCubit>().updateName(loginModel?.data?.firstName ?? "");
    context.read<EmailCubit>().updateEmail(loginModel?.data?.email ?? "");

    isNumeric = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
      showNotification(context); // Assuming this is defined elsewhere
      _loadPromoBanners();
    });
  }

  List<Map<String, String>> recentDropLocations = [];
  void _loadRecentDropLocations() {
    final storedList = box.get('recent_drop_locations', defaultValue: []);
    if (storedList is List) {
      recentDropLocations =
          storedList.map((e) => Map<String, String>.from(e)).toList();
    }
    setState(() {});
  }

  String _currentAddress = "";
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isInitialLocationLoaded = false;
  bool _isLoadingLocation = false;
  Future<void> _initializeApp() async {
    context.read<GetVehicleDataCubit>().getAllCategories();
    getCurrency(context); // Assuming this is defined elsewhere
    getUserDataLocallyToHandleTheState(
        context); // Assuming this is defined elsewhere
    await _loadInitialLocation();
  }

  Future<void> _loadPromoBanners() async {
    try {
      final response = await httpPost(
        Config.sliders,
        {},
        context: context,
      );

      final List<dynamic> data = response is Map && response['data'] is List
          ? response['data'] as List<dynamic>
          : const [];

      if (!mounted) return;
      setState(() {
        _promoBanners = data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => (item['image'] ?? '').toString().isNotEmpty)
            .toList();
      });

      _startPromoBannerAutoScroll();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _promoBanners = [];
      });
    }
  }

  void _startPromoBannerAutoScroll() {
    _bannerTimer?.cancel();
    if (_promoBanners.length < 2) return;

    void scheduleNextBanner() {
      if (!mounted || !_promoBannerController.hasClients) return;
      final currentPage = (_promoBannerController.page ?? 0).round();
      final currentBanner =
          _promoBanners[currentPage % _promoBanners.length];

      int seconds = 4;
      final rawDuration = currentBanner['duration'] ??
          currentBanner['time'] ??
          currentBanner['display_time'] ??
          currentBanner['interval'];
      if (rawDuration != null) {
        seconds = int.tryParse(rawDuration.toString()) ?? 4;
      }
      if (seconds < 1) seconds = 4;

      _bannerTimer?.cancel();
      _bannerTimer = Timer(Duration(seconds: seconds), () {
        if (!mounted || !_promoBannerController.hasClients) return;
        final nextPage = (currentPage + 1) % _promoBanners.length;
        _promoBannerController
            .animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        )
            .then((_) {
          if (mounted && _promoBannerController.hasClients) {
            scheduleNextBanner();
          }
        });
      });
    }

    scheduleNextBanner();
  }

  Future<void> _loadInitialLocation() async {
    if (_isInitialLocationLoaded || _isLoadingLocation) return;
    setState(() => _isLoadingLocation = true);

    try {
      final permission = await _checkPermissions();
      if (!mounted) return;

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: notifires.getbgcolor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Location permission required',
              style: heading3(context),
            ),
            content: Text(
              'Please enable location access to continue using the app.',
              style: regular(context),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'.translate(context)),
              ),
              TextButton(
                onPressed: () async {
                  await Geolocator.openAppSettings();
                },
                child: Text('Open Settings'.translate(context)),
              ),
            ],
          ),
        );
        return;
      }

      if (permission == LocationPermission.denied) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;

      updateUserLocation(position);
      _isInitialLocationLoaded = true;
    } catch (_) {
      // Keep existing UX: the app already shows snackbars/toasts via helpers.
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void startLiveLocationTracking() {
    context.read<LocationUserCubit>().startLiveLocationTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _bannerTimer?.cancel();
    _dropAddressDebounce?.cancel();
    _promoBannerController.dispose();
    _selectedLocation.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLocationServiceOnResume();
    }
  }

  Future<void> _checkLocationServiceOnResume() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (serviceEnabled) {
      if (_isLocationServiceDialogShowing && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _isLocationServiceDialogShowing = false;
      }
      if (!_isInitialLocationLoaded && !_isLoadingLocation) {
        _loadInitialLocation();
      }
    }
  }

  Future<LocationPermission> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceDialog();
      return LocationPermission.denied;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  Future<void> _showLocationServiceDialog() async {
    if (_isLocationServiceDialogShowing || !mounted) return;
    _isLocationServiceDialogShowing = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: notifires.getbgcolor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.location_off_rounded,
              color: themeColor,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Enable Location Services'.translate(context),
                style: heading3(context),
              ),
            ),
          ],
        ),
        content: Text(
          'Location services are disabled on your device. Please enable location services to continue using the app.'
              .translate(context),
          style: regular(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Cancel'.translate(context)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
            },
            child: Text(
              'Enable Location'.translate(context),
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    _isLocationServiceDialogShowing = false;
  }

  void updateUserLocation(Position position) {
    final latLng = LatLng(position.latitude, position.longitude);
    _selectedLocation.value = latLng;
    if (_mapCenterLat == 0 && _mapCenterLng == 0) {
      _mapCenterLat = position.latitude;
      _mapCenterLng = position.longitude;
    }
    if (_homeMapController != null) {
      _homeMapController!.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 15),
      );
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      context.read<UpdateCurrentAddressCubit>().getAddressFromLatLng(
            latitude: position.latitude,
            longitude: position.longitude,
          );
    });
  }

  Map<String, String> parseCleanAddress(String fullAddress) {
    if (fullAddress.isEmpty) return {"title": "", "subtitle": ""};
    final List<String> parts = fullAddress
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final plusCodeRegex =
        RegExp(r'^[A-Z0-9]{4,8}\+[A-Z0-9]{2,5}$', caseSensitive: false);
    final filteredParts =
        parts.where((p) => !plusCodeRegex.hasMatch(p)).toList();

    if (filteredParts.isEmpty) {
      return {"title": fullAddress, "subtitle": ""};
    }

    final String title = filteredParts.first;
    final String subtitle =
        filteredParts.length > 1 ? filteredParts.sublist(1).join(', ') : "";

    return {"title": title, "subtitle": subtitle};
  }

  Future<void> _fetchDropAddressFromLatLng(double lat, double lng) async {
    if (lat == 0 || lng == 0) return;
    if (mounted) setState(() => _isFetchingDropAddress = true);
    try {
      final url =
          "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=${Config.googleKey}";
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["status"] == "OK" && (data["results"] as List).isNotEmpty) {
          String address = data["results"][0]["formatted_address"] as String;
          final parsed = parseCleanAddress(address);
          if (parsed["title"]!.isNotEmpty) {
            address = parsed["subtitle"]!.isNotEmpty
                ? "${parsed["title"]}, ${parsed["subtitle"]}"
                : parsed["title"]!;
          }
          if (mounted) {
            setState(() {
              _selectedDropAddress = address;
              _isFetchingDropAddress = false;
            });
          }
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isFetchingDropAddress = false;
      });
    }
  }

  void _saveRecentDropLocation(String address, String lat, String lng) {
    if (address.isEmpty) return;
    final parsed = parseCleanAddress(address);
    final cleanAddress = parsed["title"]!.isNotEmpty
        ? (parsed["subtitle"]!.isNotEmpty
            ? "${parsed["title"]}, ${parsed["subtitle"]}"
            : parsed["title"]!)
        : address;

    final storedList = box.get('recent_drop_locations', defaultValue: []);
    List<Map<String, String>> currentList = [];
    if (storedList is List) {
      currentList = storedList.map((e) => Map<String, String>.from(e)).toList();
    }
    currentList.removeWhere((item) => item['address'] == cleanAddress);
    currentList.insert(0, {
      "address": cleanAddress,
      "lat": lat,
      "lng": lng,
    });
    if (currentList.length > 3) {
      currentList = currentList.sublist(0, 3);
    }
    box.put('recent_drop_locations', currentList);
    _loadRecentDropLocations();
  }

  void _confirmSelectedDropLocation(double lat, double lng, String address) {
    _checkProfileAndProceed(() {
      if (_currentAddress.isEmpty) {
        showAlert = false;
        startLiveLocationTracking();
        setState(() {});
        return;
      }

      _saveRecentDropLocation(address, lat.toString(), lng.toString());

      final selectedAddressCubit = context.read<SelectedAddressCubit>();
      final bookRideCubit = context.read<BookRideRealTimeDataBaseCubit>();

      selectedAddressCubit.updateIsSelectedDropOffAddress(
          isCheckedSelectedDropOff: true);
      selectedAddressCubit.updateIsCrossIconSelectedDropOff(
          ischeckedCrossIconDropOff: true);
      selectedAddressCubit.dropOffAddressController.text = address;

      bookRideCubit.updatePickupAddress(pickupAddress: _currentAddress);
      bookRideCubit.updateDropOffAddress(dropoffAddress: address);
      bookRideCubit.updateDropOffLatAndLng(
        dropoffAddressLatitude: lat.toString(),
        dropoffAddressLongitude: lng.toString(),
      );

      context.read<VehicleDataUpdateCubit>().updateVehicleTypeSelectedId(1);

      if (bookRideCubit.state.pickupAddress.isNotEmpty &&
          bookRideCubit.state.dropoffAddress.isNotEmpty &&
          bookRideCubit.state.pickupAddressLatitude.isNotEmpty &&
          bookRideCubit.state.pickupAddressLongitude.isNotEmpty &&
          bookRideCubit.state.dropoffAddressLatitude.isNotEmpty &&
          bookRideCubit.state.dropoffAddressLongitude.isNotEmpty) {
        goTo(const LoadingNearbySearchScreen());
      } else {
        goTo(UserSearchLocation(currentAddress: _currentAddress));
      }
    });
  }

  void _checkProfileAndProceed(VoidCallback onProceed) {
    String userName =
        (loginModel?.data?.firstName ?? context.read<NameCubit>().state).trim();
    if (userName.isEmpty) {
      final storedData = box.get("UserData");
      if (storedData != null && storedData.toString().isNotEmpty) {
        try {
          final jsonMap = jsonDecode(storedData.toString());
          if (jsonMap is Map &&
              jsonMap['data'] != null &&
              jsonMap['data']['first_name'] != null) {
            userName = jsonMap['data']['first_name'].toString().trim();
          }
        } catch (_) {}
      }
    }
    if (userName.isEmpty || userName.toLowerCase() == "rider") {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF8E7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
                    color: Color(0xFFFFB300),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Complete Your Profile".translate(context),
                  style: heading2Grey1(context).copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Please tell us your name to proceed with booking your ride."
                      .translate(context),
                  textAlign: TextAlign.center,
                  style: regular(context).copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignUp(),
                      ),
                    );
                  },
                  child: Container(
                    height: 52,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          themeColor.withValues(alpha: 0.85),
                          themeColor,
                          const Color(0xFFFFB300),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        "Complete Profile Now".translate(context),
                        style: heading3(context).copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );
    } else {
      onProceed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        dialogExit(context);
      },
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDF5),
        drawer: const MyDrawer(),
        key: _scaffoldKey,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: Fixed decorative background wallpaper
            Positioned.fill(
              child: RepaintBoundary(
                child: Image.asset(
                  "assets/images/home_background_ui.png",
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
            // Layer 2: Independent scrollable foreground content
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 5),
                    _buildLocationInput(),
                    const SizedBox(height: 15),
                    _buildMapWidget(),
                    const SizedBox(height: 20),
                    RepaintBoundary(child: _buildExploreSection()),
                    const SizedBox(height: 20),
                    if (recentDropLocations.isNotEmpty) ...[
                      _buildRecentSearches(),
                      const SizedBox(height: 20),
                    ],
                    if (_promoBanners.isNotEmpty) ...[
                      RepaintBoundary(child: _buildPromoBanner()),
                      const SizedBox(height: 20),
                    ],
                    RepaintBoundary(child: _buildFixedOfferBannerCard()),
                    const SizedBox(height: 20),
                    const SizedBox(
                        height:
                            70), // Bottom padding so content scrolls above fixed footer
                  ],
                ),
              ),
            ),
            // Layer 3: Persistent Footer anchored at bottom of screen
            Positioned(
              left: 16,
              right: 16,
              bottom: 8,
              child: RepaintBoundary(
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Powered by FOXRUN INDIA (OPC) PRIVATE LIMITED",
                            style: regular2(context).copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Proudly made for India \uD83C\uDDEE\uD83C\uDDF3",
                            style: regular2(context).copyWith(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          BlocBuilder<MyImageCubit, dynamic>(builder: (context, state) {
            return InkWell(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: myImage.isEmpty
                  ? Icon(
                      CupertinoIcons.profile_circled,
                      size: 60,
                      color: blackColor,
                    )
                  : ClipOval(
                      child: Container(
                        color: Colors.white,
                        height: 60,
                        width: 60,
                        child: ClipOval(
                          child: myNetworkImage(
                              context.read<MyImageCubit>().state),
                        ),
                      ),
                    ),
            );
          }),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BlocBuilder<NameCubit, dynamic>(builder: (context, state) {
                  return Row(
                    children: [
                      Text("Hi".translate(context),
                          style: heading2Grey1(context)),
                      const SizedBox(
                        width: 7,
                      ),
                      Text(context.read<NameCubit>().state,
                          style: heading2Grey1(context))
                    ],
                  );
                }),
                Text(
                  "Where do you want to go today?".translate(context),
                  style: heading3Grey1(context).copyWith(color: grey2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInput() {
    return BlocBuilder<UpdateCurrentAddressCubit, UpdateCurrentAddressState>(
      builder: (context, state) {
        if (state is UpdateCurrentAddresSuccess) {
          _currentAddress = state.currentAddress ?? '';
          if (state.lat != null && state.lng != null) {
            final latLng = LatLng(state.lat!, state.lng!);
            _selectedLocation.value = latLng;
            if (_homeMapController != null) {
              _homeMapController!.animateCamera(
                CameraUpdate.newLatLngZoom(latLng, 15),
              );
            }
          }
          context
              .read<BookRideRealTimeDataBaseCubit>()
              .updatePickupAddress(pickupAddress: _currentAddress);

          context.read<BookRideRealTimeDataBaseCubit>().updatePickupLatAndLng(
                pickupAddressLatitude: state.lat.toString(),
                pickupAddressLongitude: state.lng.toString(),
              );
          context.read<UpdateCurrentAddressCubit>().removeAddress();
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child:
                          const Icon(Icons.menu_outlined, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Flexible(
                    child: InkWell(
                      onTap: () {
                        _checkProfileAndProceed(() async {
                          context
                              .read<VehicleDataUpdateCubit>()
                              .updateVehicleTypeSelectedId(1);

                          context
                              .read<SelectedAddressCubit>()
                              .pickupAddressController
                              .text = _currentAddress;
                          context
                              .read<GetSuggestionAddressCubit>()
                              .getSuggestions("");
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserSearchLocation(
                                currentAddress: _currentAddress,
                              ),
                            ),
                          );
                          _loadRecentDropLocations();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.green),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _currentAddress.isEmpty
                                    ? "Your Current Location".translate(context)
                                    : _currentAddress,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMapWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              ValueListenableBuilder<LatLng>(
                valueListenable: _selectedLocation,
                builder: (context, latLng, _) {
                  final hasLocation =
                      latLng.latitude != 0 && latLng.longitude != 0;
                  final center =
                      hasLocation ? latLng : const LatLng(28.6139, 77.2090);

                  return GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: center,
                      zoom: 15,
                    ),
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                    zoomGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: true,
                    markers: hasLocation
                        ? {
                            Marker(
                              markerId: const MarkerId('current_location'),
                              position: latLng,
                              infoWindow: InfoWindow(
                                title: 'Your Location'.translate(context),
                              ),
                            ),
                          }
                        : {},
                    onMapCreated: (controller) {
                      _homeMapController = controller;
                      if (hasLocation) {
                        _mapCenterLat = latLng.latitude;
                        _mapCenterLng = latLng.longitude;
                        _homeMapController?.animateCamera(
                          CameraUpdate.newLatLngZoom(latLng, 15),
                        );
                      }
                    },
                    onCameraMove: (CameraPosition position) {
                      _mapCenterLat = position.target.latitude;
                      _mapCenterLng = position.target.longitude;
                    },
                    onCameraIdle: () {
                      _dropAddressDebounce?.cancel();
                      _dropAddressDebounce =
                          Timer(const Duration(milliseconds: 500), () {
                        if (_mapCenterLat != 0 && _mapCenterLng != 0) {
                          _fetchDropAddressFromLatLng(
                              _mapCenterLat, _mapCenterLng);
                        }
                      });
                    },
                  );
                },
              ),

              // Center Drop Point Pin Marker
              IgnorePointer(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pin Marker Graphic
                      Image.asset(
                        "assets/images/dropmarker.png",
                        height: 38,
                        width: 38,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on,
                              color: Colors.white, size: 24),
                        ),
                      ),

                      // Ground Shadow Effect underneath pin tip
                      Container(
                        width: 14,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius:
                              const BorderRadius.all(Radius.elliptical(7, 2.5)),
                        ),
                      ),

                      const SizedBox(height: 19),
                    ],
                  ),
                ),
              ),

              // Top Right Controls (Re-center & Search Screen)
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_selectedLocation.value.latitude != 0) {
                          _mapCenterLat = _selectedLocation.value.latitude;
                          _mapCenterLng = _selectedLocation.value.longitude;
                          _homeMapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(
                                _selectedLocation.value, 16),
                          );
                          _fetchDropAddressFromLatLng(
                              _mapCenterLat, _mapCenterLng);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(Icons.my_location,
                            color: themeColor, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _checkProfileAndProceed(() async {
                          context
                              .read<VehicleDataUpdateCubit>()
                              .updateVehicleTypeSelectedId(1);
                          context
                              .read<SelectedAddressCubit>()
                              .pickupAddressController
                              .text = _currentAddress;
                          context
                              .read<GetSuggestionAddressCubit>()
                              .getSuggestions("");
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserSearchLocation(
                                currentAddress: _currentAddress,
                              ),
                            ),
                          );
                          _loadRecentDropLocations();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fullscreen, color: themeColor, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              "View Map".translate(context),
                              style: regular2(context).copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Live Address Pill & Set Drop Button
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: InkWell(
                  onTap: () {
                    if (_mapCenterLat != 0 && _mapCenterLng != 0) {
                      _confirmSelectedDropLocation(
                        _mapCenterLat,
                        _mapCenterLng,
                        _selectedDropAddress.isNotEmpty
                            ? _selectedDropAddress
                            : _currentAddress,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF0F9D58).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.radio_button_checked,
                            color: Color(0xFF0F9D58),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isFetchingDropAddress
                                ? "Locating address...".translate(context)
                                : (_selectedDropAddress.isEmpty
                                    ? "Drag map to set drop location"
                                        .translate(context)
                                    : _selectedDropAddress),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: regular2(context).copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: themeColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Set Drop".translate(context),
                                style: regular2(context).copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.arrow_forward_rounded,
                                  size: 13, color: Colors.black),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    if (_promoBanners.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 2.3 / 1,
            child: PageView.builder(
              controller: _promoBannerController,
              itemCount: _promoBanners.length,
              itemBuilder: (context, index) {
                final banner = _promoBanners[index];
                final imageUrl = (banner['image'] ?? '').toString();
                final heading = (banner['heading'] ?? '').toString().trim();

                return InkWell(
                  onTap: () {
                    _checkProfileAndProceed(() async {
                      context
                          .read<VehicleDataUpdateCubit>()
                          .updateVehicleTypeSelectedId(1);
                      context
                          .read<SelectedAddressCubit>()
                          .pickupAddressController
                          .text = _currentAddress;
                      context
                          .read<GetSuggestionAddressCubit>()
                          .getSuggestions("");
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserSearchLocation(
                            currentAddress: _currentAddress,
                          ),
                        ),
                      );
                      _loadRecentDropLocations();
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            imageUrl,
                            headers: const {
                              "ngrok-skip-browser-warning": "true"
                            },
                            fit: BoxFit.fill,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                          if (heading.isNotEmpty)
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    heading,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: heading2Grey1(context).copyWith(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_promoBanners.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 6,
              child: ListenableBuilder(
                listenable: _promoBannerController,
                builder: (context, _) {
                  final currentPage = _promoBannerController.hasClients
                      ? (_promoBannerController.page ?? 0).round()
                      : 0;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _promoBanners.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: currentPage == index ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: currentPage == index
                              ? themeColor
                              : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFixedOfferBannerCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        height: 105,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFB800),
              Color(0xFFFF9100),
              Color(0xFFFF7A00),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF8800).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Background Ambient Light Circle 1 (Top Left)
              Positioned(
                top: -25,
                left: -25,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
              ),
              // Background Ambient Light Circle 2 (Bottom Right)
              Positioned(
                bottom: -35,
                right: 40,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
              // Decorative Sparkle Icon (Top Right)
              Positioned(
                top: 10,
                right: 95,
                child: Icon(
                  Icons.auto_awesome,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 16,
                ),
              ),
              // Content Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Special Offer Glassmorphic Pill Tag
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.local_offer_rounded,
                                  size: 12,
                                  color: Color(0xFF1E1E1E),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "SPECIAL OFFER".translate(context),
                                  style: regular2(context).copyWith(
                                    color: const Color(0xFF1E1E1E),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Headline
                          Text(
                            "Get 20% OFF Your First Ride".translate(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: heading2Grey1(context).copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Subtitle Info
                          Text(
                            "Automatic discount applied at checkout"
                                .translate(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: regular2(context).copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // App Logo Badge Ring
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset(
                            "assets/images/appIcon.png",
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSearches() {
    final displayedSearches = recentDropLocations.take(3).toList();
    if (displayedSearches.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: Colors.black87,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "Recent Searches".translate(context),
                  style: heading3Grey1(context).copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayedSearches.length,
              separatorBuilder: (context, index) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Divider(
                  height: 1,
                  thickness: 0.7,
                  color: Color(0xFFF1F5F9),
                ),
              ),
              itemBuilder: (context, index) {
                final item = displayedSearches[index];
                final String fullAddress = item['address'] ?? "";
                final parsed = parseCleanAddress(fullAddress);
                final String mainTitle = parsed["title"] ?? fullAddress;
                final String subTitle = parsed["subtitle"] ?? "";

                return InkWell(
                  onTap: () {
                    _checkProfileAndProceed(() {
                      if (_currentAddress.isEmpty) {
                        showAlert = false;
                        startLiveLocationTracking();
                        setState(() {});
                        return;
                      }

                      context
                          .read<SelectedAddressCubit>()
                          .dropOffAddressController
                          .text = fullAddress;
                      context
                          .read<BookRideRealTimeDataBaseCubit>()
                          .updateDropOffLatAndLng(
                            dropoffAddressLatitude: item['lat'] ?? "",
                            dropoffAddressLongitude: item['lng'] ?? "",
                          );

                      final bookRide =
                          context.read<BookRideRealTimeDataBaseCubit>();

                      bookRide.updatePickupAddress(
                        pickupAddress: _currentAddress,
                      );
                      bookRide.updateDropOffAddress(
                        dropoffAddress: fullAddress,
                      );

                      if (bookRide.state.pickupAddress.isNotEmpty &&
                          bookRide.state.dropoffAddress.isNotEmpty &&
                          bookRide.state.pickupAddressLatitude.isNotEmpty &&
                          bookRide.state.pickupAddressLongitude.isNotEmpty &&
                          bookRide.state.dropoffAddressLatitude.isNotEmpty &&
                          bookRide.state.dropoffAddressLongitude.isNotEmpty) {
                        goTo(const LoadingNearbySearchScreen());
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.black87,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mainTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: regular(context).copyWith(
                                  color: Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (subTitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: regular(context).copyWith(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Explore".translate(context),
                style: heading3Grey1(context).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          BlocBuilder<GetVehicleDataCubit, GetVehicleDataState>(
              builder: (context, state) {
            List<ItemTypes> itemList = [];
            if (state is GetVehicleSuccess && state.itemTypes.isNotEmpty) {
              itemList = state.itemTypes;
              context
                  .read<SetVehicleCategoryCubit>()
                  .updateSetVehicleCategoryList(itemList);
            }
            bool isLoading = state is GetVehicleLoading;
            return _buildVehicleGrid(itemList, isLoading);
          }),
        ],
      ),
    );
  }

  Widget _buildVehicleGrid(List<ItemTypes> items, bool isLoading) {
    if (items.isEmpty && !isLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 30, bottom: 20),
        child: Center(
          child: InkWell(
            onTap: () {
              context.read<GetVehicleDataCubit>().getAllCategories();
              setState(() {});
            },
            child: Text(
              "Retry".translate(context),
              style: regular2(context),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 104,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: isLoading ? 8 : items.length,
        itemBuilder: (_, index) {
          if (isLoading) return ShimmerLoader();
          final item = items[index];

          return Container(
            width: 86,
            margin: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                _checkProfileAndProceed(() async {
                  context
                      .read<VehicleDataUpdateCubit>()
                      .updateVehicleTypeSelectedId(item.id);

                  context
                      .read<SelectedAddressCubit>()
                      .pickupAddressController
                      .text = _currentAddress;
                  context
                      .read<GetSuggestionAddressCubit>()
                      .getSuggestions("");

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserSearchLocation(
                        currentAddress: _currentAddress,
                      ),
                    ),
                  );
                  _loadRecentDropLocations();
                });
              },
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      item.image ?? "",
                      headers: const {"ngrok-skip-browser-warning": "true"},
                      width: 44,
                      height: 44,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.name ?? "",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: heading3(context).copyWith(
                        color: blackColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

void getCurrency(BuildContext context) {
  context.read<GeneralCubit>().fetchGeneralSetting(context);
}

class DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(size.width, 0); // thoda slope upar
    path.lineTo(size.width - 40, size.height); // neeche right tak slope
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
