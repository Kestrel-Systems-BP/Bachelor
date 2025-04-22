import RPi.GPIO as GPIO
from time import sleep

# Define GPIO pins connected to the relay channels
relay_pins = [20, 26]  # Adjust according to your HAT's pinout

# GPIO setup
GPIO.setmode(GPIO.BCM)
for pin in relay_pins:
    GPIO.setup(pin, GPIO.OUT)
    GPIO.output(pin, GPIO.HIGH)  # Set all relays to OFF initially

def activate_relay(channel):
    print(f"Activating relay {channel}")
    GPIO.output(relay_pins[channel], GPIO.LOW)  # Active low

def deactivate_relay(channel):
    print(f"Deactivating relay {channel}")
    GPIO.output(relay_pins[channel], GPIO.HIGH)  # Deactivate

try:
    while True:
        # Activate relays one by one
        for i in range(len(relay_pins)):
            activate_relay(i)
            sleep(1)  # Wait a second
            deactivate_relay(i)

except KeyboardInterrupt:
    print("Cleaning up GPIO")
    GPIO.cleanup()
