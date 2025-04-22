import asyncio
import logging
import RPi.GPIO as GPIO

logging.basicConfig(
    filename='logs/drone_dispenser.log',
    format = '%(asctime)s %(levelname)s %(message)s')


async def control_actuator(queue, relay_pin1, relay_pin2):
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(relay_pin1, GPIO.OUT)
    GPIO.setup(relay_pin2, GPIO.OUT)
    while True:
        try:
            command = await queue.get()
            if command["type"] == "actuator":
                if command["data"] == "open":
                    GPIO.output(relay1, GPIO.LOW)
                    GPIO.output(relay2, GPIO.LOW)
                    await queue.put({"type": "status_actuator", "data": "Dispenser opened"})
                elif command["data"] == "close":
                    GPIO.output(relay1, GPIO.HIGH)
                    GPIO.output(relay2, GPIO.HIGH)
                    await queue.put({"type": "status_actuator", "data": "Dispenser closed"})
            queue.task_done()
        except Exception as e:
            logging.error(f"Error with the actuator: {e}")
            await asyncio.sleep(1)
