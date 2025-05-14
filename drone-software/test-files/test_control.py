import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import asyncio
from mavlink import MAVLinkConnection
from control import DroneController

async def test_control():
    try:
        #Establish connection with the drone
        mavlink = MAVLinkConnection()
        await mavlink.connect()
        controller = DroneController(mavlink.drone)

        #Test offboard mode
        await controller.start_offboard()

        #Test steering
        sample_offset = (100, 50)
        await controller.steer(sample_offset)
        await asyncio.sleep(2)

        #Test hovering
        await controller.steer(None)
        await asyncio.sleep(2)

        await controller.stop()
        print("Control test passed")
    except Exception as e:
        print(f"Control test failed: {e}")

if __name__ == "__main__":
    asyncio.run(test_control())
