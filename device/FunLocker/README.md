# Funlocker (ESP32/Arduino Device Code)

Arduino/ESP32 device code to control a custom BLE locking device.

> ⚠️ **Warning** ⚠️  
> Please note this is not production ready device code and as such does not implement heavy error handling or any hardened security.
> For demo/education purposes only - useful for other BLE use cases 

## Bluetooth Low Energy Communication Details

Two BLE Characteristics (think messaging endpoints if not familiar). A Status Characteristic to access the current state of the device and Request Characteristic for sending commands/getting acknowledgments.

``` c
#define SERVICE_UUID "e2b3e883-bbb4-4402-bd39-7658ddd7f5af"
#define REQUEST_CHARACTERISTIC_UUID "3171f86b-c1fc-4893-a3db-98ae4c29df0c"
#define STATUS_CHARACTERISTIC_UUID "4d0910dd-87dc-4a3c-a7f3-b3c8a49afdbc"
```


Key Application -> Device **command** communications include:

``` text
Use Case       Application               Device

Request a PIN change...
PIN Change -> [OLDPIN]-NEWPIN-[NEWPIN] -> Request Characteristic
                    READY [or ERROR] <--- Request Characteristic

Initiate the unlocking of the device...
Unlock           ---->[ PIN]-UNLOCK ----> Request Characteristic
                    READY [or ERROR] <--- Request Characteristic
                            UNLOCKING <--- Status Characteristic
                             UNLOCKED <--- Status Characteristic

Initiate the locking of the device...
Lock              --------> LOCK -------> Request Characteristic
                    READY [or ERROR] <--- Request Characteristic
                              LOCKING <--- Status Characteristic
                               LOCKED <--- Status Characteristic

Make small adjustments to the locking bolt...
Adjusting         -----> [PIN]-CCW -----> Request Characteristic
Counter             READY [or ERROR] <--- Request Characteristic
Clockwise                   ADJUSTING <--- Status Characteristic

Adjusting         ------> [PIN]-CW -----> Request Characteristic
Clockwise           READY [or ERROR] <--- Request Characteristic
                            ADJUSTING <--- Status Characteristic

Flip the UNLOCK/LOCK device setting (useful during 
testing or after system/power failure)...
Flip              -----> [PIN]-FLIP ----> Request Characteristic
                    READY [or ERROR] <--- Request Characteristic
                 LOCKED [or UNLOCKED] <--- Status Characteristic

Update the Name of the device...
Name             -----> NAME-[NAME] ----> Request Characteristic
Change              READY [or ERROR] <--- Request Characteristic

Update the Rotations required to lock the device...
Rotations     ---> ROTATIONS-[NUMBER] --> Request Characteristic
Change              READY [or ERROR] <--- Request Characteristic
```

## Dependencies

- Arduino Stepper Library  
https://github.com/arduino-libraries/Stepper

## Hardware

- Tested on the ESP32-C3 Devkit (specifically ESP32 C3 Super Mini Dev Board)

- Leverages the ubiquitous 5V 28BYJ-48 Stepper Motor and ULN2003 Driver.
Yes it is very slow to lock/unlock 😉

## Pin Out

While connecting an external power supply to feed 5v to both the Servo and ESP32 is 
recommended, supplying the Servo from the ESP32 is sufficient for the small draw 
without effecting the ESP32 or connectivity. It is however, slow!

| ESP32-C3 | ULN2003 Board |
|---|---|
| GPIO0 | IN1 |
| GPIO1 | IN2 |
| GPIO2 | IN3 |
| GP103 | IN4 |
| 5V | 5V |
| GND | GND |

