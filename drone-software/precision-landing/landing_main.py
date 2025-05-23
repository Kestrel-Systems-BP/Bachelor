import asyncio
import cv2
import sys
import time
from camera import Camera
from landing_detection import ObjectDetector
from mavlink import MAVLinkConnection
from landing_control import DroneController

async def main():
    if sys.version_info < (3.8):
        print("Error: Update to newer python version")
        return

    #Initialize the other programs
    try:
        camera = Camera()
        detector = ObjectDetector()
        mavlink = MAVLinkConnection()
        controller = DroneController(mavlink.drone)

        #Connect with the drone
        await mavlink.connect()

        #Initialize the camera
        camera.initialize()

        #Start offboard mode
        await controller.start_offboard()


        #Main loop
        center_threshold = 50
        centered_start_time = None
        centered_duration = 1.0

        while True:
            #Capture frame
            frame = camera.get_frame()

            #Detect the object
            center, radius, processed_frame = detector.detect(frame)
            offset = detector.compute_offset(center)

            #Control drone
            await controller.steer(offset)

            #Check if the object is centered
            if center:
                distance = ((center[0] - detector.img_center[0])**2 + (center[1] - detector.img_center[1])**2) ** 0.5
                if distance < center_threshold:
                    print("Second IF-loop")
                    if centered_start_time is None:
                        print("Third IF-loop")
                        centered_start_time = time.time()
                    elif time.time() - centered_start_time >= centered_duration:
                        print("Object is centered, initiating landing!")
                        await controller.land()
                        break
                else:
                    centered_start_time = None
            else:
                centered_start_time = None

            await asyncio.sleep(0.01)

    except Exception as e:
        print(f"Error in main loop: {e}")
    finally:
        #Clean up processes
        camera.release()
        await controller.stop_offboard()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except RuntimeError as e:
        print(f"Event loop error: {e}")
