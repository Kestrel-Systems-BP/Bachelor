import cv2
import numpy as np
import time
import asyncio
import sys
from mavsdk import System
from mavsdk.offboard import OffboardError, PositionNewYaw
import voxl #VOXL Camera API

#Initialize the MAVSDK connection to PX4
async def main():

    if sys.version_info < (3.8):
        print("Python 3.8 or higher required.")
        return


    drone = System()
    try:
        await drone.connect(system_address="udp://8900")
    except Exception as e:
        print(f"Failed to connect to drone: {e}")
        return

    print("Waiting for drone to connect...")
    async for state in drone.core.connection_state():
        if state.is_connected:
            print("Drone connected!")
            break

    #Initialize the camera
    cap = cv2.VideoCapture("v4l2src device=/dev/video2 ! videoconvert ! appsink", cv2.CAP_GSTREAMER)
    if not cap.isOpened():
        print("Failed to access camera")
        await drone.action.disarm()
        return

    #Image center and threshold
    img_center = (1280 // 2, 720 // 2)
    center_threshold = 50
    centered_start_time = None
    centered_duration = 1.0

    #Pixel to meter conversion
    pixel_to_meter = 0.001

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                print("Failed to grab frame")
                break

        #Gaussian blur is a mathematical function that blurs images
        #Blurring the image will help reduce noise
        #https://docs.opencv.org/4.x/d4/d86/group__imgproc__filter.html#gae8bdcd9154ed5ca3cbc1766d960f45c1
            frame_blur = cv2.GaussianBlur(frame, (5, 5), 0)

        #Convert to HSV for color detection
            hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)

        #The color ranges will be divided in two
            lower_red1 = np.array([0, 120, 70])
            upper_red1 = np.array([10, 255, 255])
            lower_red2 = np.array([170, 120, 70])
            upper_red2 = np.array([180, 255, 255])

        #Since there are now two color ranges, there needs to be created two masks
        #These masks are then combined into one
            mask1 = cv2.inRange(hsv, lower_red1, upper_red1)
            mask2 = cv2.inRange(hsv, lower_red2, upper_red2)
            mask = cv2.bitwise_or(mask1, mask2)

        #Morphological operations
        #description later
            kernel = np.ones((5, 5), np.uint8)
            mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
            mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)

        #Find contours
            contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            object_detected = False

            if contours:
                for contour in contours:
                    area = cv2.contourArea(contour)
                    if area < 500:
                        continue
                    perimeter = cv2.arcLength(contour, True)
                    if perimeter == 0:
                        continue
                    circularity = 4 * np.pi * area / (perimeter * perimeter)
                    if circularity > 0.7:
                        ((x,y), radius) = cv2.minEnclosingCircle(contour)
                        center = int(x), int(y)
                        print(f"Detected landing pad at center: {center}, radius {radius}")

                        cv2.circle(frame, center, int(radius), (0, 255, 0), 2)
                        object_detected = True

                        dx = (center[0] - img_center[0]) * pixel_to_meter
                        dy = (center[1] - img_center[1]) * pixel_to_meter
                        dz = 0.0

                        try:
                            await drone.offboard.set_position_ned(PositionNedYaw(dx, dy, dz, 0.0))
                        except OffboardError as e:
                            print(f"Failed to set position: {e}")


                        distance = np.sqrt((center[0] - img_center[0])**2 + (center[1] - img_center[1])**2)
                        if distance < center_threshold:
                            if centered_start_time is None:
                                centered_start_time = time.time()
                            elif time.time() - centered_start_time >= centered_duration:
                                print("Object is in the center of the frame! Initiate landing!")
                                try:
                                    await drone.action.land()
                                    print("Landing initiated")
                                    break
                                except Exception as e:
                                    print(f"Failed to initiate landing: {e}")
                                    break
                            else:
                                centered_start_time = None
                            break

                if not object_detected:
                    centered_start_time = None

            # Display camera feed in window
                cv2.imshow('Webcam Feed', frame)

      # Break the loop when 'q' is pressed
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break

    except Exception as e:
        print(f"Error in main loop: {e}")
    finally:
        cap.release()
        cv2.destroyAllWindows()
        try:
            await drone.action.disarm()
        except Exception as e:
            print(f"Failed to disarm: {e}")



if __name__ == "__main__":
    try:
        asyncio.run(main())
    except RuntimeError as e:
        print(f"Event loop error: {e}")
        print("Ensure no other event loop is running, or use asyncio.get_event_loop()")
