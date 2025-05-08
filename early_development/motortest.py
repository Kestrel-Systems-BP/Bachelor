from time import sleep
import RPi.GPIO as gpio

direction_pin   = 20
pulse_pin       = 26
cw_direction    = 0
ccw_direction   = 1

gpio.setmode(gpio.BCM)
gpio.setup(direction_pin, gpio.OUT)
gpio.setup(pulse_pin, gpio.OUT)
gpio.output(direction_pin,cw_direction)


try:
    while True:
        print("Extend the actuator")
        sleep(.5)
        gpio.output(direction_pin,ccw_direction)
        for x in range(4000):
            gpio.output(pulse_pin,gpio.LOW)
            sleep(.001)
            gpio.output(pulse_pin,gpio.LOW)
            #sleep(.0005)
            sleep(15)
        print("Retract the actuator")
        sleep(.5)
        gpio.output(direction_pin,cw_direction)
        for x in range(4000):
            gpio.output(pulse_pin,gpio.HIGH)
            sleep(.001)
            gpio.output(pulse_pin,gpio.HIGH)
            sleep(.0005)

except KeyboardInterrupt:
    gpio.cleanup()

