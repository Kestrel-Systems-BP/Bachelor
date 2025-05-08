import asyncio
import logging
import RPi.GPIO as GPIO

logging.basicConfig(
    filename='logs/drone_dispenser.log',
    format = '%(asctime)s %(levelname)s %(message)s')


async def control_actuator(actuator_queue, sending_queue, relay_pin1, relay_pin2):
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(relay_pin1, GPIO.OUT)
    GPIO.setup(relay_pin2, GPIO.OUT)
    while True:
        try:
            command = await actuator_queue.get()
            print(f"Recieved in Actuator: {command}")
            if command["type"] == "actuator":
                print("Type == actuator")
                if command["data"] == "open":
                    print("data == open")
                    GPIO.output(relay_pin1, GPIO.LOW)
                    GPIO.output(relay_pin2, GPIO.LOW)
                    await asyncio.sleep(15)
                    print("Open Command Recieved and executed")
                    await sending_queue.put({"type": "status_actuator", "data": "Dispenser opened"})
                elif command["data"] == "close":
                    print("data == close")
                    GPIO.output(relay_pin1, GPIO.HIGH)
                    GPIO.output(relay_pin2, GPIO.HIGH)
                    await asyncio.sleep(15)
                    print("Close command received and executed")
                    await sending_queue.put({"type": "status_actuator", "data": "Dispenser closed"})
            actuator_queue.task_done()
        except Exception as e:
            logging.error(f"Error with the actuator: {e}")
            await asyncio.sleep(1)

