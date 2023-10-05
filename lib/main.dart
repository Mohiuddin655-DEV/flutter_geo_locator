import 'dart:async';
import 'dart:io' show Platform;

import 'package:baseflow_plugin_template/baseflow_plugin_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

final MaterialColor themeMaterialColor =
    BaseflowPluginExample.createMaterialColor(
        const Color.fromRGBO(48, 49, 60, 1));

void main() {
  runApp(const MyApp());
}

class Application extends StatefulWidget {
  const Application({super.key});

  @override
  State<Application> createState() => _ApplicationState();
}

class _ApplicationState extends State<Application> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Geo locator",
      theme: ThemeData(
        primarySwatch: Colors.orange,
      ),
      home: const Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              children: [
                Text("data"),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  static ExamplePage createPage() {
    return ExamplePage(
      Icons.location_on,
      (context) => const MyApp(),
    );
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const String _kLocationServicesDisabledMessage =
      'Location services are disabled.';
  static const String _kPermissionDeniedMessage = 'Permission denied.';
  static const String _kPermissionDeniedForeverMessage =
      'Permission denied forever.';
  static const String _kPermissionGrantedMessage = 'Permission granted.';

  final GeolocatorPlatform _geoLocatorPlatform = GeolocatorPlatform.instance;
  final List<_PositionItem> _positionItems = <_PositionItem>[];
  StreamSubscription<Position>? _positionStatus;
  StreamSubscription<ServiceStatus>? _serviceStatus;
  bool positionStreamStarted = false;

  @override
  void initState() {
    super.initState();
    _toggleServiceStatusStream();
  }

  @override
  Widget build(BuildContext context) {
    const sizedBox = SizedBox(
      height: 10,
    );

    void onMenu(int value) async {
      switch (value) {
        case 1:
          _getLocationAccuracy();
          break;
        case 2:
          _requestTemporaryFullAccuracy();
          break;
        case 3:
          _openAppSettings();
          break;
        case 4:
          _openLocationSettings();
          break;
        case 5:
          setState(_positionItems.clear);
          break;
        default:
          break;
      }
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Geo locator",
      theme: ThemeData(
        primarySwatch: Colors.orange,
      ),
      home: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: const Text("Geo locator"),
          backgroundColor: Colors.white,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
          ),
          actions: [
            PopupMenuButton(
              elevation: 40,
              onSelected: onMenu,
              itemBuilder: (context) {
                return [
                  if (Platform.isIOS)
                    const PopupMenuItem(
                      value: 1,
                      child: Text("Get Location Accuracy"),
                    ),
                  if (Platform.isIOS)
                    const PopupMenuItem(
                      value: 2,
                      child: Text("Request Temporary Full Accuracy"),
                    ),
                  const PopupMenuItem(
                    value: 3,
                    child: Text("Open App Settings"),
                  ),
                  if (Platform.isAndroid || Platform.isWindows)
                    const PopupMenuItem(
                      value: 4,
                      child: Text("Open Location Settings"),
                    ),
                  const PopupMenuItem(
                    value: 5,
                    child: Text("Clear"),
                  ),
                ];
              },
            ),
          ],
        ),
        backgroundColor: Colors.grey.shade100,
        body: ListView.builder(
          itemCount: _positionItems.length,
          itemBuilder: (context, index) {
            final positionItem = _positionItems[index];

            if (positionItem.type == _PositionItemType.log) {
              return ListTile(
                title: Text(
                  positionItem.displayValue,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            } else {
              return Card(
                child: ListTile(
                  tileColor: themeMaterialColor,
                  title: Text(
                    positionItem.displayValue,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            }
          },
        ),
        floatingActionButton: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              onPressed: () {
                positionStreamStarted = !positionStreamStarted;
                _togglePositionListening();
              },
              tooltip: (_positionStatus == null)
                  ? 'Start position updates'
                  : _positionStatus!.isPaused
                      ? 'Resume'
                      : 'Pause',
              backgroundColor: _determineButtonColor(),
              child: (_positionStatus == null || _positionStatus!.isPaused)
                  ? const Icon(Icons.play_arrow)
                  : const Icon(Icons.pause),
            ),
            sizedBox,
            FloatingActionButton(
              onPressed: _getCurrentPosition,
              child: const Icon(Icons.my_location),
            ),
            sizedBox,
            FloatingActionButton(
              onPressed: _getLastKnownPosition,
              child: const Icon(Icons.bookmark),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getCurrentPosition() async {
    final hasPermission = await _handlePermission();

    if (!hasPermission) {
      return;
    }

    final position = await _geoLocatorPlatform.getCurrentPosition();
    _updatePositionList(
      _PositionItemType.position,
      position.toString(),
    );
  }

  Future<bool> _handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await _geoLocatorPlatform.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _updatePositionList(
        _PositionItemType.log,
        _kLocationServicesDisabledMessage,
      );

      return false;
    }

    permission = await _geoLocatorPlatform.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _geoLocatorPlatform.requestPermission();
      if (permission == LocationPermission.denied) {
        _updatePositionList(
          _PositionItemType.log,
          _kPermissionDeniedMessage,
        );

        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _updatePositionList(
        _PositionItemType.log,
        _kPermissionDeniedForeverMessage,
      );

      return false;
    }

    _updatePositionList(
      _PositionItemType.log,
      _kPermissionGrantedMessage,
    );
    return true;
  }

  void _updatePositionList(_PositionItemType type, String displayValue) {
    _positionItems.add(_PositionItem(type, displayValue));
    setState(() {});
  }

  bool _isListening() =>
      !(_positionStatus == null || _positionStatus!.isPaused);

  Color _determineButtonColor() {
    return _isListening() ? Colors.green : Colors.red;
  }

  void _toggleServiceStatusStream() {
    if (_serviceStatus == null) {
      final subscription = _geoLocatorPlatform.getServiceStatusStream();
      _serviceStatus = subscription.handleError((error) {
        _serviceStatus?.cancel();
        _serviceStatus = null;
      }).listen((serviceStatus) {
        String serviceStatusValue;
        if (serviceStatus == ServiceStatus.enabled) {
          if (positionStreamStarted) {
            _togglePositionListening();
          }
          serviceStatusValue = 'enabled';
        } else {
          if (_positionStatus != null) {
            setState(() {
              _positionStatus?.cancel();
              _positionStatus = null;
              _updatePositionList(
                  _PositionItemType.log, 'Position Stream has been canceled');
            });
          }
          serviceStatusValue = 'disabled';
        }
        _updatePositionList(
          _PositionItemType.log,
          'Location service has been $serviceStatusValue',
        );
      });
    }
  }

  /// POSITION CHANGING STREAM
  void _togglePositionListening() {
    if (_positionStatus == null) {
      _positionStatus = _geoLocatorPlatform
          .getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 100,
              timeLimit: Duration(milliseconds: 1000 * 5),
            ),
          )
          .handleError(_positionSubscriptionErrorHandle)
          .listen(_positionChanged);
      _positionStatus?.pause();
    }

    setState(() {
      if (_positionStatus == null) {
        return;
      }

      String statusDisplayValue;
      if (_positionStatus!.isPaused) {
        _positionStatus!.resume();
        statusDisplayValue = 'resumed';
      } else {
        _positionStatus!.pause();
        statusDisplayValue = 'paused';
      }

      _updatePositionList(
        _PositionItemType.log,
        'Listening for position updates $statusDisplayValue',
      );
    });
  }

  void _positionChanged(Position position) {
    _updatePositionList(
      _PositionItemType.position,
      position.toString(),
    );
  }

  void _positionSubscriptionErrorHandle(dynamic error) {
    _positionStatus?.cancel();
    _positionStatus = null;
  }

  @override
  void dispose() {
    if (_positionStatus != null) {
      _positionStatus!.cancel();
      _positionStatus = null;
    }

    super.dispose();
  }

  void _getLastKnownPosition() async {
    final position = await _geoLocatorPlatform.getLastKnownPosition();
    if (position != null) {
      _updatePositionList(
        _PositionItemType.position,
        position.toString(),
      );
    } else {
      _updatePositionList(
        _PositionItemType.log,
        'No last known position available',
      );
    }
  }

  void _getLocationAccuracy() async {
    final status = await _geoLocatorPlatform.getLocationAccuracy();
    _handleLocationAccuracyStatus(status);
  }

  void _requestTemporaryFullAccuracy() async {
    final status = await _geoLocatorPlatform.requestTemporaryFullAccuracy(
      purposeKey: "TemporaryPreciseAccuracy",
    );
    _handleLocationAccuracyStatus(status);
  }

  void _handleLocationAccuracyStatus(LocationAccuracyStatus status) {
    String locationAccuracyStatusValue;
    if (status == LocationAccuracyStatus.precise) {
      locationAccuracyStatusValue = 'Precise';
    } else if (status == LocationAccuracyStatus.reduced) {
      locationAccuracyStatusValue = 'Reduced';
    } else {
      locationAccuracyStatusValue = 'Unknown';
    }
    _updatePositionList(
      _PositionItemType.log,
      '$locationAccuracyStatusValue location accuracy granted.',
    );
  }

  void _openAppSettings() async {
    final opened = await _geoLocatorPlatform.openAppSettings();
    String displayValue;

    if (opened) {
      displayValue = 'Opened Application Settings.';
    } else {
      displayValue = 'Error opening Application Settings.';
    }

    _updatePositionList(
      _PositionItemType.log,
      displayValue,
    );
  }

  void _openLocationSettings() async {
    final opened = await _geoLocatorPlatform.openLocationSettings();
    String displayValue;

    if (opened) {
      displayValue = 'Opened Location Settings';
    } else {
      displayValue = 'Error opening Location Settings';
    }

    _updatePositionList(
      _PositionItemType.log,
      displayValue,
    );
  }
}

enum _PositionItemType {
  log,
  position,
}

class _PositionItem {
  _PositionItem(this.type, this.displayValue);

  final _PositionItemType type;
  final String displayValue;
}
