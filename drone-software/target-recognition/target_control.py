import asyncio
from mavsdk.offboard import OffboardError, VelocityNedYaw

class DroneController:
    def __init__(self, drone, pixel_to_meter=0.001, kp=0.5, max_velocity=1.0):
        # Initialize controller with drone instance and control parameters
        # Arguments:
        #   drone: MAVSDK drone object for sending commands
        #   pixel_to_meter: Conversion factor from pixels to meters for control calculations
        #   kp: Proportional gain for the control loop
        #   max_velocity: Maximum allowed velocity for the drone (m/s)
        self.drone = drone
        self.pixel_to_meter = pixel_to_meter
        self.kp = kp
        self.max_velocity = max_velocity

    def compute_distance(self, bbox, reference_width=200, reference_distance=2.0):
        # Estimate the distance to the detected person based on bounding box width
        # Arguments:
        #   bbox: Tuple (x1, y1, x2, y2) of bounding box coordinates
        #   reference_width: Reference bounding box width (pixels) at reference_distance
        #   reference_distance: Known distance (meters) corresponding to reference_width
        # Returns:
        #   Estimated distance (meters) to the person, or None if bbox is invalid
        if bbox is None:
            return None
        x1, y1, x2, y2 = bbox
        bbox_width = x2 - x1
        return (reference_width / bbox_width) * reference_distance

    async def steer(self, offset, bbox, target_distance=2.0, altitude_target=2.0):
        # Steer the drone to follow the detected person based on offset and distance
        # Arguments:
        #   offset: Tuple (dx, dy) of pixel offsets from image center
        #   bbox: Tuple (x1, y1, x2, y2) of bounding box coordinates
        #   target_distance: Desired distance to maintain from the person (meters)
        #   altitude_target: Desired altitude to maintain (meters)
        if offset is None or bbox is None:
            return
        dx, dy = offset
        distance = self.compute_distance(bbox) #Estimate distance to target
        if distance:
            distance_error = distance - target_distance
            vx = self.kp * dx * self.pixel_to_meter + self.kp * distance_error
        else:
            vx = self.kp * dx * self.pixel_to_meter
        vy = -self.kp * dy * self.pixel_to_meter
        async for alt in self.drone.telemetry.position():
            vz = -self.kp * (alt.relative_altitude_m - altitude_target)
            break
        yaw = 0.0
        try:
            await self.drone.offboard.set_velocity_ned(VelocityNedYaw(vx, vy, vz, yaw))
        except OffboardError as e:
            print(f"Failed to set velocity: {e}")
            raise

    # Other methods (start_offboard, land, stop_offboard) remain unchanged
