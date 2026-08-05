import 'dart:async';
import 'package:flutter/cupertino.dart';
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

class _ItemHomeScreenState extends State<ItemHomeScreen> with WidgetsBindingObserver {
  bool _isLocationServiceDialogShowing = false;
  final ValueNotifier<LatLng> _selectedLocation =
      ValueNotifier(const LatLng(0, 0));
  static const LatLng _defaultLocation = LatLng(37.7749, -122.4194);
  Timer? _debounceTimer; // San Francisco
  Timer? _bannerTimer;
  final PageController _promoBannerController = PageController();
  List<Map<String, dynamic>> _promoBanners = [];
  bool _promoBannerLoading = true;
  bool showAlert = false;
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
        _promoBannerLoading = false;
      });

      _startPromoBannerAutoScroll();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _promoBannerLoading = false;
        _promoBanners = [];
      });
    }
  }

  void _startPromoBannerAutoScroll() {
    _bannerTimer?.cancel();
    if (_promoBanners.length < 2) return;

    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_promoBannerController.hasClients) return;
      final currentPage = (_promoBannerController.page ?? 0).round();
      final nextPage = (currentPage + 1) % _promoBanners.length;
      _promoBannerController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
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
        desiredAccuracy: LocationAccuracy.high,
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
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      context.read<UpdateCurrentAddressCubit>().getAddressFromLatLng(
            latitude: position.latitude,
            longitude: position.longitude,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // ignore: deprecated_member_use
      onPopInvoked: (v) async =>
          dialogExit(context), // Assuming this is defined elsewhere
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
              child: Image.asset(
                "assets/images/home_background_ui.png",
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
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
                    _buildPromoBanner(),
                    const SizedBox(height: 20),
                    _buildExploreSection(),
                    const SizedBox(height: 20),
                    if (recentDropLocations.isNotEmpty) ...[
                      _buildRecentSearches(),
                      const SizedBox(height: 20),
                    ],
                    const SizedBox(height: 70), // Bottom padding so content scrolls above fixed footer
                  ],
                ),
              ),
            ),
            // Layer 3: Persistent Footer anchored at bottom of screen
            Positioned(
              left: 16,
              right: 16,
              bottom: 8,
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
                      onTap: () async {
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

  Widget _buildPromoBanner() {
    if (_promoBannerLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: AspectRatio(
          aspectRatio: 3 / 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );
    }

    if (_promoBanners.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 3 / 1,
              child: PageView.builder(
                controller: _promoBannerController,
                itemCount: _promoBanners.length,
                itemBuilder: (context, index) {
                  final banner = _promoBanners[index];
                  final imageUrl = (banner['image'] ?? '').toString();
                  final heading = (banner['heading'] ?? '').toString().trim();

                  return Container(
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
                            headers: const {"ngrok-skip-browser-warning": "true"},
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              color: themeColor.withValues(alpha: 0.15),
                              alignment: Alignment.center,
                              child: const Icon(Icons.image, size: 40),
                            ),
                          ),
                          if (heading.isNotEmpty)
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: AspectRatio(
        aspectRatio: 3 / 1,
        child: Container(
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
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Get 20% Off".translate(context),
                        style: heading2Grey1(context).copyWith(
                          color: blackColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Your First Ride".translate(context),
                        style: heading3Grey1(context).copyWith(
                          color: themeColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        "assets/images/appIcon.png",
                        height: 45,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "FoxRun\u2122".translate(context),
                        style: heading2Grey1(context).copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSearches() {
    final displayedSearches = recentDropLocations.take(5).toList();
    if (displayedSearches.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: themeColor, size: 18),
                const SizedBox(width: 6),
                Text(
                  "Recent Searches".translate(context),
                  style: heading3Grey1(context).copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: displayedSearches.length > 3
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: displayedSearches.length,
                separatorBuilder: (context, index) => const Divider(
                  height: 1,
                  color: Color(0xFFF0F0F0),
                ),
                itemBuilder: (context, index) {
                  final item = displayedSearches[index];
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    dense: true,
                    leading: Icon(Icons.history, color: themeColor, size: 18),
                    title: Text(
                      item['address'] ?? "",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: regular(context).copyWith(
                        color: notifires.getGrey1whiteColor,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () {
                      if (_currentAddress.isEmpty) {
                        showAlert = false;
                        startLiveLocationTracking();
                        setState(() {});
                        return;
                      }

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

                      final bookRide =
                          context.read<BookRideRealTimeDataBaseCubit>();

                      bookRide.updatePickupAddress(
                        pickupAddress: _currentAddress,
                      );
                      bookRide.updateDropOffAddress(
                        dropoffAddress: item['address'] ?? "",
                      );
                      debugPrint(
                          'pic latLang with address ${bookRide.state.pickupAddressLatitude},${bookRide.state.pickupAddressLongitude} ${bookRide.state.pickupAddress}');
                      debugPrint(
                          'drop latLang with address ${bookRide.state.dropoffAddressLatitude},${bookRide.state.dropoffAddressLongitude} ${bookRide.state.dropoffAddress}');

                      if (bookRide.state.pickupAddress.isNotEmpty &&
                          bookRide.state.dropoffAddress.isNotEmpty &&
                          bookRide.state.pickupAddressLatitude.isNotEmpty &&
                          bookRide.state.pickupAddressLongitude.isNotEmpty &&
                          bookRide.state.dropoffAddressLatitude.isNotEmpty &&
                          bookRide.state.dropoffAddressLongitude.isNotEmpty) {
                        goTo(const LoadingNearbySearchScreen());
                      } else {}
                    },
                  );
                },
              ),
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
    return items.isEmpty && isLoading == false
        ? Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Center(
                child: InkWell(
                    onTap: () {
                      context.read<GetVehicleDataCubit>().getAllCategories();
                      setState(() {});
                    },
                    child: Text(
                      "Retry".translate(context),
                      style: regular2(context),
                    ))),
          )
        : GridView.builder(
            padding: const EdgeInsets.symmetric(vertical: 15),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: isLoading ? 8 : items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
                mainAxisExtent: 88),
            itemBuilder: (_, index) {
              if (isLoading) return ShimmerLoader();
              final item = items[index];

              return InkWell(
                onTap: () async {
                  context
                      .read<VehicleDataUpdateCubit>()
                      .updateVehicleTypeSelectedId(item.id);

                  context
                      .read<SelectedAddressCubit>()
                      .pickupAddressController
                      .text = _currentAddress;
                  context.read<GetSuggestionAddressCubit>().getSuggestions("");

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserSearchLocation(
                        currentAddress: _currentAddress,
                      ),
                    ),
                  );
                  _loadRecentDropLocations();
                },
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
              );
            },
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
