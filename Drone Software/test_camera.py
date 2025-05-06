#This is a code designed to solely test the camera functionality
#It imports the camera class from the camera.py file

import cv2
from camera import Camera

def test_camera(use_webcam=False, device="/dev/video2"):
    try:
        if use_webcam:
            cam = Camera(device=0)
        else:
            cam = Camera(device=device)
        cam.initialize()
        for _ in range(10):
            frame = cam.get_frame()
            cv2.imshow("Camera test", frame)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
        cam.release()
        cv2.destroyAllWindows()
        print("Camera test passed")
    except Exception as e:
        print(f"Camera test failed: {e}")

if __name__ == '__main__':
    test_camera(use_webcam=True, device="/dev/video2")
