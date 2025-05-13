import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import asyncio
import mavsdk
from mavlink import MAVLinkConnection

async def test_mavlink():
    print("Starting MAVLink test")
    try:
        mavlink = MAVLinkConnection()
        print("Connecting to drone...")
        await asyncio.wait_for(mavlink.connect(), timeout=5.0)
        print("Waiting for heartbeat...")
        await asyncio.wait_for(mavlink.wait_heartbeat(), timeout=5.0)
        print("MAVLink test successful: Heartbeat received!")
        await mavlink.disconnect()
    except asyncio.TimeoutError:
        print("MAVLink test failed: Timeout waiting for heartbeat")
    except Exception as e:
        print(f"MAVLink test has failed: {e}")

if __name__ == "__main__":
    print("Running test with mavsdk version", mavsdk.__version__)
    asyncio.run(test_mavlink())
