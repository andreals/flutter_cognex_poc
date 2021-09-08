import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';

import 'package:cmbsdk_flutter/cmbsdk_flutter.dart';
import 'package:cmbsdk_flutter/cmbsdk_flutter_constants.dart';

void main() {
  runApp(
    new MaterialApp(
      home: new MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  //----------------------------------------------------------------------------
  // The cmbSDK supports multi-code scanning (scanning multiple barcodes at
  // one time); thus scan results are returned as an array. Note that
  // this sample app does not demonstrate the use of these multi-code features.
  //----------------------------------------------------------------------------
  List<dynamic> _resultsArray = [];

  bool _isScanning = false;
  String _cmbSDKVersion = 'N/A';
  String _connectionStatusText = 'Disconnected';
  Color _connectionStatusBackground = Colors.redAccent;
  String _scanButtonText = '(NOT CONNECTED)';
  bool _scanButtonEnabled = false;

  //----------------------------------------------------------------------------
  // If USE_PRECONFIGURED_DEVICE is YES, then the app will create a reader
  // using the values of device/cameraMode. Otherwise, the app presents
  // a pick list for the user to select either MX-1xxx, MX100 or the built-in
  // camera.
  //----------------------------------------------------------------------------
  final bool _usePreconfiguredDevice = false;
  int _deviceType = CmbsdkDeviceType.MXReader;
  int _cameraMode = CmbsdkCameraMode.NoAimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);

    initCmbSDK();
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appLifecycleState) {
    switch (appLifecycleState) {
      case AppLifecycleState.resumed:
        CmbsdkFlutter.connect()
            .catchError((error, stackTrace) => print('${error.message}'));
        break;
      case AppLifecycleState.inactive:
        if (_isScanning)
          CmbsdkFlutter.stopScanning()
              .catchError((error, stackTrace) => print('${error.message}'));
        break;
      case AppLifecycleState.paused:
        CmbsdkFlutter.disconnect()
            .catchError((error, stackTrace) => print('${error.message}'));
        break;
    }
  }

  Future<void> initCmbSDK() async {
    String cmbSDKVersion = 'N/A';

    // This is called when a MX-1xxx device has became available (USB cable was plugged, or MX device was turned on),
    // or when a MX-1xxx that was previously available has become unavailable (USB cable was unplugged, turned off due to inactivity or battery drained)
    CmbsdkFlutter.setAvailabilityChangedListener((availability) {
      if (availability == CmbsdkAvailability.Available.index) {
        CmbsdkFlutter.connect()
            .catchError((error, stackTrace) => print('${error.message}'));
      } else {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Text('Device became unavailable'),
              actions: [
                TextButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    });

    // This is called when a connection with the reader has been changed.
    // The reader is usable only in the "Connected" state
    CmbsdkFlutter.setConnectionStateChangedListener((state) {
      if (state == CmbsdkConnectionState.Connected.index) {
        _configureReaderDevice();

        _updateUIByConnectionState(CmbsdkConnectionState.Connected);
      } else {
        _updateUIByConnectionState(CmbsdkConnectionState.Disconnected);
      }

      if (!mounted) return;

      setState(() {
        _isScanning = false;
        _resultsArray = [];
      });
    });

    // This is called after scanning has completed, either by detecting a barcode,
    // canceling the scan by using the on-screen button or a hardware trigger button, or if the scanning timed-out
    CmbsdkFlutter.setReadResultReceivedListener((resultJSON) {
      final Map<String, dynamic> resultMap = jsonDecode(resultJSON);
      final List<dynamic> resultsArray = resultMap['results'];

      if (!mounted) return;

      setState(() {
        _resultsArray = resultsArray;
      });
    });

    // It will return TRUE in the result if the scanning process is STARTED and false if it's STOPPED
    CmbsdkFlutter.setScanningStateChangedListener((scanningState) {
      if (!mounted) return;

      setState(() {
        _isScanning = scanningState;
        _scanButtonText = _isScanning ? 'STOP SCANNING' : 'START SCANNING';
      });
    });

    // Get cmbSDK version number
    cmbSDKVersion = await CmbsdkFlutter.sdkVersion;

    //initialize and connect to MX/Phone Camera here
    if (_usePreconfiguredDevice) {
      _createReaderDevice();
    } else {
      _selectDeviceFromPicker();
    }

    if (!mounted) return;

    setState(() {
      _cmbSDKVersion = cmbSDKVersion;
    });
  }

  // Update the UI of the app (scan button, connection state label) depending on the current connection state
  void _updateUIByConnectionState(CmbsdkConnectionState state) {
    String connectionStatusText = _connectionStatusText;
    Color connectionStatusBackground = _connectionStatusBackground;
    String scanButtonText = _scanButtonText;
    bool scanButtonEnabled = _scanButtonEnabled;

    if (state == CmbsdkConnectionState.Connected) {
      connectionStatusText = 'Connected';
      connectionStatusBackground = Colors.lightGreen;

      scanButtonText = 'START SCANNING';
      scanButtonEnabled = true;
    } else {
      connectionStatusText = 'Disconnected';
      connectionStatusBackground = Colors.redAccent;

      scanButtonText = '(NOT CONNECTED)';
      scanButtonEnabled = false;
    }

    if (!mounted) return;

    setState(() {
      _connectionStatusText = connectionStatusText;
      _connectionStatusBackground = connectionStatusBackground;

      _scanButtonText = scanButtonText;
      _scanButtonEnabled = scanButtonEnabled;
    });
  }

  //----------------------------------------------------------------------------
  // This is the pick list for choosing the type of reader connection
  //----------------------------------------------------------------------------
  Future<void> _selectDeviceFromPicker() async {
    int deviceType = _deviceType;
    int cameraMode = _cameraMode;

    switch (await showDialog<int>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: const Text('Select device'),
            children: <Widget>[
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, CmbsdkDeviceType.MXReader);
                },
                child: const Text('MX Scanner (MX-1xxx)'),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, CmbsdkDeviceType.Camera);
                },
                child: const Text('Phone Camera'),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, null);
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        })) {
      case CmbsdkDeviceType.MXReader:
        deviceType = CmbsdkDeviceType.MXReader;
        break;
      case CmbsdkDeviceType.Camera:
        deviceType = CmbsdkDeviceType.Camera;
        cameraMode = CmbsdkCameraMode.NoAimer;
        // ...
        break;
      default:
        // dialog dismissed
        break;
    }

    if (!mounted) return;

    setState(() {
      _deviceType = deviceType;
      _cameraMode = cameraMode;
    });

    _createReaderDevice();
  }

  // Create a reader using the selected option from "selectDeviceFromPicker"
  void _createReaderDevice() {
    CmbsdkFlutter.setCameraMode(_cameraMode);
    CmbsdkFlutter.setPreviewOptions(CmbsdkPrevewiOption.Defaults);

    CmbsdkFlutter.registerSDK("SDK_KEY");
    CmbsdkFlutter.loadScanner(_deviceType).then((value) {
      CmbsdkFlutter.connect().then((value) {
        _updateUIByConnectionState(CmbsdkConnectionState.Connected);
      }).catchError((error, stackTrace) {
        _updateUIByConnectionState(CmbsdkConnectionState.Disconnected);
      });
    });
  }

  //----------------------------------------------------------------------------
  // This is an example of configuring the device. In this sample application, we
  // configure the device every time the connection state changes to connected (see
  // the ConnectionStateChanged event), as this is the best
  // way to garentee it is setup the way we want it. Not only does this garentee
  // that the device is configured when we initially connect, but also covers the
  // case where an MX scanner has hibernated (and we're reconnecting)--unless
  // setting changes are explicitly saved to non-volatile memory, they can be lost
  // when the MX hibernates or reboots.
  //
  // These are just example settings; in your own application you will want to
  // consider which setting changes are optimal for your application. It is
  // important to note that the different supported devices have different, out
  // of the box defaults:
  //
  //    * MX-1xxx Mobile Terminals have the following symbologies enabled by default:
  //        - Data Matrix
  //        - UPC/EAN
  //        - Code 39
  //        - Code 93
  //        - Code 128
  //        - Interleaved 2 of 5
  //        - Codabar
  //    * MX-100 Barcode Scanner has the following symbologies enabled by default:
  //        - UPC/EAN
  //        - Code 39
  //        - Code 128
  //        - GS1 Databar
  //        - PDF417
  //        - QR Code
  //    * camera scanner has NO symbologies enabled by default
  //
  // For the best scanning performance, it is recommended to only have the barcode
  // symbologies enabled that your application actually needs to scan. If scanning
  // with an MX-1xxx, that may mean disabling some of the defaults (or enabling
  // symbologies that are off by default).
  //
  // Keep in mind that this sample application works with all three types of devices,
  // so in our example below we show explicitly enabling symbologies as well as
  // explicitly disabling symbologies (even if those symbologies may already be on/off
  // for the device being used).
  //
  // We also show how to send configuration commands that may be device type
  // specific--again, primarily for demonstration purposes.
  //----------------------------------------------------------------------------
  void _configureReaderDevice() {
    //----------------------------------------------
    // Explicitly enable the symbologies we need
    //----------------------------------------------
    CmbsdkFlutter.setSymbologyEnabled(CmbsdkSymbology.DataMatrix, true)
        .then((value) => print('DataMatrix enabled'))
        .catchError((error, stackTrace) =>
            print('DataMatrix NOT enabled. ${error.message}'));

    CmbsdkFlutter.setSymbologyEnabled(CmbsdkSymbology.C128, true)
        .catchError((error, stackTrace) => print('${error.message}'));
    CmbsdkFlutter.setSymbologyEnabled(CmbsdkSymbology.UpcEan, true)
        .catchError((error, stackTrace) => print('${error.message}'));

    //-------------------------------------------------------
    // Explicitly disable symbologies we know we don't need
    //-------------------------------------------------------
    CmbsdkFlutter.setSymbologyEnabled(CmbsdkSymbology.CodaBar, false)
        .then((value) => print('CodaBar disabled'))
        .catchError((error, stackTrace) =>
            print('CodaBar NOT disabled. ${error.message}'));

    CmbsdkFlutter.setSymbologyEnabled(CmbsdkSymbology.C93, false)
        .catchError((error, stackTrace) => print('${error.message}'));

    //---------------------------------------------------------------------------
    // Below are examples of sending DMCC commands and getting the response
    //---------------------------------------------------------------------------
    CmbsdkFlutter.sendCommand('GET DEVICE.TYPE')
        .then((value) => print('$value'))
        .catchError((error, stackTrace) => print('${error.message}'));

    CmbsdkFlutter.sendCommand('GET DEVICE.FIRMWARE-VER')
        .then((value) => print('$value'))
        .catchError((error, stackTrace) => print('${error.message}'));

    //---------------------------------------------------------------------------
    // We are going to explicitly turn off image results (although this is the
    // default). The reason is that enabling image results with an MX-1xxx
    // scanner is not recommended unless your application needs the scanned
    // image--otherwise scanning performance can be impacted.
    //---------------------------------------------------------------------------
    CmbsdkFlutter.enableImage(false)
        .catchError((error, stackTrace) => print('${error.message}'));
    CmbsdkFlutter.enableImageGraphics(false)
        .catchError((error, stackTrace) => print('${error.message}'));

    //---------------------------------------------------------------------------
    // Device specific configuration examples
    //---------------------------------------------------------------------------
    if (_deviceType == CmbsdkDeviceType.Camera) {
      //---------------------------------------------------------------------------
      // Phone/tablet
      //---------------------------------------------------------------------------

      // Set the SDK's decoding effort to level 3
      CmbsdkFlutter.sendCommand("SET DECODER.EFFORT 3")
          .catchError((error, stackTrace) => print('${error.message}'));
    } else if (_deviceType == CmbsdkDeviceType.MXReader) {
      //---------------------------------------------------------------------------
      // MX-1xxx
      //---------------------------------------------------------------------------

      //---------------------------------------------------------------------------
      // Save our configuration to non-volatile memory (on an MX-1xxx; for the
      // phone, this has no effect). However, if the MX hibernates or is
      // rebooted, our settings will be retained.
      //---------------------------------------------------------------------------
      CmbsdkFlutter.sendCommand("CONFIG.SAVE")
          .catchError((error, stackTrace) => print('${error.message}'));
    }
  }

  void _toggleScanner() {
    if (_isScanning) {
      CmbsdkFlutter.stopScanning()
          .catchError((error, stackTrace) => print('${error.message}'));
    } else {
      CmbsdkFlutter.startScanning()
          .catchError((error, stackTrace) => print('${error.message}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      backgroundColor: Color(0xff333333),
      appBar: AppBar(
        title: const Text('CMBCameraDemo'),
        actions: <Widget>[
          Padding(
              padding: const EdgeInsets.all(20.0),
              child: GestureDetector(
                onTap: () {
                  _selectDeviceFromPicker();
                },
                child: const Text('DEVICE'),
              )),
        ],
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Expanded(
                child: ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: _resultsArray.length,
                    itemBuilder: (BuildContext context, int index) {
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('${_resultsArray[index]['readString']}',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 18)),
                            Text('${_resultsArray[index]['symbologyString']}',
                                style: TextStyle(color: Colors.grey)),
                          ]);
                    },
                    separatorBuilder: (BuildContext context, int index) =>
                        const Divider(thickness: 1))),
            Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _scanButtonEnabled
                          ? () {
                              _toggleScanner();
                            }
                          : null,
                      child: Text(_scanButtonText),
                      style: ElevatedButton.styleFrom(
                          primary: Color(0xfffadb04),
                          onPrimary: Colors.black,
                          onSurface: Color(0xfffadb04)),
                    ))),
            Padding(
                padding: const EdgeInsets.all(5),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(_cmbSDKVersion,
                        style: TextStyle(
                          color: Colors.white,
                        )),
                    Container(
                      color: _connectionStatusBackground,
                      child: Padding(
                          padding: EdgeInsets.all(2),
                          child: Text(_connectionStatusText,
                              style: TextStyle(
                                color: Colors.white,
                              ))),
                    )
                  ],
                ))
          ],
        ),
      ),
    );
  }
}