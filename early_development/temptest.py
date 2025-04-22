import Adafruit_DHT
from time import sleep
import RPi.GPIO as gpio

sensor = Adafruit_DHT.DHT11

data_pin = 23


def read_dht11():
	while True:
		try:
			humidity, temperatur = Adafruit_DHT.read(sensor, data_pin)
			if humidity is not None and temperatur is not None:
				print(f"Temperatur: {temperatur:.1f}C  Humidity: {humidity:.1f}%")
			else:
				print("No sensor data available")

			sleep(5) #write data every 5 seconds
		except KeyboardInterrupt:
			break
if __name__ == "__main__":
	read_dht11()
