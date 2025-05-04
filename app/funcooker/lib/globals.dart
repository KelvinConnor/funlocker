import 'package:logger/logger.dart';

///Global app logger
var logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0, // Number of method calls to be displayed
    errorMethodCount: 8, // Number of method calls if stacktrace is provided
    lineLength: 120, // Width of the output
    colors: true, // Colorful log messages
    printEmojis: true, // Print an emoji for each log message
    dateTimeFormat:
        DateTimeFormat.none, // Should each log print contain a timestamp
    noBoxingByDefault: true,
  ),
);

///Service UUID of the BLE device
const String kServiceUuid = "e2b3e883-bbb4-4402-bd39-7658ddd7f5af";

///Characteristic UUID of the BLE device
const String kRequestCharacteristicUuid =
    "3171f86b-c1fc-4893-a3db-98ae4c29df0c";

///Characteristic UUID of the BLE device
const String kStatusCharacteristicUuid = "4d0910dd-87dc-4a3c-a7f3-b3c8a49afdbc";
