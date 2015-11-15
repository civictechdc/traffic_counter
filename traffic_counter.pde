/***************************************************************
 * 
 * Do-It-Yourself TRAFFIC COUNTER
 *
 * This is a fork of a project originally developed by Tomorrow Lab in NYC 2012 (v5). 
 * Original code written by Ted Ullricis_measuringh <ted@tomorrow-lab.com> 
 * See more http://tomorrow-lab.com and http://waycount.com
 *
 * Materials and guide can be found here http://issuu.com/shriya/docs/traffic_counter_guide
 *  
 * This work is licensed under a Creative Commons Attribution-ShareAlike 3.0 Unported License.
 * Please include credit to Tomorrow Lab in all future versions.
 ***************************************************************/

#include <EEPROM.h>
#include "EEPROMAnything.h"
#define NOTE_C6  1047
#define NOTE_E6  1319
#define NOTE_G6  1568
#define MEM_SIZE 512 //EEPROM memory size (remaining 2 bytes reserved for count)

// notes in the melody:
int melody[] = {
  NOTE_C6, NOTE_G6};
int noteDurations[] = {
  8,8};
int trigger_value; // pressure reading threshold for identifying a bike is pressing.
int threshold = 2; //change this amount if necessary. tunes sensitivity.
int the_tally; //total amount of sensings.
int incomingByte = 0;   // for incoming serial data
int the_time_offset; // in case of power out, it starts counting time from when the power went out.
int latest_minute;
int the_wheel_delay = 50; //number of milliseconds to create accurate readings for cars. prevents bounce.
int car_timeout = 3000;
long the_wheel_timer; //for considering that double wheel-base of cars, not to count them twice.
int the_max = 0;
int is_measuring = 0;
int count_this = 0;
int strike_number = 0;
float wheel_spacing = 2.7500; //average spacing between wheels of car (METERS)
float first_wheel = 0.0000000;
float second_wheel= 0.0000000;
float wheel_time = 0.0000000;
float the_speed = 0.0000000;
int time_slot;
int speed_slot;
int all_speed;


void setup() {
  pinMode(A0, INPUT);
  pinMode(2, OUTPUT);
  pinMode(13, OUTPUT);
  Serial.begin(9600);
  // make_tone();
  //update the tally variable from memory:
  EEPROM_readAnything(0,  the_tally); //the tally is stored in position 0. assigns the read value to 'the_tally'.
  EEPROM_readAnything((the_tally*2)+1, the_time_offset); //read the last time entry

  if (the_tally < 0) { //for formatting the EEPROM for a new device.
    erase_memory(); 
  }
  // read local air pressure and create offset.
  trigger_value = analogRead(A0) + threshold;
  delay(1000);
  Serial.println("Hello, Welcome to the DIY Traffic Counter");
  Serial.println("Developed by Tomorrow Lab in NYC");
  Serial.println("___________________________________________________");
  Serial.println("");
  Serial.print("Local Air Pressure: ");
  Serial.println(trigger_value - threshold);
  Serial.println("___________________________________________________");
  Serial.println("");
  Serial.println("ENTER 1 TO PRINT MEMORY");
  Serial.println("ENTER 2 TO ERASE MEMORY");
  Serial.println("___________________________________________________");


}

void loop() {
  //Serial.println(analogRead(A0));

  //1 - TUBE IS PRESSURIZED INITIALLY
  if (analogRead(A0) > trigger_value) {
    if (strike_number == 0 && is_measuring == 0) { // FIRST HIT
      Serial.println("");
      Serial.println("Car HERE. ");
      first_wheel = millis(); 
      is_measuring = 1;
    }
    if (strike_number == 1 && is_measuring == 1) { // SECOND HIT
      Serial.println("Car GONE.");
      second_wheel = millis();
      is_measuring = 0;
    }
  }


  //2 - TUBE IS STILL PRESSURIZED
  while(analogRead(A0) > the_max && is_measuring == 1) { //is being pressed, in all cases. to measure the max pressure.
    the_max = analogRead(A0); 
  }


  //3 - TUBE IS RELEASED
  if (analogRead(A0) < trigger_value - 1 && count_this == 0) { //released by either wheel
    if (strike_number == 0 && is_measuring == 1 && (millis() - first_wheel > the_wheel_delay)) {
      strike_number = 1;
    }
    if (strike_number == 1 && is_measuring == 0 && (millis() - second_wheel > the_wheel_delay) ) {
      count_this = 1;
    }
  }


  //4 - PRESSURE READING IS ACCEPTED AND RECORDED
  if ((analogRead(A0) < trigger_value - 1) && ((count_this == 1 && is_measuring == 0) || ((millis() - first_wheel) > car_timeout) && is_measuring == 1)) { //has been released for enough time.
    make_tone(); //will buzz if buzzer attached, also LED on pin 13 will flash.
    the_tally++; 
    time_slot = the_tally*2;
    speed_slot = (the_tally*2)+1;
    Serial.print("Pressure Reached = ");
    Serial.println(the_max);
    Serial.print("Current Count = ");
    Serial.println(the_tally);
    // Write the configuration struct to EEPROM
    EEPROM_writeAnything(0, the_tally); //puts the value of x at the 0 address.
    //Serial.print("time between wheels = ");
    wheel_time = ((second_wheel - first_wheel)/3600000);
    //Serial.println(wheel_time);
    int time = ((millis()/1000)/60) + the_time_offset + 1; // the number of seconds since first record.
    EEPROM_writeAnything(time_slot, time); //puts the value of y at address 'the_tally'.
    the_speed = (wheel_spacing/1000)/wheel_time;
    if (the_speed > 0 ) {
      Serial.print("Estimated Speed (km/h) = ");
      Serial.println(the_speed);
      EEPROM_writeAnything(speed_slot, int(the_speed)); //puts the value of y at address 'the_tally'.
    }
    else {
      Serial.println("Speed not measureable");
      EEPROM_writeAnything(speed_slot, 0); //puts the value of y at address 'the_tally'.
    }

    //RESET ALL VALUES
    the_max = 0; 
    strike_number = 0;
    count_this = 0;
    is_measuring = 0;

  }


  if (Serial.available() > 0) {
    // read the incoming byte:
    incomingByte = Serial.read();
    if (incomingByte == '1') {
      print_memory();
    }
    if (incomingByte == '2') {
      Serial.println("");
      Serial.println("ARE YOU SURE YOU WANT TO ERASE THE MEMORY? Enter Y/N");
    }
    if (incomingByte == 'N' || incomingByte == 'n') {
      Serial.println("MEMORY ERASE CANCELLED");
      Serial.println("___________________________________________________");
    }
    if (incomingByte == 'Y' || incomingByte == 'y') {
      erase_memory();  
      print_memory();
    }
  }
}


void print_memory() {
  //raw_print_memory();
  if (the_tally > 0) {
    Serial.println("");
    Serial.println("Count , Time (Minutes) , Speed (km/h)");
    for (int i=1; i<= the_tally; i++){
      Serial.print(i);
      Serial.print(" , ");
      long y = EEPROM.read(2*i);
      Serial.print(y);
      Serial.print(" , ");
      long z = EEPROM.read((2*i)+1);
      Serial.println(z); 
      all_speed = (all_speed+z); //add all the speeds together to find average.
      latest_minute = y;    
    }
  }

  Serial.println(""); 
  Serial.print("Total Cars, ");
  Serial.println(the_tally);//read memory
  Serial.print("Total Minutes Measured, ");
  Serial.println(latest_minute);
  Serial.print("Traffic Rate (cars per min), ");
  if ((the_tally/latest_minute) <= 0) {
    Serial.println("0");
  }
  else {
    Serial.println(the_tally/latest_minute);
  }
  Serial.print("Average Car Speed (km per hour), ");
  if ((all_speed/the_tally) <= 0) {
    Serial.println("0");
  }
  else {
    Serial.println(all_speed/the_tally);
  }
  Serial.println("___________________________________________________");
}


void raw_print_memory(){

  Serial.println("EEPROM REPORT: ");
  Serial.print("[");
  for (int i = 0; i <= MEM_SIZE; i++)
  {
    int h = EEPROM.read(i);
    Serial.print(h);
    if (i < MEM_SIZE)
    Serial.print(",");
  }
  Serial.println("]");

}

void erase_memory() {
  //erase current tally
  Serial.println("");
  Serial.println("ERASING MEMORY ...");
  for (int i = 0; i <= MEM_SIZE; i++){
    EEPROM.write(i, 0);
  }  
  the_tally = 0; 
  the_time_offset = 0;
  latest_minute = 0;
}



void make_tone() {
  for (int thisNote = 0; thisNote < 2; thisNote++) {

    //to calculate the note duration, take one second 
    //divided by the note type.
    //e.g. quarter note = 1000 / 4, eighth note = 1000/8, etc.
    int noteDuration = 1000/noteDurations[thisNote];
    tone(13, melody[thisNote],noteDuration);

    //to distinguish the notes, set a minimum time between them.
    //the note's duration + 30% seems to work well:
    int pauseBetweenNotes = noteDuration * 1.30;
    delay(pauseBetweenNotes);
    //stop the tone playing:
    noTone(13);
  }
}



