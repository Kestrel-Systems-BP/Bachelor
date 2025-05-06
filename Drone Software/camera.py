import cv2

class Camera:
    def __init__(self, device="/dev/video2", width=1280, height=720):
        self.device = device
        self.width = width
        self.height = height
        self.cap = None

    def initialize(self):
        """Initialize the GStreamer pipeline for the camera"""
        pipeline = f"v4l2src device={self.device} ! video/x-raw, width={self.width}, height={self.height} ! videoconvert ! appsink"
        self.cap = cv2.VideoCapture(pipeline, cv2.CAP_GSTREAMER) #Start capture of video
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
