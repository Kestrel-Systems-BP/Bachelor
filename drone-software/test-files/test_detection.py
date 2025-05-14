import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import cv2
from detection import ObjectDetector

def test_detection(image_path):
    try:
        detector = ObjectDetector()
        frame = cv2.imread(image_path)
        if frame is None:
            raise RuntimeError(f"Failed to load image: {image_path}")
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

if __name__ == "__main__":
    test_detection("C:/Users/eirik/Documents/GitHub/Bachelor/Drone Software/testimage.jpg")
