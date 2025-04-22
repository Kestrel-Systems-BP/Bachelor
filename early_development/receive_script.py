import socket
from time import sleep
import subprocess
import Adafruit_DHT
import asyncio

sensor = Adafruit_DHT.DHT11
data_pin = 23 #on the raspberry pi

udp_ip = "0.0.0.0"
recv_port = 5005

#global send socket
send_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

#global receive socket
recv_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
recv_socket.bind((udp_ip, recv_port))

print(f"Listning on UDP port {recv_port}")


async def temperatur_sender():
	while True:
		humidity, temperatur = Adafruit_DHT.read(sensor, data_pin)
		if humidity is not None and temperatur is not None:
			message = (f"Temperatur: {temperatur:.1f}C Humidity: {humidity:.1f}")
			print("Sending message")
			try:
				send_sock.sendto(message.encode(), ("172.20.10.3", 5007))
			except Exception as e:
				print(f"Error sending message: {e}")

		else:
			print("No sensor data available")

		await asyncio.sleep(60)


async def udp_receiver():
	while True:
		print("Hei")
		try:
			data, addr = await asyncio.get_running_loop().run_in_executor(None, recv_socket.recvfrom, 1024)
			message = data.decode('utf-8').strip().lower()
			print("Message from")

			if message.lower() == "open":
				print("Open command received")
				subprocess.run(["python3", "dispenser_openclose.py", "open"])

			elif message.lower() == "close":
				print("Close command recieved")
				subprocess.run(["python3", "dispenser_openclose.py", "close"])

			else:
				print("no known command")


		except Exception as e:
			print(f"Error receiving data: {e}")
		await asyncio.sleep(0.1)

async def main_function():
	await asyncio.gather(temperatur_sender(), udp_receiver())

asyncio.run(main_function())

