import asyncio
from mavsdk import System

class MAVLinkConnection:
    def __init__(self, connection_str="udp://:14550"):
        self.drone = System()
        self.connection_str = connection_str

    async def connect(self):
        """Connect to the PX4 Autopilot"""
        print(f"Attempting connection to {self.connection_str}")
        try:
            await self.drone.connect(system_address=self.connection_str)
            print("Connected to drone")
        except Exception as e:
            print(f"Connection failed: {e}")
            raise RuntimeError(f"Connection failed: {e}")

        async def wait_heartbea(self):
            """Wait for a heartbeat from the drone"""
            print("Waiting for heartbeat")
            async for state in self.drone.core.connection_state():
                if state.is_connected:
                    print("Heartbeat received")
                    return
            print("No heartbeat received")
            raise RuntimeError("No heartbeat received")

    async def disconnect(self):
        """Disconnect and disarm the drone"""
        print("Disconnecting")
        self.drone = None
        print("Disconnected")

if __name__ == "__main__":
    async def test_mavlink():
        print("Testing MAVLinkConnection")
        try:
            mavlink = MAVLinkConnection()
            await mavlink.connect()
            await mavlink.wait_heartbeat()
            print("MAVLink test successful")
            await asyncio.sleep(2)
            #Needs a pause to observe the connection
            await mavlink.disconnect()
        except Exception as e:
            print(f"MAVLink failed test: {e}")

    asyncio.run(test_mavlink)
