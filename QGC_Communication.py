import socket
from time import sleep
import subprocess
import Adafruit_DHT
import asyncio
import yaml
import logging
import RPi.GPIO as GPIO
from DHT11_control import read_dht11
from Actuator_Control import control_actuator
from Charging_Control import control_charging

# Read the settings file
with open('settings.yaml', 'r') as f:
    config = yaml.safe_load(f)

logging.basicConfig(
    filename=config['logging']['file'],
    format='%(asctime)s %(levelname)s %(message)s')


# global send socket
#send_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

# global receive socket
#recv_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
#recv_socket.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 65536)
#recv_socket.bind(('0.0.0.0', config['udp']['receiving_port']))


async def tcp_sender(sending_queue):
    connections = {}
    send_address = config['tcp']['send_address']
    #Initiate a tcp connection to QGC
    async def get_connection(port):
        if port not in connections or connections[port][1].is_closing():
            try:
                reader, writer = await asyncio.open_connection(send_address, port)
                connections[port] = (reader, writer)
            except Exception as e:
                logging.error(f"Failed to connect on port {port}: {e}")
                return None, None
        return connections[port]

    while True:
        try:
            message = await sending_queue.get()

            #Select address based on type of communication
            if message["type"] == "sensor":
                port = config['tcp']['sensor_port']
            elif message["type"] == "status_actuator":
                port = config['tcp']['actuator_port']
            elif message["type"] == "charging_status":
                port = config['tcp']['charging_port']
            else:
                logging.warning(f"(Unknown message: {message.get('type')}")
                sending_queue.task_done()
                continue
            #Establish or get connection
            reader, writer = await get_connection(port)
            if writer is None:
                logging.error(f"No connection on {port}, deleting message")
                sending_queue.task_done()
                continue

            #Sending the message
            try:
                writer.write((message["data"] + "\n").encode())
                await writer.drain()
            except Exception as e:
                logging.error(f"TCP send error on {port}: {e}")
                writer.close()
                await writer.wait_closed()
                connections.pop(port, None)

            sending_queue.task_done()

        except Exception as e:
            logging.error(f"TCP sender error: {e}")
            await ascyncio.sleep(1)


async def tcp_receiver(actuator_queue, charging_queue):
    async def handle_client(reader, writer):
        addr = writer.get_extra_info('peername')

        while True:
            try:
                #Read until a newline
                data = await reader.readuntil(b"\n")
                if not data:
                    break
                message = data.decode('utf-8').strip().lower()
                #Place message in queue acqording to the data
                if message in ["open", "close"]:
                    await actuator_queue.put({"type": "actuator", "data": message})
                elif message in ["start", "stop"]:
                    await charging_queue.put({"type": "charging", "data": message})
            except asyncio.IncompleteReadError:
                logging.error(f"Connection closed by {addr}")
                break
            except Exception as e:
                logging.error(f"TCP receive error from {addr}: {e}")
                break
        writer.close()
        await writer.wait_closed()
    #Starting the tcp server
    try:
        server = await asyncio.start_server(handle_client, '0.0.0.0', config['tcp']['receiving_port'])
        async with server:
            await server.serve_forever()
    except Exception as e:
        logging.error(f"TCP server error: {e}")

"""
async def udp_receiver(actuator_queue, charging_queue):
#    print("Starting udp_receiver")
    while True:
        try:
            data, addr = await asyncio.get_running_loop().run_in_executor(None, recv_socket.recvfrom, 8192)
            message = data.decode('utf-8').strip().lower()
         #   print("Inside UDP receiver")
            if message in ["open", "close"]:
                print("UDP package received")
                await actuator_queue.put({"type": "actuator", "data": message})
             #   print("After queue.put")
            elif message in ["start", "stop"]:
                await charging_queue.put({"type": "charging", "data": message})
                print("Charging Message Received")
        except Exception as e:
            logging.error(f"Receiving error {e}")
            await asyncio.sleep(1)


async def udp_sender(sending_queue):
#    print("Starting udp_sender")
    while True:
        try:
            message = await sending_queue.get()
            send_address = config['udp']['send_address']

            # Select addres based on type of communication
            if message["type"] == "sensor":
                port = config['udp']['sensor_port']
            elif message["type"] == "status_actuator":
                port = config['udp']['actuator_port']
            elif message["type"] == "charging_status":
                port = config['udp']['charging_port']
            else:
                logging.warning(f"(Unknown message: {message.get('type')}")
                #queue.task_done()
                continue


            send_sock.sendto(message["data"].encode(), (send_address, port))
            sending_queue.task_done()
#            print("Udp sent")
        except Exception as e:
 #           print("exception sending UDP: {e}")
            logging.error(f"Error with UDP sender: {e}")
            await asyncio.sleep(1)
"""
async def main_function():
    print("Starting main fuction")
    actuator_queue = asyncio.Queue()
    charging_queue = asyncio.Queue()
    sending_queue = asyncio.Queue()

    sensor_pin = config['gpio']['dht11_pin']
    actuator_pin1 = config['gpio']['actuator_relay_pin1']
    actuator_pin2 = config['gpio']['actuator_relay_pin2']
    charging_relay_pin = config['gpio']['charging_relay_pin']

    await asyncio.gather(
    read_dht11(sending_queue, sensor_pin),
    control_actuator(actuator_queue, sending_queue, actuator_pin1, actuator_pin2),
#    udp_sender(sending_queue),
#    udp_receiver(actuator_queue, charging_queue),
    tcp_sender(sending_queue),
    tcp_receiver(actuator_queue, charging_queue),
    control_charging(charging_queue, sending_queue, charging_relay_pin)
    )

if __name__ == "__main__":
    try:
        asyncio.run(main_function())
    except KeyboardInterrupt:
        #send_sock.close()
        #recv_socket.close()
        print("Closing after ^C command")
    finally:
        GPIO.cleanup()
