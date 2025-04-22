import RPi.GPIO as GPIO
from time import sleep
import sys

#GPIO pins, defined based on the placement on the Raspberry Pi
STEP_PIN = 21
DIR_PIN = 20
cw_direction = 0
ccw_direction = 1


#Defines pins as output and initialize the DIR pin to clockwise rotation
GPIO.setmode(GPIO.BCM)
GPIO.setup(STEP_PIN, GPIO.OUT)
GPIO.setup(DIR_PIN, GPIO.OUT)
GPIO.output(DIR_PIN, cw_direction)

def step_motor(steps, direction): #drives the motor
	GPIO.output(DIR_PIN, direction)
	sleep(0.5)
	for i in range(steps):
		GPIO.output(STEP_PIN, GPIO.HIGH)
		sleep(0.001)
		GPIO.output(STEP_PIN, GPIO.LOW)
		sleep(0.0005)


def open_lid():
	print("Lid opening...")
	step_motor(4000, ccw_direction) #drives the motor cw and opens the lid

def close_lid():
	print("Closing lid...")
	step_motor(4000, cw_direction) #drives the motor ccw and closes the lid


def cleanup():
	GPIO.cleanup()

if __name__ == "__main__":
	if len(sys.argv) > 1:
		command =sys.argv[1].lower()
		if command == "open":
			open_lid()
		elif command == "close":
			close_lid()
		else:
			print("No known command received")
	else:
		print("No command received")
	cleanup()
else:
	print("No main funtion")

