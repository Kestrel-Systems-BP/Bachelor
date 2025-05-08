import asyncio
import logging
import RPi.GPIO as GPIO

logging.basicConfig(
    filename='logs/drone_dispenser.log',
    format='%(asctime)s %(levelname)s %(message)s')

async def control_charging(charging_queue, sending_queue, charging_relay_pin):
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(charging_relay_pin, GPIO.OUT)
    while True:
        try:
            command = await charging_queue.get()
         #   print("In the charging loop")
            if command["type"] == "charging":
                print("type == charging")
                if command["data"] == "start":
                    GPIO.output(charging_relay_pin, GPIO.LOW)
                    await sending_queue.put({"type": "charging_status", "data": "Charging started"})
                    print("Charging started")
                elif command["data"] == "stop":
                    GPIO.output(charging_relay_pin, GPIO.HIGH)
                    await sending_queue.put({"type": "charging_status", "data": "Charging stopped"})
                    print("Charging stopped")
            charging_queue.task_done()
        except Exception as e:
            logging.error(f"Charging error: {e}")
            await asyncio.sleep(1)
