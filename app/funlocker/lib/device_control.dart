import 'dart:async';
import 'dart:ui';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'passcode_screen.dart';

import 'globals.dart';

///simple enum to store the possible states of the device
///with a parsing factory to convert a device status string to a DeviceState
enum DeviceState {
  unknown,
  locked,
  unlocked,
  locking,
  unlocking,
  adjusting;

  factory DeviceState.fromDeviceStatus(String status) {
    switch (status) {
      case 'LOCKED':
        return DeviceState.locked;
      case 'UNLOCKED':
        return DeviceState.unlocked;
      case 'LOCKING':
        return DeviceState.locking;
      case 'UNLOCKING':
        return DeviceState.unlocking;
      case 'ADJUSTING':
        return DeviceState.adjusting;
      default:
        return DeviceState.unknown;
    }
  }
}

class DeviceControl extends StatefulWidget {
  const DeviceControl({super.key, required this.device, this.onBack});
  //This is the device to control
  final BluetoothDevice device;
  //Optional callback function to go back to list screen
  final VoidCallback? onBack;

  @override
  State<DeviceControl> createState() => _DeviceControlState();
}

class _DeviceControlState extends State<DeviceControl>
    with WidgetsBindingObserver {
  // Shortcuts to the desired theme colors
  late final Color _backgroundColor =
      NeumorphicTheme.of(context)?.current?.baseColor ?? Colors.white;
  late final Color _textColor =
      NeumorphicTheme.of(context)?.current?.defaultTextColor ?? Colors.black;

  late StreamSubscription<BluetoothConnectionState>
      _deviceConnectionStatusSubscription;

  BluetoothCharacteristic? _requestCharacteristic;
  BluetoothCharacteristic? _statusCharacteristic;

  // Status of the pyhisical device
  DeviceState _lastDeviceState = DeviceState.unknown;

  // Controls the rotation of the status icon
  bool _isCCW = false;

  // The following variables are used to control the passcode screen
  String _existingPin = '';
  String _newPin1 = '';
  String _newPin2 = '';

  // Stream that is used by the PasscodeScreen to provide feedback to the user.
  // Adding 'true' to this stream will clear the passcode screen
  // while 'false' will trigger the screen to provide 'bad passcode' animated feedback
  final StreamController<bool> _verificationNotifier =
      StreamController<bool>.broadcast();

  /// This function is called when the widget is first created. It sets up the
  /// various characteristics that will be used to control the device and data
  /// streams that will be used to receive status updates from the device.
  /// See the flutter_blue_plus documentation for more information
  Future<void> _findCharacteristics() async {
    List<BluetoothService> services = await widget.device.discoverServices();

    BluetoothService service = services
        .firstWhere((element) => element.serviceUuid == Guid(kServiceUuid));

    _requestCharacteristic = service.characteristics.firstWhere((element) =>
        element.characteristicUuid == Guid(kRequestCharacteristicUuid));
    logger.d(
        'RequestCharacteristic is now configured with ${_requestCharacteristic?.characteristicUuid}');
    _statusCharacteristic = service.characteristics.firstWhere((element) =>
        element.characteristicUuid == Guid(kStatusCharacteristicUuid));
    logger.d(
        'StatusCharacteristic is now configured with ${_statusCharacteristic?.characteristicUuid}');

    await _statusCharacteristic?.setNotifyValue(true);
    await _requestCharacteristic?.setNotifyValue(true);

    // Read the current status and request fields to prime the last values
    await _statusCharacteristic?.read();
    await _requestCharacteristic?.read();

    //Setup a stream listener to listen for status updates coming from the device
    final StreamSubscription? deviceStatusSubscription =
        _statusCharacteristic?.lastValueStream.listen((value) {
      final statusUpdate = String.fromCharCodes(value);
      logger.d('⬅️ DEVICE STATUS UPDATE: $statusUpdate');
      _lastDeviceState = DeviceState.fromDeviceStatus(statusUpdate);
      if (mounted) {
        // if the screen is built then update the UI
        setState(() {});
      }
    });
    //tidy up on dispose
    if (deviceStatusSubscription != null) {
      widget.device.cancelWhenDisconnected(deviceStatusSubscription);
    }

    if (mounted) {
      // if the screen is built then update the UI
      setState(() {});
    }
  }

  // --------- BEGIN: Functions to send requests to the device --------------
  Future<void> _sendUnlockRequest(String pin) async {
    if (_requestCharacteristic != null) {
      _isCCW = true; // used by the status icon to show the correct rotation
      logger.d('➡️ DEVICE UNLOCK REQUEST');
      await _requestCharacteristic!.write('$pin-UNLOCK'.codeUnits);
      var response = await _requestCharacteristic!.read();
      if (response.isEmpty) {
        logger.d('⬅️ DEVICE UNLOCK RESPONSE: EMPTY?');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bad response from device'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        _verificationNotifier.add(true);
        return;
      }
      var responseString = String.fromCharCodes(response);
      logger.d('⬅️ DEVICE UNLOCK RESPONSE: $responseString');
      if (responseString == 'READY') {
        logger.d('PIN SUCCESS');
        _verificationNotifier.add(true);
      } else {
        logger.d('PIN REJECTED');
        _verificationNotifier.add(false);
      }
    }
  }

  Future<void> _sendCWAdjustmentRequest(String pin) async {
    if (_requestCharacteristic != null) {
      _isCCW = false; // used by the status icon to show the correct rotation
      logger.d('➡️ DEVICE CW ADJUSTMENT REQUEST');
      await _requestCharacteristic!.write('$pin-CW'.codeUnits);
      var response = await _requestCharacteristic!.read();
      if (response.isEmpty) {
        logger.d('⬅️ DEVICE CW ADJUSTMENT RESPONSE: EMPTY?');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bad response from device'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        _verificationNotifier.add(true);
        return;
      }
      var responseString = String.fromCharCodes(response);
      logger.d('⬅️ DEVICE CW ADJUSTMENT RESPONSE: $responseString');
      if (responseString == 'READY') {
        logger.d('PIN SUCCESS');
        _verificationNotifier.add(true);
      } else {
        logger.d('PIN REJECTED');
        _verificationNotifier.add(false);
      }
    }
  }

  Future<void> _sendCCWAdjustmentRequest(String pin) async {
    if (_requestCharacteristic != null) {
      _isCCW = true; // used by the status icon to show the correct rotation
      logger.d('➡️ DEVICE CCW ADJUSTMENT REQUEST');
      await _requestCharacteristic!.write('$pin-CCW'.codeUnits);
      var response = await _requestCharacteristic!.read();
      if (response.isEmpty) {
        logger.d('⬅️ DEVICE CCW ADJUSTMENT RESPONSE: EMPTY?');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bad response from device'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        _verificationNotifier.add(true);
        return;
      }
      var responseString = String.fromCharCodes(response);
      logger.d('⬅️ DEVICE CCW ADJUSTMENT RESPONSE: $responseString');
      if (responseString == 'READY') {
        logger.d('PIN SUCCESS');
        _verificationNotifier.add(true);
      } else {
        logger.d('PIN REJECTED');
        _verificationNotifier.add(false);
      }
    }
  }

  Future<void> _sendFlipRequest(String pin) async {
    if (_requestCharacteristic != null) {
      logger.d('➡️ DEVICE FLIP REQUEST');
      await _requestCharacteristic!.write('$pin-FLIP'.codeUnits);
      var response = await _requestCharacteristic!.read();
      if (response.isEmpty) {
        logger.d('⬅️ DEVICE FLIP RESPONSE: EMPTY?');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bad response from device'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        _verificationNotifier.add(true);
        return;
      }
      var responseString = String.fromCharCodes(response);
      logger.d('⬅️ DEVICE FLIP RESPONSE: $responseString');
      if (responseString == 'READY') {
        logger.d('PIN SUCCESS');
        _verificationNotifier.add(true);
      } else {
        logger.d('PIN REJECTED');
        _verificationNotifier.add(false);
      }
    }
  }

  Future<void> _sendPINChangeRequest(String currentPin, String newPin) async {
    if (_requestCharacteristic != null) {
      logger.d('➡️ DEVICE PIN CHANGE REQUEST');
      await _requestCharacteristic!
          .write('$currentPin-NEWPIN-$newPin'.codeUnits);
      var response = await _requestCharacteristic!.read();
      if (response.isEmpty) {
        logger.d('⬅️ DEVICE PIN CHANGE RESPONSE: EMPTY?');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bad response from device'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        _verificationNotifier.add(true);
        return;
      }
      var responseString = String.fromCharCodes(response);
      logger.d('⬅️ DEVICE PIN CHANGE RESPONSE: $responseString');
      if (responseString == 'READY') {
        logger.d('PIN SUCCESS');
        _verificationNotifier.add(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN changed successfully'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        logger.d('PIN REJECTED');
        _verificationNotifier.add(false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN change failed'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _sendLockRequest() async {
    if (_requestCharacteristic != null) {
      _isCCW = false; // used by the status icon to show the correct rotation
      logger.d('➡️ DEVICE LOCK REQUEST');
      await _requestCharacteristic!.write('LOCK'.codeUnits);
    }
  }

  Future<void> _sendNameChangeRequest(String newName) async {
    if (_requestCharacteristic != null && newName.isNotEmpty) {
      logger.d('➡️ NAME CHANGE REQUEST');
      await _requestCharacteristic!.write('NAME-$newName'.codeUnits);
      var response = await _requestCharacteristic!.read();
      if (response.isEmpty) {
        logger.d('⬅️ NAME CHANGE RESPONSE: EMPTY?');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bad response from device'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      var responseString = String.fromCharCodes(response);
      logger.d('⬅️ NAME CHANGE RESPONSE: $responseString');
      if (responseString == 'READY') {
        logger.d('NAME CHANGE SUCCESS');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Name changed successfully - reboot required'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _sendRotationChangeRequest(int newRotation) async {
    if (_requestCharacteristic != null && newRotation > 1) {
      logger.d('➡️ ROTATION CHANGE REQUEST');
      await _requestCharacteristic!.write('ROTATION-$newRotation'.codeUnits);
      var response = await _requestCharacteristic!.read();
      if (response.isEmpty) {
        logger.d('⬅️ ROTATION CHANGE RESPONSE: EMPTY?');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bad response from device'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      var responseString = String.fromCharCodes(response);
      logger.d('⬅️ ROTATION CHANGE RESPONSE: $responseString');
      if (responseString == 'READY') {
        logger.d('ROTATION CHANGE SUCCESS');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rotation changed successfully'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  // --------- END: Functions to send requests to the device --------------

  /// Displays a pin entry dialog to the user.
  ///
  /// This function shows a PasscodeScreen dialog that requires the user to
  /// enter a 4-digit pin. The appearance of the dialog is customized with
  /// colors and styles based on the current theme. The dialog slides in
  /// from the top of the screen and does not allow dismissal by tapping
  /// outside it.
  ///
  /// The [cmd] function is called with the entered pin as an argument when
  /// the user submits the pin. The function is responsible for handling the
  /// pin validation and sending feedback to the PasscodeScreen's verification
  /// stream on whether the pin is correct or not.
  Future<void> _promptForPin(Function cmd) async {
    // Show the PasscodeScreen fullscreen with an animated slide transition
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 500),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // This just slides the dialog in from the top
        const begin = Offset(0.0, -1.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        final tween = Tween(begin: begin, end: end);
        final curvedAnimation =
            CurvedAnimation(parent: animation, curve: curve);
        return SlideTransition(
          position: tween.animate(curvedAnimation),
          child: child,
        );
      },
      pageBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation) =>
          PasscodeScreen(
        backgroundColor: _backgroundColor,
        keyboardUIConfig: KeyboardUIConfig(
          primaryColor: _textColor,
          digitTextStyle: TextStyle(fontSize: 30, color: _textColor),
        ),
        circleUIConfig:
            CircleUIConfig(borderColor: _textColor, fillColor: _textColor),
        passwordDigits: 4,
        title: Text(
          'Pin Required',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(color: _textColor),
        ),
        cancelButton: Text(
          'Cancel',
          style: TextStyle(fontSize: 22, color: _textColor),
        ),
        deleteButton: Text(
          'Delete',
          style: TextStyle(fontSize: 22, color: _textColor),
        ),
        passwordEnteredCallback: (pin) async {
          // Call the passed in function with the entered pin
          // as an argument. The function will then decide what to do and
          // determine if the pin is correct or not. The function will send
          // updates to the PasscodeScreen's verification stream
          cmd(pin);
        },
        cancelCallback: () => Navigator.pop(context),
        shouldTriggerVerification: _verificationNotifier.stream,
        isValidCallback: () {
          // Not needed
        },
      ),
    );
  }

  /// Displays a PIN change dialog to the user.
  ///
  /// This function shows a PasscodeScreen dialog that requires the user to
  /// enter their existing PIN, a new PIN, and then the new PIN again to
  /// confirm. The appearance of the dialog is customized with colors and
  /// styles based on the current theme. The dialog slides in from the top of
  /// the screen and does not allow dismissal by tapping outside it.
  ///
  /// If the user enters a valid PIN, the function will send a request to the
  /// device to change the PIN. The result of the PIN change request is
  /// displayed to the user in a SnackBar.
  Future<void> _promptForPINChange() async {
    // Clear any existing PIN change state
    _existingPin = '';
    _newPin1 = '';
    _newPin2 = '';
    // Show the PasscodeScreen fullscreen with an animated slide transition
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 500),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // This just slides the dialog in from the top
        const begin = Offset(0.0, -1.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        final tween = Tween(begin: begin, end: end);
        final curvedAnimation =
            CurvedAnimation(parent: animation, curve: curve);
        return SlideTransition(
          position: tween.animate(curvedAnimation),
          child: child,
        );
      },
      pageBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) {
        // The STATEFULBUILDER allows the passcode screen to be rebuilt whenever
        // the provided state changes. In this case, the state changes
        // whenever the existingPin, newPin1, or newPin2 variables change so
        // that the screen can be rebuilt with the updated state (thereby
        // switching beween "Enter Current Pin", "Enter New Pin", and "Re-enter Pin").
        return StatefulBuilder(builder: (context, setState) {
          return PasscodeScreen(
            key: UniqueKey(),
            backgroundColor: _backgroundColor,
            keyboardUIConfig: KeyboardUIConfig(
              primaryColor: _textColor,
              digitTextStyle: TextStyle(fontSize: 30, color: _textColor),
            ),
            circleUIConfig:
                CircleUIConfig(borderColor: _textColor, fillColor: _textColor),
            passwordDigits: 4,
            title: _getPINChangeTitle(),
            cancelButton: Text(
              'Cancel',
              style: TextStyle(fontSize: 22, color: _textColor),
            ),
            deleteButton: Text(
              'Delete',
              style: TextStyle(fontSize: 22, color: _textColor),
            ),
            passwordEnteredCallback: (pin) async {
              //delay to allow for the last passcode circle to animate
              await Future.delayed(const Duration(milliseconds: 200));
              if (_existingPin.isEmpty &&
                  _newPin1.isEmpty &&
                  _newPin2.isEmpty) {
                _existingPin = pin;
                logger.d("Existing PIN entered $pin");
              } else if (_existingPin.isNotEmpty &&
                  _newPin1.isEmpty &&
                  _newPin2.isEmpty) {
                _newPin1 = pin;
                logger.d("New PIN 1 entered $pin");
              } else if (_existingPin.isNotEmpty &&
                  _newPin1.isNotEmpty &&
                  _newPin2.isEmpty) {
                _newPin2 = pin;
                logger.d("New PIN 2 entered $pin");
                if (_newPin1 != _newPin2) {
                  logger.d('New passwords didn\'t match');
                  _newPin1 = '';
                  _newPin2 = '';
                  _verificationNotifier.add(false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('New pins do not match'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                } else {
                  logger.d("Changing PIN");
                  _sendPINChangeRequest(_existingPin, pin);
                }
              }

              setState(() {});
            },
            cancelCallback: () => Navigator.pop(context),
            shouldTriggerVerification: _verificationNotifier.stream,
            isValidCallback: () {
              // Not needed
            },
          );
        });
      },
    ).then(
      (_) {
        // Clear any existing PIN change state - just in case
        _existingPin = '';
        _newPin1 = '';
        _newPin2 = '';
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _findCharacteristics();

    // Register for device connection state changes
    _deviceConnectionStatusSubscription = widget.device.connectionState.listen(
      (connectionState) {
        if (connectionState == BluetoothConnectionState.disconnected &&
            context.mounted) {
          logger.d(
              'DEVICE DISCONNECTED - KICKING THE USER BACK TO THE SCANNING SCREEN');
          widget.onBack?.call();
        }
      },
    );

    // Register for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App is back in the foreground
      logger.d('APP IS RESUMED');
      //This should update the device status if it has changed
      _requestCharacteristic?.read();
    } else if (state == AppLifecycleState.paused) {
      // App is in the background
      logger.d('APP IS PAUSED');
      // Perform actions when paused
    }
  }

  @override
  void dispose() {
    // Close the passcode verification
    // and cancel the device connection status stream (tidy up)
    _verificationNotifier.close();
    _deviceConnectionStatusSubscription.cancel();

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Builds the UI for the device control screen, which includes buttons for
  // locking, unlocking, adjusting, and flipping the device, as well as changing
  // the PIN
  @override
  Widget build(BuildContext context) {
    return (_requestCharacteristic == null && _statusCharacteristic == null)
        ? Center(
            child: Transform.scale(
              scale: 2,
              child: CircularProgressIndicator.adaptive(),
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  flex: 4,
                  child: SizedBox(
                    width: double.infinity,
                    // Wrap ensures that the buttons are evenly distributed
                    // across the screen regardless of screen size
                    child: Wrap(
                      // This is the unlock and lock buttons
                      alignment: WrapAlignment.spaceEvenly,
                      runAlignment: WrapAlignment.spaceEvenly,
                      children: [
                        FittedBox(
                          fit: BoxFit.cover,
                          // This is the unlock button
                          child: NeumorphicButton(
                            style: NeumorphicStyle(
                              shape: (_lastDeviceState != DeviceState.locked)
                                  ? NeumorphicShape.flat
                                  : NeumorphicShape.convex,
                              boxShape: NeumorphicBoxShape.circle(),
                            ),
                            onPressed: (_lastDeviceState != DeviceState.locked)
                                ? null
                                : () => _promptForPin(_sendUnlockRequest),
                            child: const Icon(
                              Icons.lock_open,
                              size: 70.0,
                            ),
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.cover,
                          child: NeumorphicButton(
                            style: NeumorphicStyle(
                              shape: (_lastDeviceState != DeviceState.unlocked)
                                  ? NeumorphicShape.flat
                                  : NeumorphicShape.convex,
                              boxShape: NeumorphicBoxShape.circle(),
                            ),
                            onPressed:
                                (_lastDeviceState != DeviceState.unlocked)
                                    ? null
                                    : () => _sendLockRequest(),
                            child: const Icon(
                              Icons.lock,
                              size: 70.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  // This is the animated status indicator
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: Neumorphic(
                        padding: const EdgeInsets.all(10.0),
                        style: const NeumorphicStyle(
                            boxShape: NeumorphicBoxShape.circle(),
                            shape: NeumorphicShape.concave,
                            depth: -1),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: _getStatusWidget(),
                        ),
                      ),
                    ),
                  ),
                ),
                Flexible(
                  flex: 2,
                  child: SizedBox(
                    width: double.infinity,
                    // Wrap ensures that the buttons are evenly distributed
                    // across the screen regardless of screen size
                    child: Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      runAlignment: WrapAlignment.spaceAround,
                      runSpacing: 10.0,
                      children: [
                        // TODO
                        // The device supports changing name and rotation
                        // but this is an optional feature. You are welcome to add a
                        // full UI to support this if you want ;)
                        /* NeumorphicButton(
                          style: const NeumorphicStyle(
                            shape: NeumorphicShape.convex,
                            boxShape: NeumorphicBoxShape.circle(),
                          ),
                          onPressed: () async {
                            await _sendNameChangeRequest(
                                "Funlocker Test Device");
                            await _sendRotationChangeRequest(11);
                          },
                          child: Icon(Icons.edit),
                        ),
                        */

                        // I find the back 'to list' button is optional but
                        // useful for testing with multiple devices
                        if (widget.onBack != null)
                          NeumorphicButton(
                            style: const NeumorphicStyle(
                              shape: NeumorphicShape.convex,
                              boxShape: NeumorphicBoxShape.circle(),
                            ),
                            onPressed: () {
                              widget.device.disconnect();
                              widget.onBack!();
                            },
                            child: Icon(Icons.bluetooth_searching),
                          ),
                        // Change PIN button
                        NeumorphicButton(
                          style: const NeumorphicStyle(
                            shape: NeumorphicShape.convex,
                            boxShape: NeumorphicBoxShape.circle(),
                          ),
                          onPressed: (_lastDeviceState == DeviceState.locked ||
                                  _lastDeviceState == DeviceState.unlocked)
                              ? () {
                                  _promptForPINChange();
                                }
                              : null,
                          child: const Icon(Icons.password),
                        ),
                        // Adjust button - clockwise
                        // used to make minor adjustments to the lock position
                        NeumorphicButton(
                          style: const NeumorphicStyle(
                            shape: NeumorphicShape.convex,
                            boxShape: NeumorphicBoxShape.circle(),
                          ),
                          onPressed: (_lastDeviceState == DeviceState.locked ||
                                  _lastDeviceState == DeviceState.unlocked)
                              ? () => _promptForPin(_sendCWAdjustmentRequest)
                              : null,
                          child: const Icon(Icons.rotate_right),
                        ),
                        // Adjust button - counter clockwise
                        // used to make minor adjustments to the lock position
                        NeumorphicButton(
                          style: const NeumorphicStyle(
                            shape: NeumorphicShape.convex,
                            boxShape: NeumorphicBoxShape.circle(),
                          ),
                          onPressed: (_lastDeviceState == DeviceState.locked ||
                                  _lastDeviceState == DeviceState.unlocked)
                              ? () => _promptForPin(_sendCCWAdjustmentRequest)
                              : null,
                          child: const Icon(Icons.rotate_left),
                        ),
                        // Flip the lock state button
                        // Manually makes the lock either locked or unlocked
                        // useful for testing or after a power cycle
                        NeumorphicButton(
                          style: const NeumorphicStyle(
                            shape: NeumorphicShape.convex,
                            boxShape: NeumorphicBoxShape.circle(),
                          ),
                          onPressed: (_lastDeviceState == DeviceState.locked ||
                                  _lastDeviceState == DeviceState.unlocked)
                              ? () => _promptForPin(_sendFlipRequest)
                              : null,
                          child: const Icon(Icons.sync_lock),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
  }

  // UI helper method - returned the correct status icon
  // for the current device state.
  // Icons use the Animate package to rotate and jiggle
  Widget _getStatusWidget() {
    Widget statusWidget = const Icon(
      key: ValueKey('UNKNOWN'),
      Icons.question_mark,
    );

    if (_lastDeviceState == DeviceState.locking ||
        _lastDeviceState == DeviceState.unlocking ||
        _lastDeviceState == DeviceState.adjusting) {
      statusWidget = Stack(
        key: UniqueKey(),
        children: [
          Positioned(
            top: .5,
            left: .5,
            child: Padding(
              padding: const EdgeInsets.all(0.0),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
                child: Icon(
                  Icons.settings,
                  key: const ValueKey('MOVING_SHADOW'),
                  color: Colors.black54,
                )
                    .animate(delay: const Duration(milliseconds: 1000))
                    .animate(onPlay: (controller) => controller.repeat())
                    .rotate(
                      begin: _isCCW ? 1 : 0,
                      end: _isCCW ? 0 : 1,
                      duration: const Duration(seconds: 2),
                    ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(0.0),
            child: Icon(
              Icons.settings,
              key: const ValueKey('MOVING_ICON'),
              //color: Colors.amber,
            )
                .animate(delay: const Duration(milliseconds: 1000))
                .animate(onPlay: (controller) => controller.repeat())
                .rotate(
                  begin: _isCCW ? 1 : 0,
                  end: _isCCW ? 0 : 1,
                  duration: const Duration(seconds: 2),
                ),
          ),
        ],
      );
    } else if (_lastDeviceState == DeviceState.locked) {
      statusWidget = NeumorphicIcon(
        Icons.lock,
        key: const ValueKey('LOCKED'),
        style: const NeumorphicStyle(
          depth: 1,
          color: Colors.black,
        ),
      )
          .animate(delay: const Duration(milliseconds: 1000))
          .shimmer(delay: 1000.ms, duration: 1800.ms) // shimmer +
          .shake(hz: 4, curve: Curves.easeInOutCubic) // shake +
          .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.2, 1.2),
              duration: 600.ms) // scale up
          .then(delay: 600.ms) // then wait and
          .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1 / 1.2, 1 / 1.2));
    } else if (_lastDeviceState == DeviceState.unlocked) {
      statusWidget = NeumorphicIcon(
        Icons.lock_open,
        key: const ValueKey('UNLOCKED'),
        //size: 48,
        style: const NeumorphicStyle(
          depth: 1,
          color: Colors.black,
        ),
      )
          .animate(delay: const Duration(milliseconds: 1000))
          .shimmer(delay: 1000.ms, duration: 1800.ms) // shimmer +
          .shake(hz: 4, curve: Curves.easeInOutCubic) // shake +
          .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.2, 1.2),
              duration: 600.ms) // scale up
          .then(delay: 600.ms) // then wait and
          .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1 / 1.2,
                  1 / 1.2)); // .scale(delay: const Duration(milliseconds: 1000), );
    }
    return statusWidget;
  }

  Text _getPINChangeTitle() {
    var title = "Enter Current Pin";
    if (_existingPin.isNotEmpty && _newPin1.isEmpty && _newPin2.isEmpty) {
      title = "Enter New Pin";
    } else if (_existingPin.isNotEmpty &&
        _newPin1.isNotEmpty &&
        _newPin2.isEmpty) {
      title = "Re-enter Pin";
    }
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .headlineSmall
          ?.copyWith(color: _textColor),
    );
  }
}
