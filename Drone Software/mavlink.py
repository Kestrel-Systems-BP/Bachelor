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
            raise RuntimeError(f"Failed to connect to drone: {e}")

    async def disconnect(self):
