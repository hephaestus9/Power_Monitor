#define DEBUG true
#define STATICIP false

#include <SPI.h>
#include <Ethernet.h>
#include <DHT22.h>
#include <HttpClient.h>
#include <Xively.h>

#define DHT22_PIN 2

#define LM358N1_PIN 0
#define LM358N2_PIN 1


int maxReadingLM358N1 = 0;
int maxReadingLM358N2 = 0;
int currReadingLM358N1 = 0;
int currReadingLM358N2 = 0;
float main1 = 0.0;
float main2 = 0.0;
float comb = 0.0;

int packetSent = false;

// Setup a DHT22 instance
DHT22 myDHT22(DHT22_PIN);

// MAC address from sticker***
byte mac[] = { 
  0x90, 0xA2, 0xDA, 0x0D, 0x57, 0xD4 };
  
#if STATICPIP 
IPAddress ip(192,168,1, 177);
#endif

// Your Xively key to let you upload data
char xivelyKey[] = "YOUR_XIVELY_API_KEY";

// Define the strings for our datastream IDs
char humidity1Stream[] = "humidity1";
char temp1Stream[] = "temp1";

char main1Stream[] = "main1";
char main2Stream[] = "main2";
char combStream[] = "combined";

XivelyDatastream datastreams[] = {
  // Float datastreams are set up like this:
  XivelyDatastream(humidity1Stream, strlen(humidity1Stream), DATASTREAM_FLOAT),
  XivelyDatastream(temp1Stream, strlen(temp1Stream), DATASTREAM_FLOAT),
  // Int datastreams are set up like this:
  XivelyDatastream(main1Stream, strlen(main1Stream), DATASTREAM_FLOAT),
  XivelyDatastream(main2Stream, strlen(main2Stream), DATASTREAM_FLOAT),
  XivelyDatastream(combStream, strlen(combStream), DATASTREAM_FLOAT)
  };
  
// Finally, wrap the datastreams into a feed
XivelyFeed feed(FEED_ID, datastreams, 5);

// Initialize the Ethernet server library
EthernetServer server(8080);

void setup(){
  #if DEBUG
    // Open serial communications and wait for port to open:
    Serial.begin(9600);
    while (!Serial) {
     ; // wait for serial port to connect. Needed for Leonardo only
     }
    Serial.println("Starting single datastream upload to Xively...");
    Serial.println();
  #endif
  
  // start the Ethernet connection and the server:
  #if STATICPIP
    Ethernet.begin(mac, ip);
  #else
    while (Ethernet.begin(mac) != 1) {
      #if DEBUG
        Serial.println("Error getting IP address via DHCP, trying again...");
      #endif
      delay(15000);
    }
    #if DEBUG
      // report the dhcp IP address:
      Serial.println(Ethernet.localIP());
    #endif
  #endif
  server.begin();
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
   //Capture max value from 20 samples
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
  //--------------Ethernet----------------------------------------------------
  // listen for incoming clients
  EthernetClient client;
  XivelyClient xivelyclient(client);
  datastreams[0].setFloat(humidity);                           // Push a float datapoint
  datastreams[1].setFloat(tempF);
  datastreams[2].setFloat(main1);
  datastreams[3].setFloat(main2);
  datastreams[4].setFloat(comb);
  
  #if DEBUG
    Serial.println("Uploading it to Xively");
  #endif
 
  int ret = xivelyclient.put(feed, xivelyKey);
  
 }

