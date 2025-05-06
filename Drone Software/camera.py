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
        self.cap = cv2.VideoCapture(pipeline, cv2.CAP_GSTREAMER)
        if not self.cap.isOpened():
            raise RuntimeError("Failed to initialize camera")
        return True
