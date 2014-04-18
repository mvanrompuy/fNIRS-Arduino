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
#define conf B10011000         // Configuration register - Warning: don't use continuous mode, conversion can happen on switch between LEDs on or of => error

unsigned int sensorValue = 0;       // Unsigned 2-byte int
byte confRegister;
int samplesRequested = 0;
int n = 0;
int sendData = 0;
int adcBusy = 1;

// the setup routine runs once when you press reset:
void setup() {
  // initialize serial communication to PC at 19200 bits per second:
  Serial.begin(28800);

  // Start I²C connection to ADC
  Wire.begin();                  // Join bus as master
  Wire.beginTransmission(AD0);   // Start transmission with ADC
  Wire.write(conf);
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

  if (Serial.available() > 0) {
    if(Serial.peek() == 115) { // Start command ('s')
        Serial.read(); // Peek doesn't remove read byte from buffer
        sendData = 1;
        Serial.println("Arduino will send data until it receives the stop command ('e')");
    } else {
      // read the incoming byte:
      samplesRequested = Serial.parseInt();
      
      Serial.print("Arduino will send ");
      Serial.print(samplesRequested);
      Serial.println(" samples:");
    }
  
    for(int i = 0;i<samplesRequested || sendData == 1;i++){
      data = "";
      Serial.print(millis());
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
        Wire.write(conf);              // Set bit 7 -> start single conversion
        Wire.endTransmission();        // Write qeued byte;
        
        adcBusy = 1;
        while(adcBusy == 1) {
          Wire.requestFrom(AD0, 3);      // Read 3 bytes = output register (2 bytes) + configuration register (1 byte)   
          while(Wire.available()) {        
            sensorValue = 0;
  
            sensorValue = Wire.read();        // First byte  
            sensorValue = sensorValue << 8;   // Shift
            sensorValue += Wire.read();       // Second byte
            
            confRegister = Wire.read();       // Configuration register

            adcBusy = bitRead(confRegister,7);
                // if(bitRead(confRegister,7) == 0) {// If 8th bit is unset -> ADC conversion done
                //   Serial.println("ADC conversion done!");
                // }
          }
        }
        digitalWrite(2,0);
        digitalWrite(3,0);
        data += sensorValue;
        data += ",";
        delay(25);
        if (Serial.available() > 0) {
          if (Serial.read() == 101) { //Stop command ('e')
            sendData = 0;
          }
        }
      }
        Serial.println(data);
    }
  }
  samplesRequested = 0;
  sendData = 0;
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
