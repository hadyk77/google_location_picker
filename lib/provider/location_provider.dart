import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_location_picker/models/location_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as location;

class LocationProvider extends ChangeNotifier {
  late LocationModel currentLocation;
  final location.Location _location;
  late LocationModel _currentLocation;
  final String qKey;
  late GoogleMapController controller;

  List<LocationModel> searchResult = [];

  LocationProvider(this._location, this.qKey) {
    currentLocation = LocationModel(latitude: 0, longitude: 0);
    _currentLocation = LocationModel(latitude: 0, longitude: 0);
  }
  Future getCurrentLocation() async {
    final hasPermission =
        (await _location.hasPermission()) == location.PermissionStatus.granted;

    if (!hasPermission) {
      await _location.requestPermission();
    }

    final fetchedLocation = await _location.getLocation();
    final model = LocationModel(
      latitude: fetchedLocation.latitude ?? 0,
      longitude: fetchedLocation.longitude ?? 0,
    );
    final address = await getAddress(model);
    currentLocation = currentLocation.copyWith(
      latitude: fetchedLocation.latitude,
      longitude: fetchedLocation.longitude,
      address: address,
    );

    _currentLocation = currentLocation;
    moveToCurrentLoction();
    notifyListeners();
  }

  Future<String?> getAddress(LocationModel location) async {
    String host = 'https://maps.google.com/maps/api/geocode/json';
    final url =
        '$host?key=$qKey&language=en&latlng=${location.latitude},${location.longitude}';

    var response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      Map data = jsonDecode(response.body);
      String formattedAddress = data["results"][0]["formatted_address"];

      return formattedAddress;
    } else {
      return null;
    }
  }

  onCameraMove(CameraPosition cameraPosition) {
    if (cameraPosition.target.latitude != 0 &&
        cameraPosition.target.longitude != 0) {
      _currentLocation = currentLocation.copyWith(
        latitude: cameraPosition.target.latitude,
        longitude: cameraPosition.target.longitude,
      );
    }
  }

  onCameraId() async {
    if (currentLocation.latitude != 0 && currentLocation.longitude != 0) {
      final address = await getAddress(currentLocation);
      _currentLocation = _currentLocation.copyWith(address: address);
      currentLocation = _currentLocation;
      notifyListeners();
    }
  }

  onMapCreated(GoogleMapController controller) async {
    this.controller = controller;
  }

  Future<List<LocationModel>> search(String query) async {
    String url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&location=${currentLocation.latitude},${currentLocation.longitude}t&key=$qKey";

    final response = await http.get(
      Uri.parse(url),
    );

    final json = jsonDecode(response.body);

    searchResult = List<LocationModel>.from(json['predictions'].map(
      (map) => LocationModel(
        latitude: 0,
        longitude: 0,
        address: map['description'],
        placeId: map['place_id'],
      ),
    ));

    notifyListeners();
    return searchResult;
  }

  Future<LocationModel> getLocationDetails(LocationModel model) async {
    final url =
        "https://maps.googleapis.com/maps/api/place/details/json?key=$qKey"
        "&placeid=${model.placeId}";
    final response = await http.get(Uri.parse(url));
    final json = jsonDecode(response.body);

    return LocationModel(
        latitude: json['result']['geometry']['location']['lat'],
        longitude: json['result']['geometry']['location']['lng'],
        address: json['result']['formatted_address']);
  }

  onLocationPicked(LocationModel location) async {
    currentLocation = await getLocationDetails(location);

    moveToCurrentLoction();
  }

  void moveToCurrentLoction() {
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: LatLng(currentLocation.latitude, currentLocation.longitude),
      zoom: 15,
    )));
  }
}
