/*
 * Simple prototype BLE enabled 'smart lock' Arduino code
 * For demo/education purposes only - useful for other BLE
 * use cases
 *
 * @author K Connor (kconnor@unifiedcore.com)
 * @date 2024-05-15
 *
 * For more details see README
 *
 * SPDX-License-Identifier: MIT
 */

// #include <SPI.h>
#include <Arduino.h>
#include <Stepper.h>
#include <Preferences.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>

// Custom UUID's to define BLE Characteristics
// Any clients need these
#define SERVICE_UUID "e2b3e883-bbb4-4402-bd39-7658ddd7f5af"
#define REQUEST_CHARACTERISTIC_UUID "3171f86b-c1fc-4893-a3db-98ae4c29df0c"
#define STATUS_CHARACTERISTIC_UUID "4d0910dd-87dc-4a3c-a7f3-b3c8a49afdbc"

#define BUZZER_PIN 8

// ULN2003 Motor Driver Pins
#define IN1 0
#define IN2 1
#define IN3 2
#define IN4 3
const int stepsPerRevolution = 2048;

// initialize the stepper library
Stepper myStepper(stepsPerRevolution, IN1, IN3, IN2, IN4);

// Use the ESP/Ardunio Preferences library for local storage
Preferences preferences;

// program vars. Used to control the state/actions of the device

bool isLocked = false;

bool unlockRequested = false;
bool lockRequested = false;
bool cwAdjustmentRequested = false;
bool ccwAdjustmentRequested = false;

// This is the # of rotations required to lock or unlock.
// It may need to be changed based on the locking device.
int rotations = 11;

// Default/Initial PIN code
String currentPin = "1111";

// Default/Initial Device Name
String deviceName = "Funlocker";

// The two key BLE Characteristics
// Request: Inbound Action Requests (from client) and ACKs/ERROR Responses
// Status: Outbound Only Device Status ('locking', 'locked', 'unlocking', ...)
BLECharacteristic *pRequestCharacteristic;
BLECharacteristic *pStatusCharacteristic;

// Turns off the power to the Servo - prevents noise/saves power?
void powerOffServo()
{
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, LOW);
}

// Save the unlock/lock status to the device's internal storage
// Helps in case of power outages
void updateStoredStatus()
{
  preferences.begin("funlocker", false);
  Serial.print("UPDATING PREF STATUS TO ");
  preferences.putBool("locked", isLocked);
  Serial.println(isLocked ? "LOCKED" : "UNLOCKED");
  preferences.end();
}

// Updates the Request Characteristic (mostly used for ACKS/ERRORS)
void updateRequestCharacteristic(String response)
{
  pRequestCharacteristic->setValue(response.c_str());
  pRequestCharacteristic->notify();
}

// Updates the Status Characteristic ('locking', 'locked', 'unlocking', ...)
void updateStatusCharacteristic(String status)
{
  pStatusCharacteristic->setValue(status.c_str());
  pStatusCharacteristic->notify();
}

// 'Registered' BLE callbacks - think of this like the BLE event handlers
class BTServerCallbacks : public BLEServerCallbacks
{
  void onConnect(BLEServer *pServer)
  {
    updateRequestCharacteristic("READY");
  };

  void onDisconnect(BLEServer *pServer)
  {
    pServer->startAdvertising(); // restart advertising
  }
};

// These callbacks are attached to the Request Characteristics in setup()
class BTCallbacks : public BLECharacteristicCallbacks
{
  // A client updated the Request Characteristics with a 'command'
  // so compare it to the list of valid commands (string compares).
  // If valid then set the appropriate state variables OR
  // for updates, write the changes to the Preferences
  void onWrite(BLECharacteristic *pCharacteristic)
  {
    std::string value = pCharacteristic->getValue();

    String openCommand = currentPin + "-UNLOCK";
    String newPinCommand = currentPin + "-NEWPIN-";
    String cwCommand = currentPin + "-CW";
    String ccwCommand = currentPin + "-CCW";
    String flipStatusCommand = currentPin + "-FLIP";

    if (value.length() > 0)
    {
      Serial.println("*********");
      Serial.print("NEW COMMAND: ");
      Serial.println(value.c_str());
      Serial.println("*********");

      if (strcmp(value.c_str(), "LOCK") == 0)
      {
        Serial.println("LOCK REQUESTED");
        lockRequested = true;
        updateRequestCharacteristic("READY");
      }
      else if (strcmp(value.c_str(), openCommand.c_str()) == 0)
      {
        Serial.println("VALID PIN: UNLOCK REQUESTED");
        unlockRequested = true;
        updateRequestCharacteristic("READY");
      }
      else if (strcmp(value.c_str(), cwCommand.c_str()) == 0)
      {
        Serial.println("VALID PIN: CW ADJUSTMENT REQUESTED");
        cwAdjustmentRequested = true;
        updateRequestCharacteristic("READY");
      }
      else if (strcmp(value.c_str(), ccwCommand.c_str()) == 0)
      {
        Serial.println("VALID PIN: CCW ADJUSTMENT REQUESTED");
        ccwAdjustmentRequested = true;
        updateRequestCharacteristic("READY");
      }
      else if (strcmp(value.c_str(), flipStatusCommand.c_str()) == 0)
      {
        Serial.println("VALID PIN: FLIP STATUS REQUESTED");
        isLocked = !isLocked;
        if (isLocked)
        {
          updateStatusCharacteristic("LOCKED");
        }
        else
        {
          updateStatusCharacteristic("UNLOCKED");
        }

        updateRequestCharacteristic("READY");

        updateStoredStatus();
      }
      else if (strncmp(value.c_str(), newPinCommand.c_str(), 12) == 0)
      {
        Serial.println("VALID PIN: PIN CHANGE");
        char temp[5];
        strncpy(temp, &value[12], 4); // Only grab 4 chars
        temp[5] = '\0';
        Serial.print("NEW PIN = ");
        Serial.println(temp);
        preferences.begin("funcooker", false);
        preferences.putString("pin", temp);
        preferences.end();
        currentPin = temp;
        updateRequestCharacteristic("READY");
      }
      // Compare the incoming value to see if it begins with "ROTATION-" and if so
      // extract and convert the remaining string as an integer
      else if (strncmp(value.c_str(), "ROTATION-", 9) == 0)
      {
        Serial.println("ROTATION CHANGE REQUESTED");
        // Extract the number part after "ROTATION-"
        const char *numberPart = value.c_str() + 9; // Move pointer past "ROTATION-"
        int newRotations = atoi(numberPart);        // Convert the rest to integer
        Serial.print("NEW ROTATION VALUE = ");
        Serial.println(newRotations);
        rotations = newRotations; // Update the global variable
        preferences.begin("funcooker", false);
        preferences.putInt("rotations", newRotations);
        preferences.end();
        updateRequestCharacteristic("READY");
      }
      else if (strncmp(value.c_str(), "NAME-", 5) == 0)
      {
        Serial.println("NAME CHANGE REQUESTED");
        // Extract the number part after "NAME-"
        const char *namePart = value.c_str() + 5; // Move pointer past "NAME-"
        Serial.print("NEW NAME VALUE = ");
        Serial.println(namePart);
        preferences.begin("funcooker", false);
        preferences.putString("name", namePart);
        preferences.end();
        updateRequestCharacteristic("READY");
      }
      else
      {
        updateRequestCharacteristic("ERROR");
      }
    }
  }
};

// Read from the device Preference storage aand
// update the device state variables
void initLock()
{
  Serial.println("STARTING LOCK INITIALIZATION...");
  // updateStatusCharacteristic("INITIALIZING");

  preferences.begin("funcooker", false);

  currentPin = preferences.getString("pin", currentPin);
  Serial.print("CURRENT PIN IS " + currentPin);

  deviceName = preferences.getString("name", deviceName);
  Serial.print("CURRENT NAME IS " + deviceName);

  rotations = preferences.getInt("rotations", rotations);
  Serial.print("CURRENT ROTATIONS IS " + currentPin);

  // GET THE LAST KNOWN LOCK STATE (default to false/unlocked)
  isLocked = preferences.getBool("locked", false);

  preferences.end();

  unlockRequested = false;
  lockRequested = false;

  Serial.println("DONE WITH LOCK INITIALIZATION");
}

// Make a simple 1 rotation adjustment to the threaded rod
// Useful to fine tune the lock position
void adjust(bool isCCW)
{
  if (isCCW)
  {
    updateStatusCharacteristic("ADJUSTING");
    myStepper.step(-stepsPerRevolution * 1);
    updateRequestCharacteristic("READY");
    powerOffServo();
  }
  else
  {
    updateStatusCharacteristic("ADJUSTING");
    myStepper.step(stepsPerRevolution * 1);

    updateRequestCharacteristic("READY");
    powerOffServo();
  }
  if (isLocked)
  {
    updateStatusCharacteristic("LOCKED");
  }
  else
  {
    updateStatusCharacteristic("UNLOCKED");
  }
}

// Turn the servo to unlock the device
void unlock()
{
  if (isLocked)
  {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(200);
    digitalWrite(BUZZER_PIN, LOW);
    updateStatusCharacteristic("UNLOCKING");
    myStepper.step(-stepsPerRevolution * rotations);
    isLocked = false;
    updateStatusCharacteristic("UNLOCKED");
    updateRequestCharacteristic("READY");

    digitalWrite(BUZZER_PIN, HIGH);
    delay(200);
    digitalWrite(BUZZER_PIN, LOW);
    delay(200);
    digitalWrite(BUZZER_PIN, HIGH);
    delay(200);
    digitalWrite(BUZZER_PIN, LOW);
    powerOffServo();

    updateStoredStatus();
  }
}

// Turn the servo to lock the device
void lock()
{
  if (!isLocked)
  {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(200);
    digitalWrite(BUZZER_PIN, LOW);
    updateStatusCharacteristic("LOCKING");
    myStepper.step(stepsPerRevolution * rotations);
    isLocked = true;
    updateStatusCharacteristic("LOCKED");
    updateRequestCharacteristic("READY");
    digitalWrite(BUZZER_PIN, HIGH);
    delay(500);
    digitalWrite(BUZZER_PIN, LOW);
    delay(500);
    digitalWrite(BUZZER_PIN, HIGH);
    delay(500);
    digitalWrite(BUZZER_PIN, LOW);

    powerOffServo();

    updateStoredStatus();
  }
}

// Normal Arduino setup function
// Set up the Bluetooth server
void setup()
{
  Serial.begin();

  // SPI.begin(); // init SPI bus

  myStepper.setSpeed(16);

  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  // Initialize lock variables
  initLock();

  Serial.println("SETTING UP BLUETOOTH SERVER");

  BLEDevice::init(deviceName.c_str());
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new BTServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID);

  Serial.println("SETTING UP BLUETOOTH CHARACTERISTICS");
  pRequestCharacteristic = pService->createCharacteristic(
      REQUEST_CHARACTERISTIC_UUID,
      BLECharacteristic::PROPERTY_READ |
          BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY);
  pRequestCharacteristic->setValue("UNKNOWN");
  pRequestCharacteristic->setCallbacks(new BTCallbacks());
  pRequestCharacteristic->setNotifyProperty(true);
  BLE2902 *ble2902Request = new BLE2902();
  ble2902Request->setNotifications(true);
  pRequestCharacteristic->addDescriptor(ble2902Request);

  pStatusCharacteristic = pService->createCharacteristic(
      STATUS_CHARACTERISTIC_UUID,
      BLECharacteristic::PROPERTY_READ |
          BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY);
  pStatusCharacteristic->setValue("UNKNOWN");
  pStatusCharacteristic->setNotifyProperty(true);
  BLE2902 *ble2902Status = new BLE2902();
  ble2902Status->setNotifications(true);
  pStatusCharacteristic->addDescriptor(ble2902Status);

  Serial.println("STARTING BLUETOOTH SERVICE AND ADVERTISING");
  pService->start();
  // BLEAdvertising *pAdvertising = pServer->getAdvertising();  // this still is working for backward compatibility
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06); // functions that help with iPhone connections issue
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("BLUETOOTH CHARACTERISTICS ARE READY TO BE READ");

  if (isLocked)
  {
    Serial.println("PREVIOUS STATE = LOCKED");
    updateStatusCharacteristic("LOCKED");
  }
  else
  {
    Serial.println("PREVIOUS STATE = UNLOCKED");
    updateStatusCharacteristic("UNLOCKED");
  }

  updateRequestCharacteristic("READY");
}

void loop()
{

  if (unlockRequested)
  {
    unlock();
    unlockRequested = false;
  }

  if (lockRequested)
  {
    lock();
    lockRequested = false;
  }

  if (cwAdjustmentRequested)
  {
    adjust(false);
    cwAdjustmentRequested = false;
  }

  if (ccwAdjustmentRequested)
  {
    adjust(true);
    ccwAdjustmentRequested = false;
  }
}
