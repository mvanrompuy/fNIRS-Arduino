/*
  First prototype fNIRS
 
 Sampling at +- 750 Hz (4ms for 3 samples)
 
 Send integer to request a number of samples or use start ('s') and stop ('e') commands.
 
 Maarten Van Rompuy 
 
 
 I²C Arduino UNO
 SDA A4
 SCL A5
 
 Configuration register
 BIT      7       6 5 4  3    2    1     0
 NAME     ST/BSY  0 0 SC DR1  DR0  PGA1  PGA0
 DEFAULT  
 
 ST/BSY 
 Write
 (ignored when in continuous conversion mode)
 0  No effect
 1  Starts a single conversion
 
 Read - Single conversion mode
 0  A/D conversion not busy, last result available in output register
 1  A/D conversion busy
 
 Read - Continuous conversion mode
 Always reads 1
 
 SC  
 0  Continuous conversion mode    DEFAULT
 1  Single conversion mode
 
 DR1 DR0       Data rate
 0 0   128SPS             12 bit
 0 1   32SPS              14 bit
 1 0   16SPS              15 bit
 1 1   8SPS      DEFAULT  16 bit
 
 PGA1 PGA0     Gain
 0 0   1         DEFAULT
 0 1   2
 1 0   4
 1 1   8
 
 If single-ended measurement -> lose 1 bit
 */

#include <Wire.h>

#define AD0 B1001000           // 7-bit address
#define ADConfig B10011000         // Configuration register - Warning: don't use continuous mode, conversion can happen on switch between LEDs on or of => value wrong

unsigned int sensorValue = 0;       // Unsigned 2-byte int
int configRegister = ADConfig;      // Set initial value
int confRegisterState;
int samplesRequested = 0;
int n = 0;
int sendData = 0;
int adcBusy = 1;
int samplingDelay = 30;
int delayChanged;
int newDelay; // Temporarily stores updated sampling delay until restart
int flushed;

// the setup routine runs once when you press reset:
void setup() {
  // initialize serial communication to PC at 19200 bits per second:
  Serial.begin(28800);
  Serial.println(configRegister); // Send configuration settings at startup
  Serial.println(samplingDelay);
  // Start I²C connection to ADC
  Wire.begin();                  // Join bus as master
  Wire.beginTransmission(AD0);   // Start transmission with ADC
  Wire.write(configRegister);
  Wire.endTransmission();

  // declare pin 8 to be an output:
  pinMode(2, OUTPUT);
  pinMode(3, OUTPUT);

  digitalWrite(2,0);
  digitalWrite(3,0);
}

// the loop routine runs over and over again forever:
void loop() {
  String data;
  int startTime;

  // Update sampling delay
  if(delayChanged == 1) {
    samplingDelay = newDelay;
    delayChanged = 0;
    Serial.print("Sampling delay set to ");
    Serial.print(samplingDelay);
    Serial.println(" milliseconds.");
  }

  // Check for commands from Matlab
  if (Serial.available() > 0) {
    // Wait for signal from Matlab that serial data buffer is empty to prevent wrong interpreted data
    int incomingByte = Serial.read();

    if(flushed == 1) { // Check if matlab is ready
      switch(incomingByte) {
        case 100: // Sampling delay command ('d')
          newDelay = Serial.parseInt();
          delayChanged = 1;
          break;
        case 110: // Number of samples command ('n')
          samplesRequested = Serial.parseInt();
          Serial.print("Arduino will send ");
          Serial.print(samplesRequested);
          Serial.println(" samples:");
          break;
        case 115: // Start command ('s')
          sendData = 1;
          Serial.println("Arduino will send data until it receives the stop command ('e')");
          break;
      }
    // If matlab hasn't yet send flushed acknowledgement, check for it
    } else if(incomingByte == 102) { // Flush acknowledgement ('f')
        flushed = 1;
    } else {
        // Ignore unknown command
    }
   }

  // Store time at start of sampling
  startTime = millis();

  // Execute sampling and send data to Matlab
  for(int i = 0;i<samplesRequested || sendData == 1;i++){
    data = "";
    Serial.print(millis() - startTime); // Time since start sampling
    Serial.print(",");

    for(int c = 1; c <= 3; c++){
      switch(c){
      case 1:
        digitalWrite(2,0);
        digitalWrite(3,0);
        break;
      case 2:
        digitalWrite(2,1);
        digitalWrite(3,0);
        break;
      case 3:
        digitalWrite(2,0);
        digitalWrite(3,1);
        break;
      }

      Wire.beginTransmission(AD0);
      Wire.write(configRegister);              // Set bit 7 -> start single conversion
      Wire.endTransmission();        // Write qeued byte;

      adcBusy = 1;
      while(adcBusy == 1) {
        Wire.requestFrom(AD0, 3);      // Read 3 bytes = output register (2 bytes) + configuration register (1 byte)   
        while(Wire.available()) {        
          sensorValue = 0;

          sensorValue = Wire.read();        // First byte  
          sensorValue = sensorValue << 8;   // Shift
          sensorValue += Wire.read();       // Second byte

          confRegisterState = Wire.read();       // Configuration register

          adcBusy = bitRead(confRegisterState,7);
          // if(bitRead(confRegisterState,7) == 0) {// If 8th bit is unset -> ADC conversion done
          //   Serial.println("ADC conversion done!");
          // }
        }
      }
      digitalWrite(2,0);
      digitalWrite(3,0);
      data += sensorValue;
      data += ",";
      delay(samplingDelay);
      
      // Check for commands from Matlab
      if (Serial.available() > 0) {
        int incomingByte = Serial.read();
        switch(incomingByte) {
          case 99: // ADC configuration command ('c' followed by byte to set configuration registor of ADS1100)
            configRegister = Serial.parseInt();  // Read configuration byte and update configuration register
            break;
          case 100: // Delay command ('d')
            newDelay = Serial.parseInt();
            delayChanged = 1;
            sendData = 0;
            flushed = 0;
            break;
          case 101: // Stop command ('e')
            sendData = 0;
            flushed = 0;
            break;
        }
      }
    }
    Serial.println(data);
  }
  samplesRequested = 0;
  sendData = 0;
  data = "";
  digitalWrite(2,0);
  digitalWrite(3,0);
}

// When using internal ADC of Arduino UNO
//        // Clear ADC capacitor
//        analogRead(A1);
//        analogRead(A0);
//        //Delay to provide correct measurements
//        delay(2); // Dont't make to short -> needs time to settle
//        // read the input on analog pin 0:
//        sensorValue = analogRead(A0);
////        sensorValue = sensorValue + analogRead(A0);
////        sensorValue = sensorValue/2;
//        //Delay to provide correct measurements
//        delay(10);
//        digitalWrite(2,0);
//        digitalWrite(3,0);
//        analogRead(A1);
//        delay(100);

