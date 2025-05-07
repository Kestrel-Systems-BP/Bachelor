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

        #Find the contours
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        for contour in contours:
            area = cv2.contourArea(contour)
            if area < self.min_area:
                continue
            perimeter = cv2.arcLength(contour, True)
            if perimeter == 0:
                continue
            circularity = 4 * np.pi * area / (perimeter * perimeter)
            if circularity > self.circularity_threshold:
                ((x, y), radius) = cv2.minEnclosingCircle(contour)
                center = (int(x), int(y))
                cv2.circle(frame, center, int(radius), (0, 255, 0), 2) #Marks identified circle with a green circle
                return center, radius, frame
        return None, None, frame

def compute_offset(self, center):
    """Compute pixel offset from frame center"""
    if center is None:
        return None
    return (center[0] - self.img_center[0], center[1] - self.img_center[1])

if __name__ == "__main__":
    try:
        detector = ObjectDetector()
        frame = cv2.imread("C:/Users/eirik/Documents/GitHub/Bachelor/Drone Software/testimage.jpg")
        if frame is None:
            raise RuntimeError("Failed to load test image")
        center, radius, processed_frame = detector.detect(frame)
        if center:
            offset = detector.compute_offset(center)
            print(f"Detected center: {center}, radius: {radius}, offset: {offset}")
            cv2.imshow("Detection test", processed_frame)
            cv2.waitKey(0)
            cv2.destroyAllWindows()
        else:
            print("No object detected")
    except Exception as e:
        print(f"Detection test failed: {e}")
