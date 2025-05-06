import cv2
import numpy as np

class ObjectDetector:
    def __init__(self, img_width=1280, img_height=720):
        self.img_center = (img_width // 2, img_height // 2)
        self.min_area = 500
        self.circularity_threshold = 0.7

    def detect(self, frame):
        """Detects red circular object and returns its center and radius"""

        #Gaussian blur is implemented
        frame_blur = cv2.GaussianBlur(frame, (5, 5), 0)

        #Convert to HSV color space
        hsv = cv2.cvtColor(frame_blur, cv2.COLOR_BGR2HSV)

        #Color ranges for detection
        lower_red1 = np.array([0, 120, 70])
        upper_red1 = np.array([10, 255, 255])
        lower_red2 = np.array([170, 120, 70])
        upper_red2 = np.array([180, 255, 255])

        #Using the color ranges to create to separate masks
        #Then combine the two masks into one
        mask1 = cv2.inRange(hsv, lower_red1, upper_red1)
        mask2 = cv2.inRange(hsv, lower_red2, upper_red2)
        mask = cv2.bitwise_or(mask1, mask2)

        #Morphological operations
        kernel = np.ones((5, 5), np.uint8)
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
