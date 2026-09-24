// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui' as ui;
import 'package:equatable/equatable.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/utils/common_widget.dart';


abstract class MarkerState extends Equatable {
  @override
  List<Object?> get props => [];
}

class MarkerInitial extends MarkerState {}

class MarkerUpdated extends MarkerState {
  final Set<Marker> markers;

  MarkerUpdated({required this.markers});

  @override
  List<Object?> get props => [markers];
}

class MarkerCubit extends Cubit<MarkerState> {
  MarkerCubit() : super(MarkerInitial());

  final Set<Marker> _markers = {};

  void addOrUpdateMarker(LatLng position, String title, String markerId,
      String image, int size, {double rotation = 0.0}) async {
    final Uint8List markerIcon = await getBytesFromAsset(image, size);

    final Offset anchor = (markerId.toLowerCase().contains('driver') ||
            title.toLowerCase().contains('driver'))
        ? const Offset(0.5, 0.5)
        : const Offset(0.5, 1.0);

    Marker marker = Marker(
      markerId: MarkerId(markerId),
      position: position,
      draggable: false,
      zIndex: 2,
      flat: true,
      rotation: rotation,
      anchor: anchor,
      infoWindow: InfoWindow(title: title),
      icon: BitmapDescriptor.fromBytes(markerIcon),
    );

    _markers.removeWhere((m) => m.markerId.value == markerId);
    _markers.add(marker);

    emit(MarkerUpdated(markers: _markers));
  }

  Future<Uint8List> getBytesFromAsset(String path, int width, {int? height}) async {
    ByteData data = await rootBundle.load(path);
    final bool isPin = path.contains('dropmarker') || path.contains('pickupmarker');
    final int? targetH = height ?? (isPin ? 42 : null);
    final int? targetW = targetH != null ? null : (width > 0 ? width : null);

    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: targetW, targetHeight: targetH);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  void resetMarker() {
    emit(MarkerInitial());
  }
}

abstract class GetUpdatedLocationState extends Equatable {
  @override
  List<Object?> get props => [];
}

class GetUpdatedLocationInitial extends GetUpdatedLocationState {}

class GetUpdatedLocationUpdated extends GetUpdatedLocationState {
  final double lat;
  final double lng;

  GetUpdatedLocationUpdated({
    required this.lat,
    required this.lng,
  });

  @override
  List<Object?> get props => [
        lat,
        lng,
      ];
}

class GetUpdatedLocationCubit extends Cubit<GetUpdatedLocationState> {
  GetUpdatedLocationCubit() : super(GetUpdatedLocationInitial());

  StreamSubscription<DatabaseEvent>? _driverLocationSubscription;

  void updateDriverLocation({int? selectedDriverId}) {
    if (selectedDriverId == null) return;

    final DatabaseReference database = FirebaseDatabase.instance
        .ref()
        .child("drivers")
        .child(selectedDriverId.toString());

    _driverLocationSubscription?.cancel();

    _driverLocationSubscription = database.onValue.listen((event) {
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        final driverData = event.snapshot.value as Map;
        final location = driverData['location'];


        if (location != null &&
            location is Map &&
            location['latitude'] != null &&
            location['longitude'] != null) {
          final double lat = double.parse(location['latitude'].toString());
          final double lng = double.parse(location['longitude'].toString());

          emit(GetUpdatedLocationUpdated(
            lat: lat,
            lng: lng,
          ));
        }
      }
    }, onError: (error) {
   //
    });
  }

  void resetLocation() {
    _driverLocationSubscription?.cancel();
    emit(GetUpdatedLocationInitial());
  }

  @override
  Future<void> close() {
    _driverLocationSubscription?.cancel();
    return super.close();
  }
}

abstract class UserMarkerState extends Equatable {
  @override
  List<Object?> get props => [];
}

class UserMarkerInitial extends UserMarkerState {}

class UserMarkerUpdated extends UserMarkerState {
  final Set<Marker> markers;

  UserMarkerUpdated({required this.markers});

  @override
  List<Object?> get props => [markers];
}



class UserMarkerCubit extends Cubit<UserMarkerState> {
  UserMarkerCubit() : super(UserMarkerInitial());

  final Set<Marker> _markers = {};

  Future<void> addOrUpdateMarker(
    LatLng position,
    String title,
    String markerId,
    String iconPath,
    int size,
    {double rotation = 0.0}
  ) async {
    Uint8List markerIcon;

    if (iconPath.endsWith('.png') && (iconPath.contains('BIKE') || iconPath.contains('AUTO') || iconPath.contains('CAB'))) {
      markerIcon = await getBytesFromAsset(iconPath, 85);
    } else if (title.toString() == "Driver Location") {
      markerIcon = await createCustomMarkerImage(iconPath);
    } else {
      markerIcon = await getBytesFromAsset(iconPath, size);
    }

    final Offset anchor = (markerId.toLowerCase().contains('driver') ||
            title.toLowerCase().contains('driver') ||
            markerId.startsWith('nearby_'))
        ? const Offset(0.5, 0.5)
        : const Offset(0.5, 1.0);

    _markers.removeWhere((marker) => marker.markerId.value == markerId);
    _markers.add(
      Marker(
        markerId: MarkerId(markerId),
        position: position,
        infoWindow: InfoWindow(title: title),
        rotation: rotation,
        flat: true,
        anchor: anchor,
        icon: BitmapDescriptor.bytes(markerIcon),
      ),
    );
    emit(UserMarkerUpdated(markers: _markers));
  }

  void removeMarker(String markerId) {
    _markers.removeWhere((marker) => marker.markerId.value == markerId);
    emit(UserMarkerUpdated(markers: _markers));
  }

  void removeNearbyMarkers() {
    final before = _markers.length;
    _markers.removeWhere((marker) => marker.markerId.value.startsWith('nearby_'));
    if (_markers.length != before) {
      emit(UserMarkerUpdated(markers: Set.from(_markers)));
    }
  }

  Future<void> addNearbyDrivers(
    List<Map<String, dynamic>> drivers,
    String iconAsset,
  ) async {
    final Uint8List iconBytes = await getBytesFromAsset(iconAsset, 85);
    _markers.removeWhere((m) => m.markerId.value.startsWith('nearby_'));

    for (final driver in drivers) {
      final lat = (driver['latitude'] as num?)?.toDouble();
      final lng = (driver['longitude'] as num?)?.toDouble();
      final id = driver['id']?.toString() ?? '';
      if (lat != null && lng != null && id.isNotEmpty) {
        final heading = (driver['heading'] as num?)?.toDouble() ??
            (driver['bearing'] as num?)?.toDouble() ??
            0.0;

        _markers.add(
          Marker(
            markerId: MarkerId('nearby_$id'),
            position: LatLng(lat, lng),
            flat: true,
            rotation: heading,
            anchor: const Offset(0.5, 0.5),
            zIndex: 1,
            icon: BitmapDescriptor.bytes(iconBytes),
          ),
        );
      }
    }
    emit(UserMarkerUpdated(markers: Set.from(_markers)));
  }

  void updateDriverMarkerFast(LatLng position, double rotation, {String markerId = 'driver_marker'}) {
    final existingList = _markers.where((m) => m.markerId.value == markerId).toList();
    if (existingList.isNotEmpty) {
      final existing = existingList.first;
      final updated = existing.copyWith(
        positionParam: position,
        rotationParam: rotation,
      );
      _markers.removeWhere((m) => m.markerId.value == markerId);
      _markers.add(updated);
      emit(UserMarkerUpdated(markers: Set.from(_markers)));
    }
  }

  Future<Uint8List> getBytesFromAsset(String path, int width, {int? height}) async {
    ByteData data = await rootBundle.load(path);
    final bool isPin = path.contains('dropmarker') || path.contains('pickupmarker');
    final int? targetH = height ?? (isPin ? 42 : null);
    final int? targetW = targetH != null ? null : (width > 0 ? width : null);

    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: targetW, targetHeight: targetH);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  void clear() {
    emit(UserMarkerInitial());
    removeMarker("User_marker");
    removeMarker("drop_marker");
    removeMarker("driver_marker");
    removeNearbyMarkers();
  }
}
