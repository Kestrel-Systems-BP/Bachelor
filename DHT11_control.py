import asyncio
import logging
import Adafruit_DHT

logging.basicConfig(
	filename='logs/drone_dispenser.log',
	format='%(asctime)s %(levelname)s %(message)s')

async def read_dht11(sending_queue, sensor_pin):
	sensor = Adafruit_DHT.DHT11
	while True:
		try:
			humidity, temperature = Adafruit_DHT.read(sensor, sensor_pin)
#			print(f"Results: h={humidity}, t={temperature}")
			if humidity is not None and temperature is not None:
				message = (f"{temperature:.1f},{humidity:.1f}")
#				print("In DHT11 queue", message)
				await sending_queue.put({"type": "sensor", "data": message})
			else:
#				print("No DHT11 results")
				logging.warning("No data to read")
		except Exception as e:
#			print("Exception as e= {e}")
			logging.error(f"DHT11 error: {e}")
		await asyncio.sleep(5)
