
/*
#include "CustomMission.h"
#include "MissionManager.h"
#include "MissionItem.h"
#include "QGCApplication.h"
#include "QGCLoggingCategory.h"


QGC_LOGGING_CATEGORY(CustomMissionLog, "CustomMissionLog")

CustomMission::CustomMission(QObject* parent)
    : QObject(parent)
{
}

void CustomMission::createAutomaticMission(Vehicle* vehicle, double latitude, double longitude, double altitude)
{
	//check if  a vehicle is connected first
    if (!vehicle) {
        qCWarning(CustomMissionLog) << "createAutomaticMission: No vehicle connected";
        return;
    }
	

    //  check if coords are valid
    if (latitude < -90.0 || latitude > 90.0 || longitude < -180.0 || longitude > 180.0 || altitude <= 0.0) {
        qCWarning(CustomMissionLog) << "createAutomaticMission: Invalid coordinates or altitude";
        return;
    }

    // Get the MissionManager instance for the vehicle
    MissionManager* missionManager = vehicle->missionManager();
    if (!missionManager) {
        qCWarning(CustomMissionLog) << "createAutomaticMission: MissionManager not available";
        return;
    }

    // make sure to clear existing mission
    missionManager->removeAll();

    // Create a list to hold mission items
    QList<MissionItem*> missionItems;

    // 1. Takeoff Command (10m altitude)
    MissionItem* takeoffItem = new MissionItem();
    takeoffItem->setCommand(MAV_CMD_NAV_TAKEOFF);
    takeoffItem->setFrame(MAV_FRAME_GLOBAL_RELATIVE_ALT);
    takeoffItem->setParam1(15.0); // Minimum pitch (default for takeoff)
    takeoffItem->setParam7(10.0); // Takeoff altitude: 10m
    missionItems.append(takeoffItem);

    // 2. Waypoint Command (using provided coordinates)
    MissionItem* waypointItem = new MissionItem();
    waypointItem->setCommand(MAV_CMD_NAV_WAYPOINT);
    waypointItem->setFrame(MAV_FRAME_GLOBAL_RELATIVE_ALT);
    waypointItem->setParam1(0.0);  // Hold time at waypoint (seconds)
    waypointItem->setParam5(latitude);  // Latitude from parameter
    waypointItem->setParam6(longitude); // Longitude from parameter
    waypointItem->setParam7(altitude);  // Altitude from parameter
    missionItems.append(waypointItem);

    // 3. Return-to-Launch (RTL) command
    MissionItem* rtlItem = new MissionItem();
    rtlItem->setCommand(MAV_CMD_NAV_RETURN_TO_LAUNCH);
    rtlItem->setFrame(MAV_FRAME_MISSION);
    missionItems.append(rtlItem);

    // Send the mission items to the vehicle
    missionManager->writeMissionItems(missionItems);

    // Debug to make it visible for operator
    qCDebug(CustomMissionLog) << "Automatic mission success.Latitude:"
                             << latitude << "Longitude:" << longitude << "Altitude:" << altitude;
}
*/


#include "CustomMission.h"
#include "MissionManager.h"
#include "MissionItem.h"
#include "MissionController.h"
#include "SimpleMissionItem.h"
#include "QmlObjectListModel.h"
#include "Vehicle.h"
#include "QGCApplication.h"
#include "QGCLoggingCategory.h"



QGC_LOGGING_CATEGORY(CustomMissionLog, "CustomMissionLog")

CustomMission::CustomMission(QObject* parent)
    : QObject(parent)
{
}




void CustomMission::createAutomaticMission(Vehicle* vehicle, double latitude, double longitude, double altitude)
{
    if (!vehicle) {
        qCWarning(CustomMissionLog) << "No vehicle connected.";
        return;
    }

    if (latitude < -90.0 || latitude > 90.0 || longitude < -180.0 || longitude > 180.0 || altitude <= 0.0) {
        qCWarning(CustomMissionLog) << "Invalid coordinates.";
        return;
    }

    // Create mission controller (Plan View mode)
    MissionController* controller = new MissionController(nullptr);
    controller->start(false); // Not Fly View

    // Insert Takeoff item
    QGeoCoordinate takeoffCoord = vehicle->coordinate();
    if (takeoffCoord.isValid()) {
        controller->insertTakeoffItem(takeoffCoord, controller->visualItems()->count(), true);
    } else {
        qCWarning(CustomMissionLog) << "Invalid vehicle location for takeoff.";
    }

    // Insert Waypoint item
    QGeoCoordinate wpCoord(latitude, longitude, altitude);
    controller->insertSimpleMissionItem(wpCoord, controller->visualItems()->count(), true);

    // Insert Return-to-Launch (RTL) as a MissionItem and wrap in SimpleMissionItem
    MissionItem rtlItem(
        controller->visualItems()->count(),       // sequence number
        MAV_CMD_NAV_RETURN_TO_LAUNCH,             // command
        MAV_FRAME_MISSION,                        // frame
        0, 0, 0, 0,                                // param 1-4
        0, 0, 0,                                   // param 5-7
        true,                                      // autoContinue
        false                                      // isCurrentItem
    );

    SimpleMissionItem* rtl = new SimpleMissionItem(controller->masterController(), false, rtlItem);
    controller->visualItems()->append(rtl);

    // Mark mission as dirty and send to vehicle
    controller->setDirty(true);
    controller->sendToVehicle();

    qCDebug(CustomMissionLog) << "Mission created and sent to vehicle.";
}
