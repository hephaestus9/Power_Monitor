/*
Modified by J.Brian Apr 2014
BBCC_Plotter
 by Tim Hirzel, Feb 2008
 v 1.1

 with gratitude, based on:
 Grapher Pro!
 by Tom Igoe


 This Processing application is designed to plot and display values 
 coming from the BBCC PID controller for Arduino.  With minimal modification,
 it could be setup to plot and show different incoming data

 Please refer to the top section for alterations of plot ranges, graph size etc.

 All code released under
 Creative Commons Attribution-Noncommercial-Share Alike 3.0 
 */

import processing.serial.*;

// *********  unlikely that you want to change these  ********* 
int BAUDRATE = 9600; 
char DELIM = ':'; // the delimeter for parsing incoming data
//char INIT_MARKER = '!';      //Look for this character before sending init message

//String INIT_MESSAGE = "?gu";  //Send these characters to the arduino after init to start up messages
// this gets the help string from teh device, and then turns on plotting mode with constant update strings

//  *********  SETINGS  *********

int yBorder = 60;  // Size of the background area around the plot in screen pixels
int xBorder = 90;

// the plot size in screen pixels
int plotHeight = 450;
int plotWidth = 750;

int ExpectUpdateSpeed = 200; // milliseconds.  This just allows the axis labels in the X direction accurate

// These are all in real number space
// all X values measured in ExpectedUpdateSpeed Intervals
 // all y measured in degrees
int gridSpaceX = 50;  
int gridSpaceY = 10; 
int startX = 0;
int endX = 600;
int startY = 0;
int endY = 120;

// leave these to be calculated
float pixPerRealY = float(plotHeight)/(endY - float(startY));
float pixPerRealX = float(plotWidth)/(endX - float(startX));

// These are calculated here, but could be changed if you wanted
int windowWidth = plotWidth + 2*xBorder;
int windowHeight = plotHeight +  2*yBorder;

// ******* Legend  ********
// Define the location and size of the Legend area
int legendWidth = 125;
int legendHeight = 130;
int legendX = windowWidth - 140;
int legendY =  15;

// ******* Help Window  ********
// Define the size of the help area.  It always sits in the middle
int helpWidth = 600;
int helpHeight = 400;


String title = "Home Monitor Data";    // Plot Title
String names = "Temp. Humidity MainA MainB Combined";                    // The names of the values that get sent over serial
String yLabel = "T\ne\nm\np\ne A\nr m\na p\nt s\nu\nr\ne\n\nF A";  // this is kind of a hack to make the vertical label
String xLabel = "Time";                               // X axis label
String fontType = "Courier";                             // Y axis label
boolean[] plotThisName = {
  true, true, true, true, true};                // For each of the values, you can choose if you want it plotted or not here

//  ****************   end of Settings area  ****************

String helpBase = "-Plotter Help-\n(all characters are case sensitive)\nh : toggle this help screen\nl : toggle the Legend\nS : save screen\nE : export shown data as text\n\n-Device Help-  \n";
String helpString = "";
Serial myPort;                // The serial port

boolean displayLegend = true;
boolean displayHelp = true;

int sensorCount = 5;                        // number of values to expect
float[][] sensorValues = new float[endX-startX][sensorCount];  // array to hold the incoming values
int currentValue = -1;
int hPosition = startX;                          // horizontal position on the plot
int displayChannel = 0;                     // which of the five readings is being displayed
int threshold = 50;                         // threshold for whether or not to write
// data to a file
boolean updatePlot = false;
//int [] lastSet  = new int[sensorCount];

int[][] colors = new int[sensorCount][3];

PFont titleFont;
PFont labelFont;

void setupColors() {
  // Thanks to colorbrewer for this pallete
  colors[0][0] = 102;  
  colors[0][1] =194; 
  colors[0][2] = 165;
  colors[1][0] = 252;  
  colors[1][1] = 141; 
  colors[1][2]= 98;
  colors[2][0] = 141;  
  colors[2][1] = 160; 
  colors[2][2]= 203;
  colors[3][0] = 231;  
  colors[3][1] = 138; 
  colors[3][2]= 195;
  colors[4][0] = 166;  
  colors[4][1] = 216; 
  colors[4][2]= 84;
  //colors[5][0] = 255;  
  //colors[5][1] = 217; 
  //colors[5][2]= 47;
}


void setup () {
  size(windowWidth, windowHeight);        // window size
  setupColors();
  smooth();
  //  println(PFont.list());
  titleFont = createFont(fontType, 18);
  labelFont = createFont(fontType, 14 );

  clearPlot();
  // List all the available serial ports
  println(Serial.list());

  // On my mac, the arduino is the first on this list.
  // Open whatever port is the one you're using.
  myPort = new Serial(this, Serial.list()[1], BAUDRATE);
  // clear the serial buffer:
  myPort.clear();
}

void draw () {
  // if the value for the given channel is valid, plot it:
  if (updatePlot) {
    // draw the plot:
    plot();
    updatePlot = false;
  }
}

void clearPlot() {
  background(5);
  strokeWeight(1.5);
  stroke(10);
  fill(40);
  // draw boundary
  rect(xBorder,yBorder,plotWidth, plotHeight);

  textAlign(CENTER);
  fill(70);
  textFont(titleFont);
  text(title, windowWidth/2, yBorder/2);

  textFont(labelFont);
  stroke(10);
  //draw grid  
  fill(70);
  textAlign(RIGHT);
  for (int i = startY; i <= endY; i+= gridSpaceY) {
    line(xBorder - 3, realToScreenY(i), xBorder + plotWidth - 1,  realToScreenY(i));
    text(str(i), xBorder - 10, realToScreenY(i));
  }

  textAlign(LEFT);
  for (int i = startX; i <= endX ; i+= gridSpaceX) {
    line(realToScreenX(i), yBorder+1, realToScreenX(i), yBorder + plotHeight + 3);
    text(str((i)/ (1000 / ExpectUpdateSpeed)), realToScreenX(i), yBorder + plotHeight + 20);
  }

  // Draw Axis Labels
  fill(70);
  text(yLabel, xBorder - 70,  yBorder + 100 );

  textAlign(CENTER);
  text(xLabel,  windowWidth/2, yBorder + plotHeight + 50);


}

float realToScreenX(float x) {
  float shift = x - startX;
  return (xBorder + shift * pixPerRealX);
}

float realToScreenY(float y) {
  float shift = y - startY;
  return yBorder + plotHeight - 1 - (shift) * pixPerRealY;

}

void plot () {
  clearPlot();
  // draw the line:
  for (int i = 0; i < sensorCount; i++) {
    // assign color to each plot
    stroke(colors[i][0], colors[i][1],colors[i][2]);

    for (int x = 1; x < currentValue; x++) {
      if(plotThisName[i]) {

        line(realToScreenX(x-1), 
        realToScreenY(sensorValues[x-1][i]) ,
        realToScreenX(x),
        realToScreenY(sensorValues[x][i]) 
          );

      }
    }
  }

  if (hPosition >= endX) {
    hPosition = startX;
    // wipe the screen clean:
    clearPlot();
  } 
  else {
    hPosition += 1;  
  }


  noStroke();
  // DRAW LEGEND
  if (displayLegend) {
    fill(128,128,128,80);
    rect(legendX, legendY, legendWidth, legendHeight);

    // print the name of the channel being graphed:
    String line;
    for (int i = 0; i < sensorCount; i++) {
      fill(colors[i][0], colors[i][1],colors[i][2]);
      textAlign(LEFT);
      text(split(names,' ')[i] , legendX+5, legendY + (i+1) * 20);
      textAlign(RIGHT);
      text(nf(sensorValues[currentValue][i], 0,2), legendX+legendWidth - 5, legendY + (i+1) * 20);
    }
  }

  if (displayHelp) {
    textAlign(LEFT);  
    fill(128,128,128,80);
    noStroke();
    rect(windowWidth/2 - helpWidth/2, windowHeight/2 - helpHeight / 2, helpWidth, helpHeight);
    fill(255,255,255);
    helpWidth -= 20;
    helpHeight -=20;
    text(helpString,windowWidth/2 - helpWidth/2, windowHeight/2 - helpHeight / 2, helpWidth, helpHeight);
    helpWidth += 20;
    helpHeight +=20;

  }
}

void keyPressed() {
  // if the key pressed is "0" through "4"
  if (key == 'l') {
    // set the display channel accordingly
    displayLegend = ! displayLegend;  
    updatePlot = true;
  }
  if (key == 'h') {
    // set the display channel accordingly
    displayHelp = ! displayHelp;  
    updatePlot = true;
  }
  if (key == 'S') {
    // set the display channel accordingly
    save(str(hour()) + "h" + str(minute()) + "m" + str(second()) +  "s"  + str(month()) + "." + str(day()) + "." + str(year())+".jpg") ;
  }
  if (key == 'E') {
    exportText();
  }
  myPort.write(key);

}

void exportText() {
  // string for the new data you'll write to the file:
  String[] outStrings = new String[currentValue+1];
  outStrings[0] = names;
  for (int i =0; i < currentValue; i++) {
    outStrings[i+1] = "";
    for (int j=0; j < sensorCount; j++) {
      outStrings[i+1]   += str(sensorValues[i][j]);
      if (j < sensorCount - 1) {
        outStrings[i+1] += ", ";
      }
    }
  }
  saveStrings(str(hour()) + "h" + str(minute()) + "m" + str(second()) +  "s"  + str(month()) + "." + str(day()) + "." + str(year())+".txt", outStrings);
}

// make up a timeStamp string for writing data to the file:
String timeStamp() {
  String now = hour()+ ":" +  minute()+ ":" + second()+ " " +
    month() + "/"  + day() + "/" + year();
  return now;
}


void serialEvent(Serial myPort) {
  // read incoming data until you get a newline:
  String serialString = myPort.readStringUntil('\n');
  // if the read data is a real string, parse it:

  if (serialString != null) {
    println(serialString);
    // split it into substrings on the DELIM character:
    String[] numbers = split(serialString, DELIM);
    // convert each subastring into an int
    if (numbers.length == sensorCount) {
      currentValue += 1;
      if (currentValue >= (endX-startX))
      {  
        currentValue = 0;
      }
      for (int i = 0; i < numbers.length; i++) {
        // make sure you're only reading as many numbers as
        // you can fit in the array:
        if (i <= sensorCount) {
          // trim off any whitespace from the substring:
          numbers[i] = trim(numbers[i]);
          sensorValues[currentValue][i] =  float(numbers[i]);
        }
      }
      updatePlot = true;
    } 
    else if (currentValue == -1){
      // The help string from the first '?' character gets appended to the plotter help string
      helpString += serialString;
    }
    else {
      // Things we don't handle in particular can get output to the text window
      print(serialString);
    }
  }
}

