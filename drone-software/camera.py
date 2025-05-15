import cv2

class Camera:
    def __init__(self, device="/dev/video2", width=1280, height=720):
        self.device = device
        self.width = width
        self.height = height
        self.cap = None

    def initialize(self):
        rtsp_url = "rtsp://127.0.0.1:8904/live"
        self.cap = cv2.VideoCapture(rtsp_url, cv2.CAP_FFMPEG)
        if not self.cap.isOpened():
            raise RuntimeError("Failed to open RTSP stream")
        return True

    def get_frame(self):
        """Capture a frame"""
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
        print("Camera test success")
    except Exception as e:
        print(f"Camera test failed: {e}")
