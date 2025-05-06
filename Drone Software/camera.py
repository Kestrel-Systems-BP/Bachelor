
import cv2


class Camera:
    def __init__(self, device="/dev/video2", width=1280, height=720):
        self.device = device
        self.width = width
        self.height = height
        self.cap = None

    def initialize(self):
        """Initialize the GStreamer pipeline for the camera"""
        #pipeline = f"v4l2src device={self.device} ! video/x-raw, width={self.width}, height={self.height} ! videoconvert ! appsink"
        #self.cap = cv2.VideoCapture(pipeline, cv2.CAP_GSTREAMER) #Start capture of video
        self.cap = cv2.VideoCapture(0)
        if not self.cap.isOpened():
            raise RuntimeError("Failed to open camera")
            #Throw error if the camera cannot be opened
        return True

    def get_frame(self):
        """Capture a single frame"""
        if not self.cap:
            raise RuntimeError("Camera not initialized")
        ret, frame = self.cap.read()
        if not ret:
            raise RuntimeError("Failed to grab frame")
        return frame

    def release(self):
        """Release the camera"""
        if self.cap:
            self.cap.release()

if __name__ == "__main__":
    try:
        cam = Camera()
        cam.initialize()
        frame = cam.get_frame()
        cv2.imshow("Test Camera", frame)
        cv2.waitKey(0)
        cam.release()
        cv2.destroyAllWindows()
        print("Camera test success")
    except Exception as e:
        print(f"Camera test failed: {e}")
