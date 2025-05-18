async def main():
    try:
        camera = Camera()
        detector = ObjectDetector()
        mavlink = MAVLinkConnection()
        controller = DroneController(mavlink.drone)

        await mavlink.connect()
        camera.initialize()
        await controller.start_offboard()

        #Main loop: Continous processing of frames and drone control
        while True:
            #Capture a frame from the camera
            frame = camera.get_frame()
            #Detect a person in the frame
            #Return their center and bounding box
            center, bbox, processed_frame = detector.detect(frame)
            #Calculate their offset from frame center
            offset = detector.compute_offset(center)
            if center and bbox:
                #Steer the drone to follow them while maintaing distance and alitude
                await controller.steer(offset, bbox, target_distance=2.0, altitude_target=2.0) #Needs to be adjusted
            else:
                #Hover in place if nobody is detected
                await controller.drone.offboard.set_velocity_ned(VelocityNedYaw(0.0, 0.0, 0.0, 0.0))

    except Exception as e:
        #Handle errors during execution and print them
        print(f"Error in main loop: {e}")
    finally:
        #Ensures resources are properly released
        camera.release()
        await controller.stop_offboard()
