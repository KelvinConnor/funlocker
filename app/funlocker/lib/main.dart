import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:funlocker/view_devices_screen.dart';

void main() {
  //Change log level to only show warnings
  FlutterBluePlus.setLogLevel(LogLevel.warning, color: false);
  runApp(const FunlockerApp());
}

class FunlockerApp extends StatelessWidget {
  const FunlockerApp({super.key});

  // The app uses the Neumorphic UI widgets and theme provided by Flutter Neumorphic Plus
  // https://pub.dev/packages/flutter_neumorphic_plus
  // You can change to more standard Material or Cupertino widgets if you like but
  // you will need to manually change the components out in code.
  @override
  Widget build(BuildContext context) {
    return const NeumorphicApp(
      title: 'Funlocker',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: NeumorphicThemeData(
        baseColor: Color(0xFFFFFFFF),
        lightSource: LightSource.topLeft,
        depth: 4,
      ),
      home: ViewDevicesScreen(), //Initial screen
    );
  }
}
