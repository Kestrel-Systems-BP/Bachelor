from ultralytics import YOLO
import cv2
import numpy as np

class ObjectDetector:
    def __init__(self, img_width=1280, img_height=720):
        self.img_center = (img_width // 2, img_height // 2)
        self.model = YOLO('yolov8n.pt') #Load the pretrained YOLOv8 nano model for object detection

    def detect(self, frame):
        # Detect a person in the input frame and draw a bounding box around them
        # Arguments:
        #   frame: Input image (BGR format from OpenCV)
        # Returns:
        #   center: Tuple (x, y) of the detected person's center, or None if not detected
        #   bbox: Tuple (x1, y1, x2, y2) of the bounding box coordinates, or None if not detected
        #   processed_frame: Copy of the input frame with bounding box drawn (if detected)
        results = self.model(frame)
        processed_frame = frame.copy()
        center, bbox = None, None
        for result in results:
            for box in result.boxes:
                if int(box.cls) == 0:  # Person class (ID = 0) in YOLO
                    x1, y1, x2, y2 = map(int, box.xyxy[0])
                    #Calculate center of bounding box
                    center = ((x1 + x2) // 2, (y1 + y2) // 2)
                    bbox = (x1, y1, x2, y2)
                    #Draw green rectangle around identified person
                    cv2.rectangle(processed_frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
                    break
            if center:
                break
        return center, bbox, processed_frame

    def compute_offset(self, center):
        # Calculate the pixel offset of the detected person's center from the image center.
        # Arguments:
        #   center: Tuple (x, y) of the detected person's center.
        # Returns:
        #   Tuple (dx, dy) representing the offset in pixels, or None if no center is provided.
        if center is None:
            return None
        return (center[0] - self.img_center[0], center[1] - self.img_center[1])
