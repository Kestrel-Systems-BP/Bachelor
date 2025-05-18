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
        except OffboardError as e:
            print(f"Failed to engage offboard: {e}")
            raise

    async def steer(self, offset):
        """Manoveur the drone based on image input"""
        if offset is None:
            return
        dx, dy = offset
        #Velocity will be proportional of offset
        vx = self.kp * dx
        vy = -self.kp * dy
        vz = 0.0
        yaw = 0.0
        try:
            await self.drone.offboard.set_velocity_ned(VelocityNedYaw(vx, vy, vz, yaw))
        except OffboardError as e:
            print(f"Failed to set velocity: {e}")
            raise

    async def land(self):
        """Perform landing manevour"""
        try:
            await self.drone.action.land()
            print("Landing procedure initiated")
        except Exception as e:
            print(f"Failed to perform landing: {e}")
            raise

    async def stop_offboard(self):
        """Stop offboard mode"""
        try:
            await self.drone.offboard.stop()
            print("Offboard mode stopped")
        except OffboardError as e:
            print(f"Failed to stop offboard: {e}")
            raise

if __name__ == "__main__":
    #Needs to be connected with drone to function
    print("Control module test requires a drone connection. Run with main.py or test_control.py.")

