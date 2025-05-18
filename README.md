# Dispenser 

Kestrel Systems drone dispenser, responsible for control of the dispenser and communication with the ground station.

## Important information
- This systems runs on a local network. To communicate between units, make sure everything is on the same network.
- Tailscale can be used to connect all devices 


## Overview 

This system runs on a Rapsberry Pi performing the following tasks: 
 - Communicate with QGroundControl over TCP
 - Control actuator movement with relays 
 - Control charging relay
 - Read and send sensor data 

## File structure 

```plaintext
Kestrel/
├── QGC_Communication.py
├── Actuator_Control.py
├── Charging_Control.py
├── DHT11_Control.py
├── settings.yaml
├── logs/
└── README.md
```

## Requirements 
For testing with a physical setup, the following hardware is needed: 
- Raspberry Pi
- Raspberry Pi Relay HAT
- Electromechanical Actuators
- DHT11 Sensor

The code can be run with only Raspberry Pi and Raspberry Pi Relay HAT for testing.

## Set & run

Clone the repository:

```bash
git clone https://github.com/Kestrel-Systems-BP/Bachelor.git
cd Kestrel
```

Adjust the settings.yaml file 
  - Set the IP address of QGroundControl
  - Set GPIO pins according to physical setup
  - Change port numbers according to ground station configuration

Run the system: 

```bash
python3 QGC_Communication.py
```
