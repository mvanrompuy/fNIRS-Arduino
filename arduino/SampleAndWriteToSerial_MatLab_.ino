/*
  First prototype fNIRS
 
  Sampling at +- 750 Hz (4ms for 3 samples)
  
  Send integer to request a number of samples or use start ('s') and stop ('e') commands.
 
 Maarten Van Rompuy  
 */

int sensorValue = 0;
int samplesRequested = 0;
int n = 0;
int sendData = 0;

// the setup routine runs once when you press reset:
void setup() {
  // initialize serial communication at 9600 bits per second:
  Serial.begin(19200);

  // declare pin 8 to be an output:
  pinMode(2, OUTPUT);
  pinMode(3, OUTPUT);
//  pinMode(10, OUTPUT); // analog output
  
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

        //Delay to provide correct measurements
        analogRead(A0);
        delay(2);
        // read the input on analog pin 0:
        sensorValue = analogRead(A0);
//        sensorValue = sensorValue + analogRead(A0);
//        sensorValue = sensorValue/2;
        //Delay to provide correct measurements
        delay(2);
        digitalWrite(2,0);
        digitalWrite(3,0);
        delay(14);
        data += sensorValue;
        data += ",";
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
