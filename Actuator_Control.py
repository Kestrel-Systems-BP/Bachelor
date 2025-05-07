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
#            print("In the while true loop")
            if command["type"] == "actuator":
                print("Type == actuator")
                if command["data"] == "open":
                    print("data == open")
                    GPIO.output(relay_pin1, GPIO.LOW)
                    GPIO.output(relay_pin2, GPIO.LOW)
                    await asyncio.sleep(15)
                    print("Open Command Recieved and executed")
                    await queue.put({"type": "status_actuator", "data": "Dispenser opened"})
                elif command["data"] == "close":
                    print("data == close")
                    GPIO.output(relay_pin1, GPIO.HIGH)
                    GPIO.output(relay_pin2, GPIO.HIGH)
                    print("Close command received and executed")
                    await queue.put({"type": "status_actuator", "data": "Dispenser closed"})
            queue.task_done()
        except Exception as e:
            logging.error(f"Error with the actuator: {e}")
            await asyncio.sleep(1)

