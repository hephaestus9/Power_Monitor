#define DEBUG false
#include <DHT22.h>

// Data wire for RTH03 is plugged into port 7 on the Arduino
// Connect a 4.7K resistor between VCC and the data pin (strong pullup)
#define DHT22_PIN 2

#define LM358N1_PIN 0
#define LM358N2_PIN 1
#define ledPin 13

int maxReadingLM358N1 = 0;
int maxReadingLM358N2 = 0;
int currReadingLM358N1 = 0;
int currReadingLM358N2 = 0;
float main1 = 0.0;
float main2 = 0.0;
float comb = 0.0;
int ledState = LOW;             

int packetSent = false;

// Setup a DHT22 instance
DHT22 myDHT22(DHT22_PIN);


void setup(){
  // Open serial communications and wait for port to open:
  Serial.begin(115200);
  //while (!Serial) {
  // ; // wait for serial port to connect. Needed for Leonardo only
  // }  
  pinMode(ledPin, OUTPUT);    
 }
 
 void loop(){
   //----------------Amperage--------------------------------------------------
   //Reset values for new packet
   if (packetSent){
     packetSent = false;
     maxReadingLM358N1 = 0;
     maxReadingLM358N2 = 0;
   }
   int i;
   for (i=0; i<250; i++) {
     // Get ADC reading for both sensors
     currReadingLM358N1 = analogRead(LM358N1_PIN);
     currReadingLM358N2 = analogRead(LM358N2_PIN);
     
     if (currReadingLM358N1 > maxReadingLM358N1) {
       maxReadingLM358N1 = currReadingLM358N1;
       }
     if (currReadingLM358N2 > maxReadingLM358N2) { 
       maxReadingLM358N2 = currReadingLM358N2;
       }
     
   }
   //                           \/ -- Arduino AREF                 \/--------Burden Resistance
   main1 = (maxReadingLM358N1 * 5 * 3100.0) / (1023.0 * sqrt(2) * 150);
   main2 = (maxReadingLM358N2 * 5 * 3100.0) / (1023.0 * sqrt(2) * 150);
   comb = main1 + main2;
   
  //-----------------------------------------------------------------------------
  //---------------------RHT-----------------------------------------------------
  DHT22_ERROR_t errorCode;
  float temperature = 0;
  float tempF = 0;
  float humidity = 0;
  
  DHT22_ERROR_t errorCode2;
  float temperature2 = 0;
  float tempF2 = 0;
  float humidity2 = 0;
  // The sensor can only be read from every 1-2s, and requires a minimum
  // 2s warm-up after power-on.
  delay(2000);
  errorCode = myDHT22.readData();
  temperature = myDHT22.getTemperatureC();
  humidity = myDHT22.getHumidity();
  tempF = (temperature*1.8)+32;
  
  #if DEBUG
    Serial.println("Temp: ");
    Serial.println(tempF);
    Serial.println("Humidity: ");
    Serial.println(humidity);
    Serial.println();
    Serial.println("Raw Reading");
    Serial.println("Main 1: ");
    Serial.println(maxReadingLM358N1);
    Serial.println("Main 2: ");
    Serial.println(maxReadingLM358N2);
    Serial.println();
    Serial.println("Calculated Amperage");
    Serial.println("Main 1: ");
    Serial.println(main1);
    Serial.println("Main 2: ");
    Serial.println(main2);
    Serial.println("Combined: ");
    Serial.println(comb);
    Serial.println("#################################");
    packetSent = true;
  #endif
  
  Serial.print(tempF);
  Serial.print(":");
  Serial.print(humidity);
  Serial.print(":");
  Serial.print(main1);
  Serial.print(":");
  Serial.print(main2);
  Serial.print(":");
  Serial.print(comb);
  Serial.println();
  
  ledState = HIGH;
  digitalWrite(ledPin, ledState);
  delay(15);
  ledState = LOW;
  digitalWrite(ledPin, ledState);
  
  packetSent = true;
  
  switch(errorCode)
  {
    case DHT_ERROR_NONE:
      temperature = myDHT22.getTemperatureC();
      humidity = myDHT22.getHumidity();
      break;
    case DHT_ERROR_CHECKSUM:
      temperature = 100;
      humidity = 100;
      break;
    case DHT_BUS_HUNG:
      Serial.println("BUS Hung ");
      break;
    case DHT_ERROR_NOT_PRESENT:
      Serial.println("Not Present ");
      break;
    case DHT_ERROR_ACK_TOO_LONG:
      Serial.println("ACK time out ");
      break;
    case DHT_ERROR_SYNC_TIMEOUT:
      Serial.println("Sync Timeout ");
      break;
    case DHT_ERROR_DATA_TIMEOUT:
      Serial.println("Data Timeout ");
      break;
    case DHT_ERROR_TOOQUICK:
      Serial.println("RHT03 Polled to quick ");
      break;
  }
  
  //---------------------------------------------------------------------------
  
 }

