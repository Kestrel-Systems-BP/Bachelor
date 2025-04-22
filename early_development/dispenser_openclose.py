import RPi.GPIO as GPIO
import sys
from time import sleep
import socket

relay1 = 26 #relay1
relay2 = 20 #relay2
temp = 23

pc_ip = "172.20.10.3"
port = 5006


#set GPIO pins on RPI
GPIO.setmode(GPIO.BCM)
GPIO.setup(relay1, GPIO.OUT) # initial=GPIO.LOW)
GPIO.setup(relay2, GPIO.OUT) # initial=GPIO.HIGH)

def move_actuator(open):
	if open:
		print("Opening dispenser")
		open_message = "Opening... "
		send_message(open_message)
		GPIO.output(relay1, GPIO.LOW)
		GPIO.output(relay2, GPIO.LOW)
		print("AFTER")
	else:
		print("Closing dispenser")
		close_message = "Closing... "
		send_message(close_message)
		GPIO.output(relay1, GPIO.HIGH)
		GPIO.output(relay2, GPIO.HIGH)
	sleep(15) #time for actuator to open
	message = "Open" if open else "Closed"
	send_message(message)
	#stop_actuator()

def send_message(message):
	try:
		server_address = (pc_ip, port)
		sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
		sock.sendto(message.encode(), server_address)
	finally:
		sock.close()

#def send_temp():



#def stop_actuator():
#	print("Stopping actuator")
#	GPIO.output(relay1, GPIO.LOW)
#	GPIO.output(relay2, GPIO.HIGH)

def cleanup():
	GPIO.cleanup()

if __name__ == "__main__":
	try:
		if len(sys.argv) > 1:
			command = sys.argv[1].lower()
			if command == "open":
				move_actuator(True)
				print("No cleanup after open")
			elif command == "close":
				move_actuator(False)
				cleanup()
				print("Cleanup finished")
			else:
				print("No known command")
		else:
			print("No command received")
	finally:
		#stop_actuator()
		#sleep(10)
		#cleanup()
		#GPIO.setmode(GPIO.BCM)
		#GPIO.setmode(relay1, GPIO.OUT)
		#GPIO.setmode(relay2, GPIO.OUT)
		#GPIO.output(relay1, GPIO.HIGH)
		#GPIO.output(relay2, GPIO.LOW)
		print("FINISHED")



