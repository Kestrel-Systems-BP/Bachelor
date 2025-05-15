/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/
//kest

#include "MissionItem.h"
#include "QGCApplication.h" //test
#include "SimpleMissionItem.h"
#include "Vehicle.h"
#include "VehicleBatteryFactGroup.h"
#include <mavlink.h>
#include "Vehicle.h"
#include "Fact.h"
#include "QmlObjectListModel.h"




//
#include "PlanMasterController.h"
#include "QGCApplication.h"
#include "QGCCorePlugin.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"
#include "SettingsManager.h"
#include "AppSettings.h"
#include "JsonHelper.h"
#include "MissionManager.h"
#include "KMLPlanDomDocument.h"
#include "SurveyPlanCreator.h"
#include "StructureScanPlanCreator.h"
#include "CorridorScanPlanCreator.h"
#include "BlankPlanCreator.h"
#include "QmlObjectListModel.h"
#include "GeoFenceManager.h"
#include "RallyPointManager.h"
#include "QGCLoggingCategory.h"



#include <QtCore/QJsonDocument>
#include <QtCore/QFileInfo>

QGC_LOGGING_CATEGORY(PlanMasterControllerLog, "PlanMasterControllerLog")

PlanMasterController::PlanMasterController(QObject* parent)
    : QObject               (parent)
    , _multiVehicleMgr      (MultiVehicleManager::instance())
    , _controllerVehicle    (new Vehicle(Vehicle::MAV_AUTOPILOT_TRACK, Vehicle::MAV_TYPE_TRACK, this))
    , _managerVehicle       (_controllerVehicle)
    , _missionController    (this)
    , _geoFenceController   (this)
    , _rallyPointController (this)
{
    _commonInit();
}

#ifdef QT_DEBUG
PlanMasterController::PlanMasterController(MAV_AUTOPILOT firmwareType, MAV_TYPE vehicleType, QObject* parent)
    : QObject               (parent)
    , _multiVehicleMgr      (MultiVehicleManager::instance())
    , _controllerVehicle    (new Vehicle(firmwareType, vehicleType))
    , _managerVehicle       (_controllerVehicle)
    , _missionController    (this)
    , _geoFenceController   (this)
    , _rallyPointController (this)
{
    _commonInit();
}
#endif

void PlanMasterController::_commonInit(void)
{
    connect(&_missionController,    &MissionController::dirtyChanged,               this, &PlanMasterController::dirtyChanged);
    connect(&_geoFenceController,   &GeoFenceController::dirtyChanged,              this, &PlanMasterController::dirtyChanged);
    connect(&_rallyPointController, &RallyPointController::dirtyChanged,            this, &PlanMasterController::dirtyChanged);

    connect(&_missionController,    &MissionController::containsItemsChanged,       this, &PlanMasterController::containsItemsChanged);
    connect(&_geoFenceController,   &GeoFenceController::containsItemsChanged,      this, &PlanMasterController::containsItemsChanged);
    connect(&_rallyPointController, &RallyPointController::containsItemsChanged,    this, &PlanMasterController::containsItemsChanged);

    connect(&_missionController,    &MissionController::syncInProgressChanged,      this, &PlanMasterController::syncInProgressChanged);
    connect(&_geoFenceController,   &GeoFenceController::syncInProgressChanged,     this, &PlanMasterController::syncInProgressChanged);
    connect(&_rallyPointController, &RallyPointController::syncInProgressChanged,   this, &PlanMasterController::syncInProgressChanged);

    // Offline vehicle can change firmware/vehicle type
    connect(_controllerVehicle,     &Vehicle::vehicleTypeChanged,                   this, &PlanMasterController::_updatePlanCreatorsList);
}


PlanMasterController::~PlanMasterController()
{

}

void PlanMasterController::start(void)
{
    _missionController.start    (_flyView);
    _geoFenceController.start   (_flyView);
    _rallyPointController.start (_flyView);

    _activeVehicleChanged(_multiVehicleMgr->activeVehicle());
    connect(_multiVehicleMgr, &MultiVehicleManager::activeVehicleChanged, this, &PlanMasterController::_activeVehicleChanged);

    _updatePlanCreatorsList();
}

void PlanMasterController::startStaticActiveVehicle(Vehicle* vehicle, bool deleteWhenSendCompleted)
{
    _flyView = true;
    _deleteWhenSendCompleted = deleteWhenSendCompleted;
    _missionController.start(_flyView);
    _geoFenceController.start(_flyView);
    _rallyPointController.start(_flyView);
    _activeVehicleChanged(vehicle);
}

void PlanMasterController::_activeVehicleChanged(Vehicle* activeVehicle)
{
    if (_managerVehicle == activeVehicle) {
        // We are already setup for this vehicle
        return;
    }

    qCDebug(PlanMasterControllerLog) << "_activeVehicleChanged" << activeVehicle;

    if (_managerVehicle) {
        // Disconnect old vehicle. Be careful of wildcarding disconnect too much since _managerVehicle may equal _controllerVehicle
        disconnect(_managerVehicle->missionManager(),       nullptr, this, nullptr);
        disconnect(_managerVehicle->geoFenceManager(),      nullptr, this, nullptr);
        disconnect(_managerVehicle->rallyPointManager(),    nullptr, this, nullptr);
    }

    bool newOffline = false;
    if (activeVehicle == nullptr) {
        // Since there is no longer an active vehicle we use the offline controller vehicle as the manager vehicle
        _managerVehicle = _controllerVehicle;
        newOffline = true;
    } else {
        newOffline = false;
        _managerVehicle = activeVehicle;

        // Update controllerVehicle to the currently connected vehicle
        AppSettings* appSettings = SettingsManager::instance()->appSettings();
        appSettings->offlineEditingFirmwareClass()->setRawValue(QGCMAVLink::firmwareClass(_managerVehicle->firmwareType()));
        appSettings->offlineEditingVehicleClass()->setRawValue(QGCMAVLink::vehicleClass(_managerVehicle->vehicleType()));

        // We use these signals to sequence upload and download to the multiple controller/managers
        connect(_managerVehicle->missionManager(),      &MissionManager::newMissionItemsAvailable,  this, &PlanMasterController::_loadMissionComplete);
        connect(_managerVehicle->geoFenceManager(),     &GeoFenceManager::loadComplete,             this, &PlanMasterController::_loadGeoFenceComplete);
        connect(_managerVehicle->rallyPointManager(),   &RallyPointManager::loadComplete,           this, &PlanMasterController::_loadRallyPointsComplete);
        connect(_managerVehicle->missionManager(),      &MissionManager::sendComplete,              this, &PlanMasterController::_sendMissionComplete);
        connect(_managerVehicle->geoFenceManager(),     &GeoFenceManager::sendComplete,             this, &PlanMasterController::_sendGeoFenceComplete);
        connect(_managerVehicle->rallyPointManager(),   &RallyPointManager::sendComplete,           this, &PlanMasterController::_sendRallyPointsComplete);
    }

    _offline = newOffline;
    emit offlineChanged(offline());
    emit managerVehicleChanged(_managerVehicle);

    if (_flyView) {
        // We are in the Fly View
        if (newOffline) {
            // No active vehicle, clear mission
            qCDebug(PlanMasterControllerLog) << "_activeVehicleChanged: Fly View - No active vehicle, clearing stale plan";
            removeAll();
        } else {
            // Fly view has changed to a new active vehicle, update to show correct mission
            qCDebug(PlanMasterControllerLog) << "_activeVehicleChanged: Fly View - New active vehicle, loading new plan from manager vehicle";
            _showPlanFromManagerVehicle();
        }
    } else {
        // We are in the Plan view.
        if (containsItems()) {
            // The plan view has a stale plan in it
            if (dirty()) {
                // Plan is dirty, the user must decide what to do in all cases
                qCDebug(PlanMasterControllerLog) << "_activeVehicleChanged: Plan View - Previous dirty plan exists, no new active vehicle, sending promptForPlanUsageOnVehicleChange signal";
                emit promptForPlanUsageOnVehicleChange();
            } else {
                // Plan is not dirty
                if (newOffline) {
                    // The active vehicle went away with no new active vehicle
                    qCDebug(PlanMasterControllerLog) << "_activeVehicleChanged: Plan View - Previous clean plan exists, no new active vehicle, clear stale plan";
                    removeAll();
                } else {
                    // We are transitioning from one active vehicle to another. Show the plan from the new vehicle.
                    qCDebug(PlanMasterControllerLog) << "_activeVehicleChanged: Plan View - Previous clean plan exists, new active vehicle, loading from new manager vehicle";
                    _showPlanFromManagerVehicle();
                }
            }
        } else {
            // There is no previous Plan in the view
            if (newOffline) {
                // Nothing special to do in this case
                qCDebug(PlanMasterControllerLog) << "_activeVehicleChanged: Plan View - No previous plan, no longer connected to vehicle, nothing to do";
            } else {
                // Just show the plan from the new vehicle
                qCDebug(PlanMasterControllerLog) << "_activeVehicleChanged: Plan View - No previous plan, new active vehicle, loading from new manager vehicle";
                _showPlanFromManagerVehicle();
            }
        }
    }

    // Vehicle changed so we need to signal everything
    emit containsItemsChanged(containsItems());
    emit syncInProgressChanged();
    emit dirtyChanged(dirty());

    _updatePlanCreatorsList();
}

void PlanMasterController::loadFromVehicle(void)
{
    SharedLinkInterfacePtr sharedLink = _managerVehicle->vehicleLinkManager()->primaryLink().lock();
    if (sharedLink) {
        if (sharedLink->linkConfiguration()->isHighLatency()) {
            qgcApp()->showAppMessage(tr("Download not supported on high latency links."));
            return;
        }
    } else {
        // Vehicle is shutting down
        return;
    }

    if (offline()) {
        qCWarning(PlanMasterControllerLog) << "PlanMasterController::loadFromVehicle called while offline";
    } else if (_flyView) {
        qCWarning(PlanMasterControllerLog) << "PlanMasterController::loadFromVehicle called from Fly view";
    } else if (syncInProgress()) {
        qCWarning(PlanMasterControllerLog) << "PlanMasterController::loadFromVehicle called while syncInProgress";
    } else {
        _loadGeoFence = true;
        qCDebug(PlanMasterControllerLog) << "PlanMasterController::loadFromVehicle calling _missionController.loadFromVehicle";
        _missionController.loadFromVehicle();
        setDirty(false);
    }
}


void PlanMasterController::_loadMissionComplete(void)
{
    if (!_flyView && _loadGeoFence) {
        _loadGeoFence = false;
        _loadRallyPoints = true;
        if (_geoFenceController.supported()) {
            qCDebug(PlanMasterControllerLog) << "PlanMasterController::_loadMissionComplete calling _geoFenceController.loadFromVehicle";
            _geoFenceController.loadFromVehicle();
        } else {
            qCDebug(PlanMasterControllerLog) << "PlanMasterController::_loadMissionComplete GeoFence not supported skipping";
            _geoFenceController.removeAll();
            _loadGeoFenceComplete();
        }
        setDirty(false);
    }
}

void PlanMasterController::_loadGeoFenceComplete(void)
{
    if (!_flyView && _loadRallyPoints) {
        _loadRallyPoints = false;
        if (_rallyPointController.supported()) {
            qCDebug(PlanMasterControllerLog) << "PlanMasterController::_loadGeoFenceComplete calling _rallyPointController.loadFromVehicle";
            _rallyPointController.loadFromVehicle();
        } else {
            qCDebug(PlanMasterControllerLog) << "PlanMasterController::_loadMissionComplete Rally Points not supported skipping";
            _rallyPointController.removeAll();
            _loadRallyPointsComplete();
        }
        setDirty(false);
    }
}

void PlanMasterController::_loadRallyPointsComplete(void)
{
    qCDebug(PlanMasterControllerLog) << "PlanMasterController::_loadRallyPointsComplete";
}

void PlanMasterController::_sendMissionComplete(void)
{
    if (_sendGeoFence) {
        _sendGeoFence = false;
        _sendRallyPoints = true;
        if (_geoFenceController.supported()) {
            qCDebug(PlanMasterControllerLog) << "PlanMasterController::sendToVehicle start GeoFence sendToVehicle";
            _geoFenceController.sendToVehicle();
        } else {
            qCDebug(PlanMasterControllerLog) << "PlanMasterController::sendToVehicle GeoFence not supported skipping";
            _sendGeoFenceComplete();
        }
        setDirty(false);
    }
}

void PlanMasterController::_sendGeoFenceComplete(void)
{
    if (_sendRallyPoints) {
        _sendRallyPoints = false;
        if (_rallyPointController.supported()) {
            qCDebug(PlanMasterControllerLog) << "PlanMasterController::sendToVehicle start rally sendToVehicle";
            _rallyPointController.sendToVehicle();
        } else {
            qCDebug(PlanMasterControllerLog) << "PlanMasterController::sendToVehicle Rally Points not support skipping";
            _sendRallyPointsComplete();
        }
    }
}

void PlanMasterController::_sendRallyPointsComplete(void)
{
    qCDebug(PlanMasterControllerLog) << "PlanMasterController::sendToVehicle Rally Point send complete";
    if (_deleteWhenSendCompleted) {
        this->deleteLater();
    }
}

void PlanMasterController::sendToVehicle(void)
{
    SharedLinkInterfacePtr sharedLink = _managerVehicle->vehicleLinkManager()->primaryLink().lock();
    if (sharedLink) {
        if (sharedLink->linkConfiguration()->isHighLatency()) {
            qgcApp()->showAppMessage(tr("Upload not supported on high latency links."));
            return;
        }
    } else {
        // Vehicle is shutting down
        return;
    }

    if (offline()) {
        qCWarning(PlanMasterControllerLog) << "PlanMasterController::sendToVehicle called while offline";
    } else if (syncInProgress()) {
        qCWarning(PlanMasterControllerLog) << "PlanMasterController::sendToVehicle called while syncInProgress";
    } else {
        qCDebug(PlanMasterControllerLog) << "PlanMasterController::sendToVehicle start mission sendToVehicle";
        _sendGeoFence = true;
        _missionController.sendToVehicle();
        setDirty(false);
    }
}

void PlanMasterController::loadFromFile(const QString& filename)
{
    QString errorString;
    QString errorMessage = tr("Error loading Plan file (%1). %2").arg(filename).arg("%1");

    if (filename.isEmpty()) {
        return;
    }

    QFileInfo fileInfo(filename);
    QFile file(filename);

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        errorString = file.errorString() + QStringLiteral(" ") + filename;
        qgcApp()->showAppMessage(errorMessage.arg(errorString));
        return;
    }

    bool success = false;
    if (fileInfo.suffix() == AppSettings::missionFileExtension) {
        if (!_missionController.loadJsonFile(file, errorString)) {
            qgcApp()->showAppMessage(errorMessage.arg(errorString));
        } else {
            success = true;
        }
    } else if (fileInfo.suffix() == AppSettings::waypointsFileExtension || fileInfo.suffix() == QStringLiteral("txt")) {
        if (!_missionController.loadTextFile(file, errorString)) {
            qgcApp()->showAppMessage(errorMessage.arg(errorString));
        } else {
            success = true;
        }
    } else {
        QJsonDocument   jsonDoc;
        QByteArray      bytes = file.readAll();

        if (!JsonHelper::isJsonFile(bytes, jsonDoc, errorString)) {
            qgcApp()->showAppMessage(errorMessage.arg(errorString));
            return;
        }

        QJsonObject json = jsonDoc.object();
        //-- Allow plugins to pre process the load
        QGCCorePlugin::instance()->preLoadFromJson(this, json);

        int version;
        if (!JsonHelper::validateExternalQGCJsonFile(json, kPlanFileType, kPlanFileVersion, kPlanFileVersion, version, errorString)) {
            qgcApp()->showAppMessage(errorMessage.arg(errorString));
            return;
        }

        QList<JsonHelper::KeyValidateInfo> rgKeyInfo = {
            { kJsonMissionObjectKey,        QJsonValue::Object, true },
            { kJsonGeoFenceObjectKey,       QJsonValue::Object, true },
            { kJsonRallyPointsObjectKey,    QJsonValue::Object, true },
        };
        if (!JsonHelper::validateKeys(json, rgKeyInfo, errorString)) {
            qgcApp()->showAppMessage(errorMessage.arg(errorString));
            return;
        }

        if (!_missionController.load(json[kJsonMissionObjectKey].toObject(), errorString) ||
                !_geoFenceController.load(json[kJsonGeoFenceObjectKey].toObject(), errorString) ||
                !_rallyPointController.load(json[kJsonRallyPointsObjectKey].toObject(), errorString)) {
            qgcApp()->showAppMessage(errorMessage.arg(errorString));
        } else {
            //-- Allow plugins to post process the load
            QGCCorePlugin::instance()->postLoadFromJson(this, json);
            success = true;
        }
    }

    if(success){
        _currentPlanFile = QString::asprintf("%s/%s.%s", fileInfo.path().toLocal8Bit().data(), fileInfo.completeBaseName().toLocal8Bit().data(), AppSettings::planFileExtension);
    } else {
        _currentPlanFile.clear();
    }
    emit currentPlanFileChanged();

    if (!offline()) {
        setDirty(true);
    }
}

QJsonDocument PlanMasterController::saveToJson()
{
    QJsonObject planJson;
    QGCCorePlugin::instance()->preSaveToJson(this, planJson);
    QJsonObject missionJson;
    QJsonObject fenceJson;
    QJsonObject rallyJson;
    JsonHelper::saveQGCJsonFileHeader(planJson, kPlanFileType, kPlanFileVersion);
    //-- Allow plugin to preemptly add its own keys to mission
    QGCCorePlugin::instance()->preSaveToMissionJson(this, missionJson);
    _missionController.save(missionJson);
    //-- Allow plugin to add its own keys to mission
    QGCCorePlugin::instance()->postSaveToMissionJson(this, missionJson);
    _geoFenceController.save(fenceJson);
    _rallyPointController.save(rallyJson);
    planJson[kJsonMissionObjectKey] = missionJson;
    planJson[kJsonGeoFenceObjectKey] = fenceJson;
    planJson[kJsonRallyPointsObjectKey] = rallyJson;
    QGCCorePlugin::instance()->postSaveToJson(this, planJson);
    return QJsonDocument(planJson);
}

void
PlanMasterController::saveToCurrent()
{
    if(!_currentPlanFile.isEmpty()) {
        saveToFile(_currentPlanFile);
    }
}

void PlanMasterController::saveToFile(const QString& filename)
{
    if (filename.isEmpty()) {
        return;
    }

    QString planFilename = filename;
    if (!QFileInfo(filename).fileName().contains(".")) {
        planFilename += QString(".%1").arg(fileExtension());
    }

    QFile file(planFilename);

    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qgcApp()->showAppMessage(tr("Plan save error %1 : %2").arg(filename).arg(file.errorString()));
        _currentPlanFile.clear();
        emit currentPlanFileChanged();
    } else {
        QJsonDocument saveDoc = saveToJson();
        file.write(saveDoc.toJson());
        if(_currentPlanFile != planFilename) {
            _currentPlanFile = planFilename;
            emit currentPlanFileChanged();
        }
    }

    // Only clear dirty bit if we are offline
    if (offline()) {
        setDirty(false);
    }
}

void PlanMasterController::saveToKml(const QString& filename)
{
    if (filename.isEmpty()) {
        return;
    }

    QString kmlFilename = filename;
    if (!QFileInfo(filename).fileName().contains(".")) {
        kmlFilename += QString(".%1").arg(kmlFileExtension());
    }

    QFile file(kmlFilename);

    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qgcApp()->showAppMessage(tr("KML save error %1 : %2").arg(filename).arg(file.errorString()));
    } else {
        KMLPlanDomDocument planKML;
        _missionController.addMissionToKML(planKML);
        QTextStream stream(&file);
        stream << planKML.toString();
        file.close();
    }
}

void PlanMasterController::removeAll(void)
{
    _missionController.removeAll();
    _geoFenceController.removeAll();
    _rallyPointController.removeAll();
    if (_offline) {
        _missionController.setDirty(false);
        _geoFenceController.setDirty(false);
        _rallyPointController.setDirty(false);
        _currentPlanFile.clear();
        emit currentPlanFileChanged();
    }
}

void PlanMasterController::removeAllFromVehicle(void)
{
    if (!offline()) {
        _missionController.removeAllFromVehicle();
        if (_geoFenceController.supported()) {
            _geoFenceController.removeAllFromVehicle();
        }
        if (_rallyPointController.supported()) {
            _rallyPointController.removeAllFromVehicle();
        }
        setDirty(false);
    } else {
        qWarning() << "PlanMasterController::removeAllFromVehicle called while offline";
    }
}

bool PlanMasterController::containsItems(void) const
{
    return _missionController.containsItems() || _geoFenceController.containsItems() || _rallyPointController.containsItems();
}

bool PlanMasterController::dirty(void) const
{
    return _missionController.dirty() || _geoFenceController.dirty() || _rallyPointController.dirty();
}

void PlanMasterController::setDirty(bool dirty)
{
    _missionController.setDirty(dirty);
    _geoFenceController.setDirty(dirty);
    _rallyPointController.setDirty(dirty);
}

QString PlanMasterController::fileExtension(void) const
{
    return AppSettings::planFileExtension;
}

QString PlanMasterController::kmlFileExtension(void) const
{
    return AppSettings::kmlFileExtension;
}

QStringList PlanMasterController::loadNameFilters(void) const
{
    QStringList filters;

    filters << tr("Supported types (*.%1 *.%2 *.%3 *.%4)").arg(AppSettings::planFileExtension).arg(AppSettings::missionFileExtension).arg(AppSettings::waypointsFileExtension).arg("txt") <<
               tr("All Files (*)");
    return filters;
}


QStringList PlanMasterController::saveNameFilters(void) const
{
    QStringList filters;

    filters << tr("Plan Files (*.%1)").arg(fileExtension()) << tr("All Files (*)");
    return filters;
}

void PlanMasterController::sendPlanToVehicle(Vehicle* vehicle, const QString& filename)
{
    // Use a transient PlanMasterController to accomplish this
    PlanMasterController* controller = new PlanMasterController();
    controller->startStaticActiveVehicle(vehicle, true /* deleteWhenSendCompleted */);
    controller->loadFromFile(filename);
    controller->sendToVehicle();
}

void PlanMasterController::_showPlanFromManagerVehicle(void)
{
    if (!_managerVehicle->initialPlanRequestComplete() && !syncInProgress()) {
        // Something went wrong with initial load. All controllers are idle, so just force it off
        _managerVehicle->forceInitialPlanRequestComplete();
    }

    // The crazy if structure is to handle the load propagating by itself through the system
    if (!_missionController.showPlanFromManagerVehicle()) {
        if (!_geoFenceController.showPlanFromManagerVehicle()) {
            _rallyPointController.showPlanFromManagerVehicle();
        }
    }
}

bool PlanMasterController::syncInProgress(void) const
{
    return _missionController.syncInProgress() ||
            _geoFenceController.syncInProgress() ||
            _rallyPointController.syncInProgress();
}

bool PlanMasterController::isEmpty(void) const
{
    return _missionController.isEmpty() &&
            _geoFenceController.isEmpty() &&
            _rallyPointController.isEmpty();
}

void PlanMasterController::_updatePlanCreatorsList(void)
{
    if (!_flyView) {
        if (!_planCreators) {
            _planCreators = new QmlObjectListModel(this);
            _planCreators->append(new BlankPlanCreator(this, this));
            _planCreators->append(new SurveyPlanCreator(this, this));
            _planCreators->append(new CorridorScanPlanCreator(this, this));
            emit planCreatorsChanged(_planCreators);
        }

        if (_managerVehicle->fixedWing()) {
            if (_planCreators->count() == 4) {
                _planCreators->removeAt(_planCreators->count() - 1);
            }
        } else {
            if (_planCreators->count() != 4) {
                _planCreators->append(new StructureScanPlanCreator(this, this));
            }
        }
    }
}

void PlanMasterController::showPlanFromManagerVehicle(void)
{
    if (offline()) {
        // There is no new vehicle so clear any previous plan
        qCDebug(PlanMasterControllerLog) << "showPlanFromManagerVehicle: Plan View - No new vehicle, clear any previous plan";
        removeAll();
    } else {
        // We have a new active vehicle, show the plan from that
        qCDebug(PlanMasterControllerLog) << "showPlanFromManagerVehicle: Plan View - New vehicle available, show plan from new manager vehicle";
        _showPlanFromManagerVehicle();
    }
}


//kest










// 100 % works


/*
void PlanMasterController::addWaypoint(double latitude, double longitude, double altitude)
{
    qDebug() << "Adding waypoint from coordinates:" << latitude << longitude << altitude;

    QGeoCoordinate waypointCoord(latitude, longitude, altitude);

            // Insert takeoff only if mission is empty

    if (_missionController.visualItems()->count() == 0) {
        Vehicle* vehicle = MultiVehicleManager::instance()->activeVehicle();
        if (vehicle && vehicle->coordinate().isValid()) {

            // Use correct lat/lon and set desired takeoff altitude
            QGeoCoordinate vehicleCoord = vehicle->coordinate();
            QGeoCoordinate takeoffCoord(vehicleCoord.latitude(), vehicleCoord.longitude(), altitude);

            _missionController.insertTakeoffItem(takeoffCoord, altitude, true);
            qDebug() << "Takeoff item inserted at" << takeoffCoord;
        } else {
            qDebug() << "Unable to start mission";
            return;
        }
    }
    qDebug() << " altitude:" << altitude;

            // Insert waypoint from kestrel app
    _missionController.insertSimpleMissionItem(waypointCoord, _missionController.visualItems()->count(), true);

    qDebug() << "Waypoint inserted at" << waypointCoord;

            // Upload mission to drone
    _missionController.setDirty(true);
    _missionController.sendToVehicle();

    qDebug() << "Takeoff + Waypoint mission sent.";
}

*/

// test with video capture! working waypoint atleast!.



// funker, men ny versjon bruker ID.... denne sjekker UI bruk.















// waypoint med sys id i stedte.
// skal på igjen


void PlanMasterController::addWaypoint(int sysId, double latitude, double longitude, double altitude)

 {      //debug to check what vehicle id used to start the mission

    qDebug() << "addWaypoint() called with sysid:" << sysId;
    qDebug() << "Looking for vehicle with sysid" << sysId;




    //check what vehciles there are
    QmlObjectListModel* vehicleModel = MultiVehicleManager::instance()->vehicles();
    Vehicle* vehicle = nullptr;

        // for loop that cheks until it finds the correct vehicle
    for (int i = 0; i < vehicleModel->count(); ++i) {
        Vehicle* v = qobject_cast<Vehicle*>(vehicleModel->get(i));
        if (v && v->id() == sysId) {
            vehicle = v;
            break;
        }
    }
        //vehicle ID or coordinates check
    if (!vehicle || !vehicle->coordinate().isValid()) {
        qDebug() << "Vehicle with sysid" << sysId << "not found or invalid position.";
        return;
    }
        // set the vehicle with the correct ID as active
    MultiVehicleManager::instance()->setActiveVehicle(vehicle);

    QGeoCoordinate waypointCoord(latitude, longitude, altitude);
    qDebug() << "Adding waypoint for vehicle ID:" << vehicle->id() << latitude << longitude << altitude;

    //if there are no items in the mission already a takeoff item is added. (no takeoff item == system crash)

    if (_missionController.visualItems()->count() == 0) {
        QGeoCoordinate takeoffCoord(vehicle->coordinate().latitude(), vehicle->coordinate().longitude(), altitude);

        _missionController.insertTakeoffItem(takeoffCoord, altitude, true);
        qDebug() << "Takeoff item inserted at" << takeoffCoord;


        //start recording when starting mission
        MissionItem startVideoItem(
            _missionController.visualItems()->count(),
            MAV_CMD_VIDEO_START_CAPTURE,
            MAV_FRAME_MISSION,
            0, 0, 1, 0, 0, 0, 0,
            true, false
            );
        SimpleMissionItem* videoStart = new SimpleMissionItem(this, false, startVideoItem);
        _missionController.visualItems()->append(videoStart);
        qDebug() << "Start video capture command inserted.";
    }

    _missionController.insertSimpleMissionItem(waypointCoord, _missionController.visualItems()->count(), true);
    qDebug() << "Waypoint inserted at" << waypointCoord;

    _missionController.setDirty(true);
    _missionController.sendToVehicle();
    qDebug() << "Takeoff + Start Video + Waypoint mission sent.";
}














//the first correct one

/*
void PlanMasterController::giveMissionToAvailableDrone(double latitude, double longitude, double altitude)
{
    QmlObjectListModel* vehicleModel = MultiVehicleManager::instance()->vehicles();

    if (!vehicleModel || vehicleModel->count() == 0) {
        qWarning() << "No vehicles connected in QGC.";
        return;
    }

    for (int i = 0; i < vehicleModel->count(); ++i) {
        Vehicle* vehicle = qobject_cast<Vehicle*>(vehicleModel->get(i));
        if (vehicle && !vehicle->armed()) {
            MultiVehicleManager::instance()->setActiveVehicle(vehicle);
            qDebug() << "Selected unarmed vehicle ID:" << vehicle->id();

            addWaypoint(latitude, longitude, altitude);  // calls the clean version below
            return;
        }
    }

    qWarning() << "All vehicles are armed. No mission started.";
}

*/



//test
//funker fjell, men endre hvordan dronen tilegner mission
//skal på igen


void PlanMasterController::giveMissionToAvailableDrone(double latitude, double longitude, double altitude)
{
    QmlObjectListModel* vehicleModel = MultiVehicleManager::instance()->vehicles();
    Vehicle* preferred = nullptr;

    if (!vehicleModel || vehicleModel->count() == 0) {
        qWarning() << "No vehicles connected in QGC.";
        return;
    }

            // Step 1: Prefer unarmed drone with MAV_SYS_ID == 1
    for (int i = 0; i < vehicleModel->count(); ++i) {
        Vehicle* v = qobject_cast<Vehicle*>(vehicleModel->get(i));
        if (v && v->id() == 1 && !v->armed()) {
            preferred = v;
            break;
        }
    }

            // Step 2: If not found, use any unarmed drone
    if (!preferred) {
        for (int i = 0; i < vehicleModel->count(); ++i) {
            Vehicle* v = qobject_cast<Vehicle*>(vehicleModel->get(i));
            if (v && !v->armed()) {
                preferred = v;
                break;
            }
        }
    }
/*
            // Step 3: If found, assign mission

    if (preferred) {
        MultiVehicleManager::instance()->setActiveVehicle(preferred);
        qDebug() << "Assigned to unarmed vehicle ID:" << preferred->id();
        addWaypoint(preferred->id(),latitude, longitude, altitude);
*/
        // test

        QTimer::singleShot(300, this, [this, preferred, latitude, longitude, altitude]() {
            _missionController.removeAll();
            addWaypoint(preferred->id(), latitude, longitude, altitude);
        });

        //test

    } // FJERN       //else {
       // qWarning() << "All vehicles are armed. No mission started.";
 //   }
//}






/*
void PlanMasterController::giveMissionToAvailableDrone(double latitude, double longitude, double altitude)
{
    QmlObjectListModel* vehicleModel = MultiVehicleManager::instance()->vehicles();
    Vehicle* preferred = nullptr;

    if (!vehicleModel || vehicleModel->count() == 0) {
        qWarning() << "No vehicles connected in QGC.";
        return;
    }

            // Step 1: Prefer unarmed drone with MAV_SYS_ID == 1
    for (int i = 0; i < vehicleModel->count(); ++i) {
        Vehicle* v = qobject_cast<Vehicle*>(vehicleModel->get(i));
        if (v && v->id() == 1 && !v->armed()) {
            preferred = v;
            break;
        }
    }

            // Step 2: If not found, use any unarmed drone
    if (!preferred) {
        for (int i = 0; i < vehicleModel->count(); ++i) {
            Vehicle* v = qobject_cast<Vehicle*>(vehicleModel->get(i));
            if (v && !v->armed()) {
                preferred = v;
                break;
            }
        }
    }

            // Step 3: Assign mission directly (no activeVehicle change!)
    if (preferred) {
        qDebug() << "Assigned to unarmed vehicle ID:" << preferred->id();
        addWaypoint(preferred->id(),latitude, longitude, altitude);
    } else {
        qWarning() << "All vehicles are armed. No mission started.";
    }
}

*/











// test altitude change:
/*
void PlanMasterController::changeAltitudeMidMission(int sysId, double newAltitude)
{
    QmlObjectListModel* vehicleModel = MultiVehicleManager::instance()->vehicles();

    for (int i = 0; i < vehicleModel->count(); ++i) {
        Vehicle* vehicle = qobject_cast<Vehicle*>(vehicleModel->get(i));
        if (vehicle && vehicle->id() == sysId) {
            qDebug() << "Sending DO_CHANGE_ALTITUDE to vehicle" << sysId;

            MissionItem altChangeItem(
                0,                              // seq (not used)
                MAV_CMD_DO_CHANGE_ALTITUDE,     // command
                MAV_FRAME_GLOBAL_RELATIVE_ALT,  // frame
                newAltitude, 0, 0, 0, 0, 0, 0,   // only param1 is used
                true, false                     // autoContinue, isCurrent
                );

            vehicle->sendMavCommand(
                MAV_COMP_ID_AUTOPILOT1,
                MAV_CMD_DO_CHANGE_ALTITUDE,
                true,
                newAltitude                     // param1: target altitude
                );
            return;
        }
    }

    qWarning() << "Vehicle with ID" << sysId << "not found.";
}
*/


void PlanMasterController::triggerRTL(int sysId)
{
    QmlObjectListModel* model = MultiVehicleManager::instance()->vehicles();
    for (int i = 0; i < model->count(); ++i) {
        Vehicle* v = qobject_cast<Vehicle*>(model->get(i));
        if (v && v->id() == sysId) {
            v->sendMavCommand(
                MAV_COMP_ID_AUTOPILOT1,
                MAV_CMD_NAV_RETURN_TO_LAUNCH,
                true
                );
            qDebug() << "Sent RTL to drone ID" << sysId;
            return;
        }
    }

    qWarning() << "Drone ID" << sysId << "not found for RTL.";
}

/*
void PlanMasterController::checkBackupDroneArrival()
{
    QmlObjectListModel* model = MultiVehicleManager::instance()->vehicles();
    Vehicle* drone1 = nullptr;
    Vehicle* backupDrone = nullptr;

            // Find Drone 1 (ID 1)
    for (int i = 0; i < model->count(); ++i) {
        Vehicle* v = qobject_cast<Vehicle*>(model->get(i));
        if (v && v->id() == 1 && v->armed()) {
            drone1 = v;
        } else if (v && v->id() != 1 && v->armed()) {
            backupDrone = v;
        }
    }

    if (!drone1 || !backupDrone) {
        qDebug() << "Either Drone 1 or backup drone not ready.";
        return;
    }

    if (!drone1->coordinate().isValid() || !backupDrone->coordinate().isValid()) {
        qDebug() << "Invalid coordinates. Skip check.";
        return;
    }

    double distance = backupDrone->coordinate().distanceTo(drone1->coordinate());
    qDebug() << "Distance between drones:" << distance;

    if (distance < 5.0) {
        triggerRTL(1);
        qDebug() << "Backup drone arrived. Triggered RTL for Drone 1.";
    }
}

*/













// replaceDrone() med emit
















/*
void PlanMasterController::giveMissionToAvailableDroneAutoStart(double latitude, double longitude, double altitude)
{
    QmlObjectListModel* vehicleModel = MultiVehicleManager::instance()->vehicles();
    Vehicle* preferred = nullptr;

    if (!vehicleModel || vehicleModel->count() == 0) {
        qWarning() << "No vehicles connected in QGC.";
        return;
    }

            // Step 1: Prefer unarmed drone with MAV_SYS_ID == 1
    for (int i = 0; i < vehicleModel->count(); ++i) {
        Vehicle* v = qobject_cast<Vehicle*>(vehicleModel->get(i));
        if (v && v->id() == 1 && !v->armed()) {
            preferred = v;
            break;
        }
    }

            // Step 2: If not found, use any unarmed drone
    if (!preferred) {
        for (int i = 0; i < vehicleModel->count(); ++i) {
            Vehicle* v = qobject_cast<Vehicle*>(vehicleModel->get(i));
            if (v && !v->armed()) {
                preferred = v;
                break;
            }
        }
    }

            // Step 3: If found, assign mission
    if (preferred) {
        MultiVehicleManager::instance()->setActiveVehicle(preferred);
        qDebug() << "Assigned to unarmed vehicle ID:" << preferred->id();
        addWaypointAutoStart(preferred->id(),latitude, longitude, altitude);
    } else {
        qWarning() << "All vehicles are armed. No mission started.";
    }
}

*/


// G TEST


// skal på igjen.





/// skal på igjen etter test!!


void PlanMasterController::replaceDrone(double safeAltitude)
{
    if (_replacementInProgress) {
        qDebug() << "Replacement already in progress. Skipping.";
        return;
    }

    QmlObjectListModel* vehicleModel = MultiVehicleManager::instance()->vehicles();
    if (!vehicleModel || vehicleModel->count() == 0) {
        qWarning() << "No vehicles connected.";
        return;
    }

    Vehicle* drone1 = nullptr;
    Vehicle* backupDrone = nullptr;

            // Step 1: Find armed Drone 1 (ID 1)
    for (int i = 0; i < vehicleModel->count(); ++i) {
        Vehicle* v = qobject_cast<Vehicle*>(vehicleModel->get(i));
        if (v && v->id() == 1 && v->armed()) {
            drone1 = v;
            break;
        }
    }

    if (!drone1) {
        qWarning() << "Drone 1 not armed or not found.";
        return;
    }

            // Step 2: Check battery level
    Fact* percentFact = nullptr;
    QmlObjectListModel* batteries = drone1->batteries();
    if (batteries && batteries->count() > 0) {
        VehicleBatteryFactGroup* batteryGroup = qobject_cast<VehicleBatteryFactGroup*>(batteries->get(0));
        if (batteryGroup) {
            percentFact = batteryGroup->percentRemaining();
        }
    }

    if (!percentFact || !percentFact->rawValue().isValid()) {
        qWarning() << "Battery percentage unavailable.";
        return;
    }

    float batteryPercent = percentFact->rawValue().toFloat();
    if (batteryPercent > 50.0f) {
        qDebug() << "Battery OK (" << batteryPercent << "%). No replacement needed.";
        return;
    }

    qDebug() << "Drone 1 battery low (" << batteryPercent << "%). Initiating replacement...";
    //_replacementInProgress = true;
    setReplacementInProgress(true);


            // Step 3: Get drone 1 coordinates
    QGeoCoordinate drone1Coord = drone1->coordinate();
    if (!drone1Coord.isValid()) {
        qWarning() << "Invalid coordinate from Drone 1.";
        //_replacementInProgress = false;
        setReplacementInProgress(false);

        return;
    }

            // Step 4: Find unarmed backup drone
    for (int i = 0; i < vehicleModel->count(); ++i) {
        Vehicle* v = qobject_cast<Vehicle*>(vehicleModel->get(i));
        if (v && v->id() != 1 && !v->armed()) {
            backupDrone = v;
            break;
        }
    }

    if (!backupDrone) {
        qWarning() << "No unarmed backup drone found.";
        //_replacementInProgress = false;
        setReplacementInProgress(false);

        return;
    }

            // Step 5: Send mission and start it
    MultiVehicleManager::instance()->setActiveVehicle(backupDrone);
    qDebug() << "Backup drone assigned: ID" << backupDrone->id();

    _backupDroneId = backupDrone->id();// test
    _drone1Coord = drone1->coordinate(); // test

    /*
    //addWaypointAutoStart(backupDrone->id(), drone1Coord.latitude(), drone1Coord.longitude(), 10.0);
    addWaypoint(backupDrone->id(), drone1Coord.latitude(), drone1Coord.longitude(), 10.0);


    if (!backupDrone->armed()) {
        backupDrone->setArmed(true, false);
        qDebug() << "Backup drone armed automatically.";
    }


    //backupDrone->startMission();
    //qDebug() << "Backup drone mission started automatically.";


    if (backupDrone && backupDrone->missionManager() && backupDrone->missionManager()->missionItems().count() > 0) {
        backupDrone->startMission();
        qDebug() << "Backup drone mission started automatically.";
    } else {
        qWarning() << "Cannot start mission: No mission items found for backup drone.";
    }

*/

    addWaypoint(backupDrone->id(), drone1Coord.latitude(), drone1Coord.longitude(), 10.0);

    QTimer::singleShot(500, this, [this, backupDrone]() {
        if (!backupDrone->armed()) {
            backupDrone->setArmed(true, false);
            qDebug() << "Backup drone armed automatically.";
        }

        QTimer::singleShot(1000, this, [this, backupDrone]() {
            if (backupDrone && backupDrone->missionManager() && backupDrone->missionManager()->missionItems().count() > 0) {
                backupDrone->startMission();
                qDebug() << "Backup drone mission started automatically.";
            } else {
                qWarning() << "Cannot start mission: No mission items found for backup drone.";
            }
        });
    });

            // Step 6: Raise altitude of Drone 1
    changeAltitudeMidMission(1, safeAltitude);

            // Step 7: Trigger RTL if close enough
    if (backupDrone->coordinate().isValid()) {
        double dist = backupDrone->coordinate().distanceTo(drone1Coord);
        qDebug() << "Backup drone distance to Drone 1:" << dist << "m";





        //if (dist < 20.0) {
          //  triggerRTL(1);
           // qDebug() << "Backup drone is nearby. RTL triggered.";
       // } else {
          //  qDebug() << "Backup drone not close enough yet.";
     //   }
    }

    //_replacementInProgress = false;
   // setReplacementInProgress(true);
    _backupDroneId = backupDrone->id();
    //QTimer::singleShot(5000, this, SLOT(checkBackupDroneArrival()));
    QTimer::singleShot(3000, this, [this]() {
        checkBackupDroneArrival();
    });


}






void PlanMasterController::checkBackupDroneArrival()
{
    if (!_replacementInProgress) return;

    QmlObjectListModel* vehicleModel = MultiVehicleManager::instance()->vehicles();
    Vehicle* backupDrone = nullptr;

    for (int i = 0; i < vehicleModel->count(); ++i) {
        Vehicle* v = qobject_cast<Vehicle*>(vehicleModel->get(i));
        if (v && v->id() == _backupDroneId) {
            backupDrone = v;
            break;
        }
    }

    if (!backupDrone || !_drone1Coord.isValid() || !backupDrone->coordinate().isValid()) {
        qWarning() << "Backup drone or coordinates invalid. Retrying...";
        QTimer::singleShot(3000, this, [this]() { checkBackupDroneArrival(); });
        return;
    }

    double dist = backupDrone->coordinate().distanceTo(_drone1Coord);
    qDebug() << "Backup drone distance to Drone 1:" << dist << "m";

    if (dist < 20.0) {
        triggerRTL(1);
        setReplacementInProgress(false);
        qDebug() << "Backup drone is nearby. RTL triggered.";
    } else {
        QTimer::singleShot(3000, this, [this]() { checkBackupDroneArrival(); });
    }
}











void PlanMasterController::changeAltitudeMidMission(int sysId, double newAltitude)
{
    qCDebug(PlanMasterControllerLog) << "changeAltitudeMidMission: Starting for sysId" << sysId;

    QmlObjectListModel* vehicleModel = MultiVehicleManager::instance()->vehicles();
    Vehicle* vehicle = nullptr;

    for (int i = 0; i < vehicleModel->count(); ++i) {
        Vehicle* v = qobject_cast<Vehicle*>(vehicleModel->get(i));
        if (v && v->id() == sysId) {
            vehicle = v;
            break;
        }
    }

    if (!vehicle) {
        qCWarning(PlanMasterControllerLog) << "changeAltitudeMidMission: Vehicle with ID" << sysId << "not found.";
        return;
    }

    if (!vehicle->coordinate().isValid()) {
        qCWarning(PlanMasterControllerLog) << "changeAltitudeMidMission: Vehicle ID" << sysId << "has invalid position.";
        return;
    }

    qCDebug(PlanMasterControllerLog) << "changeAltitudeMidMission: Sending DO_CHANGE_ALTITUDE to vehicle ID" << sysId << "with altitude" << newAltitude;

    vehicle->sendMavCommand(
        MAV_COMP_ID_AUTOPILOT1,
        MAV_CMD_DO_CHANGE_ALTITUDE,
        true, // showError
        static_cast<float>(newAltitude), // param1: altitude in meters
        0, 0, 0, 0, 0, 0 // unused params
        );
}



void PlanMasterController::setReplacementInProgress(bool value) {
    if (_replacementInProgress != value) {
        _replacementInProgress = value;
        emit replacementInProgressChanged();
    }
}











/////
