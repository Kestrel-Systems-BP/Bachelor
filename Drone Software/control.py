import asyncio
from mavsdk.offboard import (OffboardError, VelocityNedYaw, PositionNedYaw)

class DroneController:
    def __init__(self, drone, pixel_to_meter=0.001, kp=0.5, max_velocity=1.0):
        self.drone = drone
        self.pixel_to_meter = pixel_to_meter
        self.kp = kp
        self.max_velocity = max_velocity

    async def start_offboard(self):
        """Enable OFFBOARD Mode"""
        try:
            await self.drone.offboard.set_velocity_ned(VelocityNedYaw(0.0, 0.0, 0.0, 0.0))
            await self.drone.offboard.start()
            print("Enabled OFFBOARD mode")
        exception OffboardError as e:

