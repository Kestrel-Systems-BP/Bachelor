#Sources:
#https://stackoverflow.com/questions/73973989/colour-calibration-in-hsv-colour-space (02.05.2025)
#https://github.com/abhisavaliya/hsv_calibration/blob/master/hsv_calibration/hsv_calibration.py (02.05.2025)

#This code is solely for calibrating HSV
#It allows for real-time adjustments in HSV settings
#Tests should be done under dynamic conditions for optimilization
#H = Hue (color)
#S = Saturation (color purity)
#V = Value (intensity)

import cv2
import numpy as np


#OpenCV requires a callback function for the trackbars to handle changes
def nothing(x):
    #The function is simply a placeholder that does nothing
    #cv2.createTrackbar expects a callback, and this satifies that requirement without adding any unnecessary logic
    pass

#Opens a window with track bars to adjust each value individually
cv2.namedWindow('Trackbars')

#Hue value ranges from 0 - 179 in OpenCV
cv2.createTrackbar('H Min', 'Trackbars', 0, 179, nothing)
cv2.createTrackbar('H Max', 'Trackbars', 179, 179, nothing)

#Saturation and value both range from 0 - 255
cv2.createTrackbar('S Min', 'Trackbars', 0, 255, nothing)
cv2.createTrackbar('S Max', 'Trackbars', 255, 255, nothing)
cv2.createTrackbar('V Min', 'Trackbars', 0, 255, nothing)
cv2.createTrackbar('V Max', 'Trackbars', 255, 255, nothing)

#Initiates camera
cap = cv2.VideoCapture(0)

#Continuously captures input from the camera
while True:
    ret, frame = cap.read()
    if not ret:
        break
        #If no frame can be captured, the loop will break to avoid errors

    #Frames are converted from BGR (Blue, Green, Red) to HSV
    #HSV separates color (hue) from intensity (value) and the color purity (saturation)
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)

    #Reads of current positions of the trackbars
    h_min = cv2.getTrackbarPos('H Min', 'Trackbars')
    h_max = cv2.getTrackbarPos('H Max', 'Trackbars')
    s_min = cv2.getTrackbarPos('S Min', 'Trackbars')
    s_max = cv2.getTrackbarPos('S Max', 'Trackbars')
    v_min = cv2.getTrackbarPos('V Min', 'Trackbars')
    v_max = cv2.getTrackbarPos('V Max', 'Trackbars')

    #Creates two arrays that represents that represents the upper and lower bounds of HSV range
    lower = np.array([h_min, s_min, v_min])
    upper = np.array([h_max, s_max, v_max])

    #Creates a binary mask to set pixels within the range (lower, upper) to white (255)
    #Pixels outside of the range are set to black (0)
    mask = cv2.inRange(hsv, lower, upper)

    #Displays window for the video feed with binary mask added
    cv2.imshow('Mask', mask)
    #Displays window for the original video feed
    cv2.imshow('Frame', frame)


    #Program closes when 'q' is pressed on the keyboard.
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break
cap.release()
cv2.destroyAllWindows()
