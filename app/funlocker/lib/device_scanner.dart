import 'dart:async';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:funlocker/device_control.dart';
import 'package:funlocker/globals.dart';

class DeviceScanner extends StatefulWidget {
  const DeviceScanner({super.key});

  @override
  State<DeviceScanner> createState() => _DeviceScannerState();
}

class _DeviceScannerState extends State<DeviceScanner> {
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;
  bool _isScanning = false;
  List<ScanResult>? _scanResults;

  int _selectedDeviceIndex = -1;

  BluetoothDevice? _selectedDevice;

  @override
  void initState() {
    super.initState();

    // Setup a Stream Listener to update the scan results when they change, this
    // will basically do its thing in the background while the app is running
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      logger.d('Scan results updated w/ ${results.length} results');

      //Update scan results
      _scanResults = results;
      if (mounted) {
        setState(() {});
      }
    }, onError: (e) {
      logger.e('Scan error', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unexpected scan error'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    // Setup a Stream Listener to update the scanning state (is scanning or not)
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      if (state) {
        logger.d('Scanning for devices');
      } else {
        logger.d('Stopped scanning for devices');
      }

      //Update scanning state
      _isScanning = state;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    //Cancel all subscriptions (tidy up)
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            //Adding a max width to limit the width of the list to make it
            //easier to read on larger screens
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              // If a device is selected and connected, show the device control screen
              // otherwise show the scan results
              child: (_selectedDevice != null &&
                      (_selectedDevice?.isConnected ?? false))
                  ? DeviceControl(
                      device: _selectedDevice!,
                      onBack: () => setState(() => _selectedDevice = null),
                    ).animate().slideY()
                  : _buildScanResults(),
            ),
          ),
        ],
      ),
    );
  }

  /// UI Helper method to build the UI for scanning for devices
  Widget _buildScanResults() {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 20),
        NeumorphicButton(
          onPressed: _isScanning
              ? () {
                  logger.d('Stopping scan');
                  FlutterBluePlus.stopScan().then((value) => setState(() {}));
                }
              : () {
                  logger.d('Scanning for devices');
                  FlutterBluePlus.startScan(
                          //fake guid for testing (no results are returned)
                          //withServices: [Guid('3d5c4743-fc80-435e-972b-18647b083515')],
                          withServices: [Guid(kServiceUuid)],
                          timeout: const Duration(seconds: 5))
                      .then((value) => setState(() {}));
                },
          child: _isScanning
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bluetooth_searching),
                    const SizedBox(width: 10),
                    const Text('Stop searching'),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bluetooth),
                    const SizedBox(width: 10),
                    const Text('Search for devices'),
                  ],
                ),
        ),
        Expanded(
          child: _isScanning
              ? Center(
                  child: Transform.scale(
                    scale: 2.0,
                    child: CircularProgressIndicator.adaptive(),
                  ),
                )
              : Center(
                  child: _buildDeviceList(),
                ),
        ),
      ],
    );
  }

  ///UI Helper method to build a list of available devices, tapping on a device
  ///will take the user to the device control screen
  Widget _buildDeviceList() {
    if (_scanResults == null) {
      return Center(
        child: Text('Start scanning for devices',
            style: Theme.of(context).textTheme.headlineSmall),
      );
    }
    if ((_scanResults ?? []).isEmpty) {
      return Center(
        child: Text('No devices found',
            style: Theme.of(context).textTheme.headlineSmall),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: (_scanResults ?? []).length,
      itemBuilder: (context, index) {
        var result = _scanResults![index];
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Neumorphic(
            style: NeumorphicStyle(
              shape: NeumorphicShape.convex,
              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
              depth: (index == _selectedDeviceIndex) ? 2 : -1,
            ),
            child: MouseRegion(
              onEnter: (event) => setState(() {
                _selectedDeviceIndex = index;
              }),
              onExit: (event) => setState(() {
                _selectedDeviceIndex = -1;
              }),
              child: InkWell(
                onTap: () {
                  logger.d('Connecting to ${result.device.platformName}');
                  result.device.connect().then(
                    (value) {
                      if (context.mounted && result.device.isConnected) {
                        logger.d('Connected to ${result.device.platformName}');
                        // Updates the selected device varible and refreshes the UI.
                        // This will take the user to the device control screen
                        _selectedDevice = result.device;
                        setState(() {});
                        // Alternatively you could set up a stream listener to listen
                        // for connection updates from the device via connectionState
                        // stream to automatically update the UI and show the device
                        // control screen (or back to the device scanner)
                      }
                    },
                  ).catchError((e) {
                    logger.e('Connection error', error: e);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Unexpected connection error'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  });
                },
                child: Ink(
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      result.device.platformName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
