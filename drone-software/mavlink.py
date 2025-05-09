import asyncio
from mavsdk import System

class MAVLinkConnection:
    def __init__(self, address="udp://:14540"):
        self.address = address
        self.drone = System()
        self.connected = False

    async def connect(self):
        """Connect to the PX4 Autopilot"""
        try:
            await self.drone.connect(system_address=self.address)
            async for state in self.drone.core.connection_state():
                if state.is_connected:
                    self.connected = True
                    print("Drone connected")
                    break
        except Exception as e:
            raise RuntimeError(f"Drone failed to connect: {e}")

    async def disconnect(self):
        """Disconnect and disarm the drone"""
        if self.connected:
            try:
                await self.drone.action.disarm()
            except Exception as e:
                print(f"Failed to disarm: {e}")
            self.connected = False

if __name__ == "__main__":
    async def test_mavlink():
        try:
            mavlink = MAVLinkConnection()
            await mavlink.connect()
            await asyncio.sleep(2)
            #Needs a pause to observe the connection
            await mavlink.disconnect()
            print("MAVLink successfully tested")
        except Exception as e:
            print(f"MAVLink failed test: {e}")

    asyncio.run(test_mavlink)
