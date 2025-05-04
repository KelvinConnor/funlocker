import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:funlocker/device_scanner.dart';

/// This is the initial screen that appears when the app is first run
/// It acts a wrapper for the rest of the app (device scanner and device control),
/// showing a warning if bluetooth is off. It is the only 'scaffold'ed widget'
/// in the app and is the root screen. If bluetooth becomes unavailable, the app
/// switches back to this view.
class ViewDevicesScreen extends StatefulWidget {
  const ViewDevicesScreen({super.key});

  @override
  State<ViewDevicesScreen> createState() => _ViewDevicesScreenState();
}

class _ViewDevicesScreenState extends State<ViewDevicesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder(
          stream: FlutterBluePlus.adapterState,
          initialData: BluetoothAdapterState.unknown,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              if (snapshot.data == BluetoothAdapterState.on) {
                //Bluetooth is on and available so show the device scanner
                return const DeviceScanner();
              } else if (snapshot.data == BluetoothAdapterState.off) {
                return _getBluetoothOffWarning();
              } else if (snapshot.data == BluetoothAdapterState.unauthorized) {
                return const Center(
                  child: Text('Bluetooth Unauthorized'),
                );
              } else if (snapshot.data == BluetoothAdapterState.unavailable) {
                return const Center(
                  child: Text('Bluetooth Unavailable'),
                );
              } else {
                return const Center(
                  child: Text('Checking connection...'),
                );
              }
            } else {
              return const Center(
                child: Text('Checking connection...'),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _getBluetoothOffWarning() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            NeumorphicIcon(
              Icons.bluetooth,
              size: 50.0,
              style: const NeumorphicStyle(color: Colors.black),
            ),
            Text(
              'Bluetooth not available',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'Have you tried turning it off and back on again?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}
