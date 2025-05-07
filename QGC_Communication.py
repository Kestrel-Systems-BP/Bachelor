import socket
from time import sleep
import subprocess
import Adafruit_DHT
import asyncio
import yaml
import logging
from DHT11_control import read_dht11
from Actuator_Control import control_actuator

# Read the settings file
with open('settings.yaml', 'r') as f:
    config = yaml.safe_load(f)

logging.basicConfig(
    filename=config['logging']['file'],
    format='%(asctime)s %(levelname)s %(message)s')


# global send socket
send_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

# global receive socket
recv_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
recv_socket.bind(('0.0.0.0', config['udp']['receiving_port']))


async def udp_receiver(queue):
    print("Starting udp_receiver")
    while True:
        try:
            data, addr = await asyncio.get_running_loop().run_in_executor(None, recv_socket.recvfrom, 1024)
            message = data.decode('utf-8').strip().lower()
            print("Inside UDP receiver")
            if message in ["open", "close"]:
                print("UDP package received")
                await queue.put({"type": "actuator", "data": message})
                print("After queue.put")
            elif message in ["starting"]:
                print("other message")
        except Exception as e:
            logging.error(f"Receiving error {e}")
            await asyncio.sleep(1)


async def udp_sender(queue):
    print("Starting udp_sender")
    while True:
        try:
            message = await queue.get()
            send_address = config['udp']['send_address']

            # Select addres based on type of communication
            if message["type"] == "sensor":
                port = config['udp']['sensor_port']
            elif message["type"] == "status_actuator":
                port = config['udp']['actuator_port']
    #        elif message["type"] == "charging_status":
     #           port = config['udp']['charging_port']
            else:
                logging.warning(f"(Unknown message: {message.get('type')}")
                queue.task_done()
                continue


            send_sock.sendto(message["data"].encode(), (send_address, port))
            queue.task_done()
#            print("Udp sent")
        except Exception as e:
 #           print("exception sending UDP: {e}")
            logging.error(f"Error with UDP sender: {e}")
            await asyncio.sleep(1)

async def main_function():
#    print("Starting main fuction")
    queue = asyncio.Queue()

    sensor_pin = config['gpio']['dht11_pin']
    actuator_pin1 = config['gpio']['actuator_relay_pin1']
    actuator_pin2 = config['gpio']['actuator_relay_pin2']

    await asyncio.gather(
    read_dht11(queue, sensor_pin),
    control_actuator(queue, actuator_pin1, actuator_pin2),
    udp_sender(queue),
    udp_receiver(queue)
    )

if __name__ == "__main__":
    try:
        asyncio.run(main_function())
    except KeyboardInterrupt:
        send_sock.close()
        recv_socket.close()
