/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window

import QGroundControl
import QGroundControl.Palette
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.ScreenTools
import QGroundControl.FlightDisplay
import QGroundControl.FlightMap
//test
import Qt5Compat.GraphicalEffects
import Qt.labs.settings
//
import QGroundControl.UTMSP

/// @brief Native QML top level window
/// All properties defined here are visible to all QML pages.
ApplicationWindow {
    id:             mainWindow
    minimumWidth:   ScreenTools.isMobile ? ScreenTools.screenWidth  : Math.min(ScreenTools.defaultFontPixelWidth * 100, Screen.width)
    minimumHeight:  ScreenTools.isMobile ? ScreenTools.screenHeight : Math.min(ScreenTools.defaultFontPixelWidth * 50, Screen.height)
    visible:        true

    property bool   _utmspSendActTrigger
    property bool   _utmspStartTelemetry

    Component.onCompleted: {
        //-- Full screen on mobile or tiny screens
        if (!ScreenTools.isFakeMobile && (ScreenTools.isMobile || Screen.height / ScreenTools.realPixelDensity < 120)) {
            mainWindow.showFullScreen()
        } else {
            width   = ScreenTools.isMobile ? ScreenTools.screenWidth  : Math.min(250 * Screen.pixelDensity, Screen.width)
            height  = ScreenTools.isMobile ? ScreenTools.screenHeight : Math.min(150 * Screen.pixelDensity, Screen.height)
        }

        // Start the sequence of first run prompt(s)
        firstRunPromptManager.nextPrompt()
    }

    QtObject {
        id: firstRunPromptManager

        property var currentDialog:     null
        property var rgPromptIds:       QGroundControl.corePlugin.firstRunPromptsToShow()
        property int nextPromptIdIndex: 0

        function clearNextPromptSignal() {
            if (currentDialog) {
                currentDialog.closed.disconnect(nextPrompt)
            }
        }

        function nextPrompt() {
            if (nextPromptIdIndex < rgPromptIds.length) {
                var component = Qt.createComponent(QGroundControl.corePlugin.firstRunPromptResource(rgPromptIds[nextPromptIdIndex]));
                currentDialog = component.createObject(mainWindow)
                currentDialog.closed.connect(nextPrompt)
                currentDialog.open()
                nextPromptIdIndex++
            } else {
                currentDialog = null
                showPreFlightChecklistIfNeeded()
            }
        }
    }

    readonly property real      _topBottomMargins:          ScreenTools.defaultFontPixelHeight * 0.5

    //-------------------------------------------------------------------------
    //-- Global Scope Variables

    QtObject {
        id: globals

        readonly property var       activeVehicle:                  QGroundControl.multiVehicleManager.activeVehicle
        readonly property real      defaultTextHeight:              ScreenTools.defaultFontPixelHeight
        readonly property real      defaultTextWidth:               ScreenTools.defaultFontPixelWidth
        readonly property var       planMasterControllerFlyView:    flyView.planController
        readonly property var       guidedControllerFlyView:        flyView.guidedController

        // Number of QGCTextField's with validation errors. Used to prevent closing panels with validation errors.
        property int                validationErrorCount:           0 

        // Property to manage RemoteID quick access to settings page
        property bool               commingFromRIDIndicator:        false
    }

    /// Default color palette used throughout the UI
    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    //-------------------------------------------------------------------------
    //-- Actions

    signal armVehicleRequest
    signal forceArmVehicleRequest
    signal disarmVehicleRequest
    signal vtolTransitionToFwdFlightRequest
    signal vtolTransitionToMRFlightRequest
    signal showPreFlightChecklistIfNeeded

    //-------------------------------------------------------------------------
    //-- Global Scope Functions

    // This function is used to prevent view switching if there are validation errors
    function allowViewSwitch(previousValidationErrorCount = 0) {
        // Run validation on active focus control to ensure it is valid before switching views
        if (mainWindow.activeFocusControl instanceof FactTextField) {
            mainWindow.activeFocusControl._onEditingFinished()
        }
        return globals.validationErrorCount <= previousValidationErrorCount
    }

    function showPlanView() {
        flyView.visible = false
        planView.visible = true
        viewer3DWindow.close()
    }

    function showFlyView() {
        flyView.visible = true
        planView.visible = false
    }

    function showTool(toolTitle, toolSource, toolIcon) {
        toolDrawer.backIcon     = flyView.visible ? "/qmlimages/PaperPlane.svg" : "/qmlimages/Plan.svg"
        toolDrawer.toolTitle    = toolTitle
        toolDrawer.toolSource   = toolSource
        toolDrawer.toolIcon     = toolIcon
        toolDrawer.visible      = true
    }

    function showAnalyzeTool() {
        showTool(qsTr("Analyze Tools"), "AnalyzeView.qml", "/qmlimages/Analyze.svg")
    }

    function showVehicleConfig() {
        showTool(qsTr("Vehicle Configuration"), "SetupView.qml", "/qmlimages/Gears.svg")
    }

    function showVehicleConfigParametersPage() {
        showVehicleConfig()
        toolDrawerLoader.item.showParametersPanel()
    }

    function showKnownVehicleComponentConfigPage(knownVehicleComponent) {
        showVehicleConfig()
        let vehicleComponent = globals.activeVehicle.autopilotPlugin.findKnownVehicleComponent(knownVehicleComponent)
        if (vehicleComponent) {
            toolDrawerLoader.item.showVehicleComponentPanel(vehicleComponent)
        }
    }

    function showSettingsTool(settingsPage = "") {
        showTool(qsTr("Application Settings"), "AppSettings.qml", "/res/QGCLogoWhite")
        if (settingsPage !== "") {
            toolDrawerLoader.item.showSettingsPage(settingsPage)
        }
    }

    //-------------------------------------------------------------------------
    //-- Global simple message dialog

    function showMessageDialog(dialogTitle, dialogText, buttons = Dialog.Ok, acceptFunction = null, closeFunction = null) {
        simpleMessageDialogComponent.createObject(mainWindow, { title: dialogTitle, text: dialogText, buttons: buttons, acceptFunction: acceptFunction, closeFunction: closeFunction }).open()
    }

    // This variant is only meant to be called by QGCApplication
    function _showMessageDialog(dialogTitle, dialogText) {
        showMessageDialog(dialogTitle, dialogText)
    }

    Component {
        id: simpleMessageDialogComponent

        QGCSimpleMessageDialog {
        }
    }

    /// Saves main window position and size
    MainWindowSavedState {
        window: mainWindow
    }

    property bool _forceClose: false

    function finishCloseProcess() {
        _forceClose = true
        // For some reason on the Qml side Qt doesn't automatically disconnect a signal when an object is destroyed.
        // So we have to do it ourselves otherwise the signal flows through on app shutdown to an object which no longer exists.
        firstRunPromptManager.clearNextPromptSignal()
        QGroundControl.linkManager.shutdown()
        QGroundControl.videoManager.stopVideo();
        mainWindow.close()
    }

    // Check for things which should prevent the app from closing
    //  Returns true if it is OK to close
    readonly property int _skipUnsavedMissionCheckMask: 0x01
    readonly property int _skipPendingParameterWritesCheckMask: 0x02
    readonly property int _skipActiveConnectionsCheckMask: 0x04
    property int _closeChecksToSkip: 0
    function performCloseChecks() {
        if (!(_closeChecksToSkip & _skipUnsavedMissionCheckMask) && !checkForUnsavedMission()) {
            return false
        }
        if (!(_closeChecksToSkip & _skipPendingParameterWritesCheckMask) && !checkForPendingParameterWrites()) {
            return false
        }
        if (!(_closeChecksToSkip & _skipActiveConnectionsCheckMask) && !checkForActiveConnections()) {
            return false
        }
        finishCloseProcess()
        return true
    }

    property string closeDialogTitle: qsTr("Close %1").arg(QGroundControl.appName)

    function checkForUnsavedMission() {
        if (planView._planMasterController.dirty) {
            showMessageDialog(closeDialogTitle,
                              qsTr("You have a mission edit in progress which has not been saved/sent. If you close you will lose changes. Are you sure you want to close?"),
                              Dialog.Yes | Dialog.No,
                              function() { _closeChecksToSkip |= _skipUnsavedMissionCheckMask; performCloseChecks() })
            return false
        } else {
            return true
        }
    }

    function checkForPendingParameterWrites() {
        for (var index=0; index<QGroundControl.multiVehicleManager.vehicles.count; index++) {
            if (QGroundControl.multiVehicleManager.vehicles.get(index).parameterManager.pendingWrites) {
                mainWindow.showMessageDialog(closeDialogTitle,
                    qsTr("You have pending parameter updates to a vehicle. If you close you will lose changes. Are you sure you want to close?"),
                    Dialog.Yes | Dialog.No,
                    function() { _closeChecksToSkip |= _skipPendingParameterWritesCheckMask; performCloseChecks() })
                return false
            }
        }
        return true
    }

    function checkForActiveConnections() {
        if (QGroundControl.multiVehicleManager.activeVehicle) {
            mainWindow.showMessageDialog(closeDialogTitle,
                qsTr("There are still active connections to vehicles. Are you sure you want to exit?"),
                Dialog.Yes | Dialog.No,
                function() { _closeChecksToSkip |= _skipActiveConnectionsCheckMask; performCloseChecks() })
            return false
        } else {
            return true
        }
    }

    onClosing: (close) => {
        if (!_forceClose) {
            _closeChecksToSkip = 0
            close.accepted = performCloseChecks()
        }
    }

    background: Rectangle {
        anchors.fill:   parent
        color:          QGroundControl.globalPalette.window
    }

    FlyView { 
        id:                     flyView
        anchors.fill:           parent
        utmspSendActTrigger:    _utmspSendActTrigger
	property var dispenserData: parent.dispenserData //kest
    }

    PlanView {
        id:             planView
        anchors.fill:   parent
        visible:        false
    }



////// DISPENSER MENU CENTER TOP


/* 

// Toggle menu button (top center, Drone Dispenser)
Button {
    id: topOverlayButton
    text: "Drone Dispenser"
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.topMargin: 6
    z: 999
    onClicked: drawer.visible = !drawer.visible
}
*/ 





//kest
/*
MouseArea {
    id: logoButton
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.topMargin: -18
    width: 95
    height: 95
    z: 999
    cursorShape: Qt.PointingHandCursor

    onClicked: {
        drawer.visible = !drawer.visible
    }



    Rectangle {
        width: parent.width
        height: parent.height
        color: "transparent"
        border.color: "white"
        border.width: 2
        radius: 10




    Image {
        anchors.fill: parent
        source: "qrc:/qmlimages/kestrelLogo.svg"
	//source: "qrc:/gear-white.svg"

        fillMode: Image.PreserveAspectFit
        smooth: true

	}
    }
}


*/












// NY ITERASJON

/*
// Properties for dispenser data
    property string udpMessage: "No message received"  // Default value
    property string temperatureMessage: "pending..."   // Default value


    property string selectedDispenser: "1"  // Default selected dispenser
    property var dispenserList: ["Dispenser 1", "Dispenser 2"]  // List of dispensers

	//property var dispenserList: [" 1", " 2"]  // List of dispensers

    property string dispenserStatus: udpMessage  // Reflects CLOSED/OPEN
    property string temperature: temperatureMessage
    property string humidity: "25"  // Static for now
    property string chargerStatus: "CHARGING"  // Static for now
    property string errorMessage: "NONE"  // Static for now

*/


  //  property string selectedDispenser: "1"  // Default selected dispenser
  //  property var dispenserList: ["Dispenser 1", "Dispenser 2"]  // List of dispensers

/// TEST

property string selectedDispenser: "1"
property var dispenserList: []
property var dispenserData: ({})

property var receivers: {
    "1": {udp: udpReceiver, temperature: temperatureReceiver},
    "2": {udp: null, temperature: null}
}

Item {
    width: parent.width
    height: 95
    anchors.top: parent.top
    anchors.topMargin: 2

    MouseArea {
        id: logoButton
        width: 62
        height: 62
	anchors.right: parent.right
        //anchors.horizontalCenter: parent.horizontalCenter
	anchors.rightMargin: 140
	anchors.horizontalCenter: parent.verticalCenter
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            drawer.visible = !drawer.visible
        }

        Image {
            anchors.fill: parent
            source: "qrc:/qmlimages/kestrelDispenser_swapped.svg"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    Text {
        id: dispenserStatusText
        text: "Dispenser status: " + dispenserData[selectedDispenser].status
        color: "white"
        font.pixelSize: 18
        font.bold: true
        anchors.verticalCenter: logoButton.verticalCenter
        anchors.right: logoButton.left
        anchors.rightMargin: 12
    }


//////// test for lagring...


Settings {
    id: dispenserSettings
    category: "DispenserData"
    property var savedDispenserData

    Component.onCompleted: {
        console.log("Loading savedDispenserData:", JSON.stringify(savedDispenserData))
        var defaultDispenserData = {
            "1": {
                status: "No message received",
                temperature: " ",
                humidity: " ",
                chargerStatus: "Unknown",
                errors: "NONE",
                latitude: 59.6574100,
                longitude: 9.6441920,
                name: "Dispenser 1"
            },
            "2": {
                status: "No message received",
                temperature: "pending...",
                humidity: "25",
                chargerStatus: "CHARGING",
                errors: "NONE",
                latitude: 59.6555001,
                longitude: 9.6457272,
                name: "Dispenser 2"
            }
        }

        if (savedDispenserData && Object.keys(savedDispenserData).length > 0) {
            dispenserData = {
                "1": {
                    status: "No message received",
                    temperature: " ",
                    humidity: " ",
                    chargerStatus: "Unknown",
                    errors: "NONE",
                    latitude: savedDispenserData["1"].latitude || defaultDispenserData["1"].latitude,
                    longitude: savedDispenserData["1"].longitude || defaultDispenserData["1"].longitude,
                    name: savedDispenserData["1"].name || defaultDispenserData["1"].name
                },
                "2": {
                    status: "No message received",
                    temperature: "pending...",
                    humidity: "25",
                    chargerStatus: "CHARGING",
                    errors: "NONE",
                    latitude: savedDispenserData["2"].latitude || defaultDispenserData["2"].latitude,
                    longitude: savedDispenserData["2"].longitude || defaultDispenserData["2"].longitude,
                    name: savedDispenserData["2"].name || defaultDispenserData["2"].name
                }
            }
        } else {
            dispenserData = defaultDispenserData
            savedDispenserData = {
                "1": {
                    latitude: dispenserData["1"].latitude,
                    longitude: dispenserData["1"].longitude,
                    name: dispenserData["1"].name
                },
                "2": {
                    latitude: dispenserData["2"].latitude,
                    longitude: dispenserData["2"].longitude,
                    name: dispenserData["2"].name
                }
            }
        }
        dispenserList = Object.keys(dispenserData).map(id => ({
            id: id,
            name: dispenserData[id].name
        }))
        selectedDispenser = "1"
        console.log("Initialized dispenserData:", JSON.stringify(dispenserData))
    }
}




///



    Rectangle {
        id: drawer
        width: 600
        height: 300
        visible: false
        color: "#1e1e1e"
        radius: 12
        z: 998
        anchors.top: logoButton.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 8
        border.color: "#3c3c3c"
        border.width: 1

        layer.enabled: true
        layer.effect: DropShadow {
            color: "#000000"
            radius: 8
            samples: 16
            verticalOffset: 4
        }

        Row {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            Rectangle {
                width: 150
                height: parent.height
                color: "#2b2b2b"
                radius: 8

                ListView {
                    anchors.fill: parent
                    anchors.margins: 8
                    model: dispenserList
                    delegate: Row {
                        width: parent.width
                        height: 40
                        spacing: 8

                        Rectangle {
                            width: parent.width - 40
                            height: 40
                            color: selectedDispenser === modelData.id ? "#3d3d3d" : "transparent"

                            Text {
                                text: modelData.name
                                color: "white"
                                font.pixelSize: 16
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    selectedDispenser = modelData.id
                                }
                            }
                        }

                        Image {
                            source: "qrc:/res/pencil.svg"
                            width: 20
                            height: 20
                            anchors.verticalCenter: parent.verticalCenter
                            fillMode: Image.PreserveAspectFit
                            smooth: true

                            MouseArea {
                                id: editArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    editPopup.dispenserId = modelData.id
                                    editPopup.dispenserName = dispenserData[modelData.id].name
                                    editPopup.dispenserLatitude = dispenserData[modelData.id].latitude
                                    editPopup.dispenserLongitude = dispenserData[modelData.id].longitude
                                    editPopup.visible = true
                                }
                            }
                        }
                    }
                }
            }

            Column {
                spacing: 12
                width: parent.width - 150 - 16

                Text {
                    //text: "Dispenser " + selectedDispenser //Ga ikke riktig navn på valgt dispenser
		    text: dispenserData[selectedDispenser].name
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }

                Text { text: "Status: " + dispenserData[selectedDispenser].status; color: "lightgray"; font.pixelSize: 16 }
                Text { 
                    text: "Temperature: " + (dispenserData[selectedDispenser].temperature === "pending..." ? "N/A" : dispenserData[selectedDispenser].temperature + "°C"); 
                    color: "lightgray"; 
                    font.pixelSize: 16 
                }
                Text { 
                    text: "Humidity: " + (dispenserData[selectedDispenser].humidity === " " ? "N/A" : dispenserData[selectedDispenser].humidity + "%"); 
                    color: "lightgray"; 
                    font.pixelSize: 16 
                }
                Text { text: "Charger Status: " + dispenserData[selectedDispenser].chargerStatus; color: "lightgray"; font.pixelSize: 16 }
                Text { text: "Errors: " + dispenserData[selectedDispenser].errors; color: "lightgray"; font.pixelSize: 16 }

                Rectangle {
                    width: 300
                    height: 60
                    color: "red"
                    radius: 10

                    Text {
                        anchors.centerIn: parent
                        text: "LAUNCH"
                        font.bold: true
                        font.pixelSize: 32
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            console.log("Launching Dispenser " + selectedDispenser)
                        }
                    }
                }

                Rectangle {
                    width: 40
                    height: 40
                    color: "gray"
                    anchors.right: parent.right
		    

                    Text {
                        anchors.centerIn: parent
                        text: "☰"
                        color: "white"
                        font.pixelSize: 24
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            openClosePopup.visible = !openClosePopup.visible
                        }
                    }
                }
            }
        }


        Rectangle {
            id: openClosePopup
            visible: false
            width: 200
            height: 60
            color: "#333"
            radius: 8
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 20 //herher
	
	    z: 999


            Row {
                spacing: 10
                anchors.centerIn: parent

                Rectangle {
                    width: 80
                    height: 40
                    radius: 8
                    color: openArea.pressed ? "#3d3d3d" : (openArea.containsMouse ? "#2a2a2a" : "transparent")

                    MouseArea {
                        id: openArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            console.log("Open Dispenser clicked")
                            qgcApp.startUdpSender()
                            openClosePopup.visible = false
                        }
                    }

                    Text {
                        text: "Open"
                        color: "white"
                        font.pixelSize: 16
                        anchors.centerIn: parent
                    }
                }

                Rectangle {
                    width: 80
                    height: 40
                    radius: 8
                    color: closeArea.pressed ? "#3d3d3d" : (closeArea.containsMouse ? "#2a2a2a" : "transparent")

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            console.log("Close Dispenser clicked")
                            qgcApp.startUdpCloseSender()
                            openClosePopup.visible = false
                        }
                    }

                    Text {
                        text: "Close"
                        color: "white"
                        font.pixelSize: 16
                        anchors.centerIn: parent
                    }
                }
            }
        }

        Rectangle {
            id: editPopup
            visible: false
            width: 300
            height: 200
            color: "#333"
            radius: 8
            anchors.centerIn: parent
            z: 999

            property string dispenserId: ""
            property string dispenserName: ""
            property real dispenserLatitude: 0
            property real dispenserLongitude: 0

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text {
                    text: "Edit Dispenser " + editPopup.dispenserId
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }

                Row {
                    spacing: 8
                    Text {
                        text: "Name:"
                        color: "white"
                        font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    TextField {
                        text: editPopup.dispenserName
                        color: "white"
                        font.pixelSize: 16
                        background: Rectangle {
                            color: "#555"
                            radius: 5
                        }
                        onTextChanged: editPopup.dispenserName = text
                    }
                }

                Row {
                    spacing: 8
                    Text {
                        text: "Latitude:"
                        color: "white"
                        font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    TextField {
                        text: editPopup.dispenserLatitude
                        color: "white"
                        font.pixelSize: 16
                        background: Rectangle {
                            color: "#555"
                            radius: 5
                        }
                        onTextChanged: editPopup.dispenserLatitude = parseFloat(text) || 0
                    }
                }

                Row {
                    spacing: 8
                    Text {
                        text: "Longitude:"
                        color: "white"
                        font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    TextField {
                        text: editPopup.dispenserLongitude
                        color: "white"
                        font.pixelSize: 16
                        background: Rectangle {
                            color: "#555"
                            radius: 5
                        }
                        onTextChanged: editPopup.dispenserLongitude = parseFloat(text) || 0
                    }
                }

                Row {
                    spacing: 10
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: 80
                        height: 40
                        radius: 8
                        color: saveArea.pressed ? "#3d3d3d" : (saveArea.containsMouse ? "#2a2a2a" : "green")
		      

		      MouseArea {
			    id: saveArea
			    anchors.fill: parent
			    hoverEnabled: true
		    onClicked: {
		        dispenserData[editPopup.dispenserId].name = editPopup.dispenserName
		        dispenserData[editPopup.dispenserId].latitude = editPopup.dispenserLatitude
		        dispenserData[editPopup.dispenserId].longitude = editPopup.dispenserLongitude
		        dispenserData = dispenserData

		        dispenserList = Object.keys(dispenserData).map(id => ({
		            id: id,
		            name: dispenserData[id].name
		        }))
		        dispenserSettings.savedDispenserData = {
	            "1": {
			        latitude: dispenserData["1"].latitude,
		                longitude: dispenserData["1"].longitude,
		                name: dispenserData["1"].name
		            },
	            "2": {
			        latitude: dispenserData["2"].latitude,
		                longitude: dispenserData["2"].longitude,
		                name: dispenserData["2"].name
		            }
		        }
		        console.log("Saved dispenserData:", JSON.stringify(dispenserSettings.savedDispenserData))

		        editPopup.visible = false
		    }
		}
  


                        Text {
                            text: "Save"
                            color: "white"
                            font.pixelSize: 16
                            anchors.centerIn: parent
                        }
                    }

                    Rectangle {
                        width: 80
                        height: 40
                        radius: 8
                        color: cancelArea.pressed ? "#3d3d3d" : (cancelArea.containsMouse ? "#2a2a2a" : "red")

                        MouseArea {
                            id: cancelArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                editPopup.visible = false
                            }
                        }

                        Text {
                            text: "Cancel"
                            color: "white"
                            font.pixelSize: 16
                            anchors.centerIn: parent
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: receivers["1"].udp
        function onMessageReceived(message) {
            console.log("Received UDP message for dispenser 1:", message)
            dispenserData["1"].status = message.trim()
            dispenserData = dispenserData
        }
    }

    Connections {
        target: receivers["1"].temperature
        function onTemperatureReceived(temperature) {
            console.log("temperature for dispenser 1:", temperature)
            dispenserData["1"].temperature = temperature.trim()
            dispenserData = dispenserData
        }
    }
}







////////////////////////////////////////////////////////
////////////////////////////////////////////////////////
////////////////////////////////////////////////////////
////////////////////////////////////////////////////////
////////////////////////////////////////////////////////
////////////////////////////////////////////////////////
////////////////////////////////////////////////////////
////////////////////////////////////////////////////////
////////////////////////////////////////////////////////



//test for UDP meldinger opo up 

// New Coordinate Pop-Up
Popup {
    id: coordinatePopup
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)
    width: 300
    height: 150
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    property double latitude: 0
    property double longitude: 0
    property string typeOfIncident: " "

    background: Rectangle {
        color: "#333"
        radius: 8
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Text {
            text: "Security Incident Alert"
            color: "white"
            font.pixelSize: 18
            font.bold: true
        }
	
	Text {
	    text: "Type of Incident: " + coordinatePopup.typeOfIncident
            color: "lightgray"
            font.pixelSize: 16

	}


        Text {
            text: "Latitude: " + coordinatePopup.latitude.toFixed(6)
            color: "lightgray"
            font.pixelSize: 16
        }

        Text {
            text: "Longitude: " + coordinatePopup.longitude.toFixed(6)
            color: "lightgray"
            font.pixelSize: 16
        }


        Row {
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                width: 80
                height: 40
                radius: 8
                color: acceptArea.pressed ? "#3d3d3d" : (acceptArea.containsMouse ? "#2a2a2a" : "green")

                MouseArea {
                    id: acceptArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        console.log("Accepted coordinates:", coordinatePopup.latitude, coordinatePopup.longitude)
                        coordinatePopup.close()
			
			if (globals.planMasterControllerFlyView) {
			//change into flightplanner
				mainWindow.showPlanView()

			//set waypoint for UDP melding
				globals.planMasterControllerFlyView.addWaypoint(coordinatePopup.latitude, coordinatePopup.longitude)
			}
			else {
				console.log("Cannot plan flight at this moment")
			}
			coordinatePopup.close()

				
                    }
                }

                Text {
                    text: "Accept"
                    color: "white"
                    font.pixelSize: 16
                    anchors.centerIn: parent
                }
            }

            Rectangle {
                width: 80
                height: 40
                radius: 8
                color: denyArea.pressed ? "#3d3d3d" : (denyArea.containsMouse ? "#2a2a2a" : "red")

                MouseArea {
                    id: denyArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        console.log("Denied coordinates:", coordinatePopup.latitude, coordinatePopup.longitude)
                        coordinatePopup.close()
                    }
                }

                Text {
                    text: "Deny"
                    color: "white"
                    font.pixelSize: 16
                    anchors.centerIn: parent
                }
            }
        }
    }
}

// Connect the CoordinateReceiver to the pop-up
Connections {
    target: coordinateReceiver
    function onCoordinatesReceived(incidentType, latitude, longitude) {
        console.log("Received coordinates: Latitude =", latitude, "Longitude =", longitude)
        coordinatePopup.latitude = latitude
        coordinatePopup.longitude = longitude
	coordinatePopup.typeOfIncident = incidentType
        coordinatePopup.open() // Automatically open the pop-up
    }
}




//







///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////





/*
// Middle Left Logo
Item {
    width: 62
    height: 62
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: 20

    MouseArea {
        id: logoButtonLeft
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        Image {
            anchors.fill: parent
            source: "qrc:/qmlimages/kestrelDispenser123.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }
}


Rectangle {
        id: bottomBar
        anchors.bottom: parent.bottom
	anchors.bottomMargin: -10
        anchors.horizontalCenter: parent.horizontalCenter // Center horizontally
        width: parent.width * 0.5 // Takes up half the window's width
        height: 40 // Matches the height of the bar in the image
        color: "#000000" // Black color
        opacity: 0.6 // Semi-transparent, adjust as needed (0.0 = fully transparent, 1.0 = fully opaque)
    }

*/








///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////










/* // versjon med Eedit som fungerer delvis

property string selectedDispenser: "1"
    property var dispenserList: ["Dispenser 1", "Dispenser 2"]

    property var dispenserData: {
        "1": {
            status: "No message received",
            temperature: " ",
            humidity: " ", 
            chargerStatus: "Unknown", 
            errors: "NONE",
            latitude: 59.6574100,
            longitude: 9.6441920,
            name: "Dispenser 1"
        },
        "2": { 
            status: "No message received", 
            temperature: "pending...", 
            humidity: "25", 
            chargerStatus: "CHARGING", 
            errors: "NONE",
            latitude: 59.6555001,  
            longitude: 9.6457272,
            name: "Dispenser 2"
        }
    }

    property var receivers: {
        "1": {udp: udpReceiver, temperature: temperatureReceiver},
        "2": {udp: null, temperature: null}
    }

    Item {
        width: parent.width
        height: 95
        anchors.top: parent.top
        anchors.topMargin: 2 //-16

        MouseArea {
            id: logoButton
            width: 62 //95
            height: 62 //95
            anchors.horizontalCenter: parent.horizontalCenter
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                drawer.visible = !drawer.visible
            }

            Image {
                anchors.fill: parent
                //source: "qrc:/qmlimages/kestrelLogo.svg"
		//source: "qrc:/qmlimages/kestrelDispenser.svg"
		source: "qrc:/qmlimages/kestrelDispenser_swapped.svg"
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }

        Text {
            id: dispenserStatusText
            text: "Dispenser status: " + dispenserData[selectedDispenser].status
            color: "white"
            font.pixelSize: 18
            font.bold: true
            anchors.verticalCenter: logoButton.verticalCenter
            anchors.left: logoButton.right
            anchors.leftMargin: 12
        }
	
	//tester her
	Settings {
		id: dispenserSettings
		category: "DispenserData"
		property var savedDispenserData: ({
        "1": {
            status: "No message received",
            temperature: " ",
            humidity: " ",
            chargerStatus: "Unknown",
            errors: "NONE",
            latitude: 59.6574100,
            longitude: 9.6441920,
            name: "Dispenser 1"
        },
        "2": {
            status: "No message received",
            temperature: " ",
            humidity: " ",
            chargerStatus: "Unknown",
            errors: "NONE",
            latitude: 59.6555001,
            longitude: 9.6457272,
            name: "Dispenser 2"
        }
    })

    Component.onCompleted: {
        // Load saved data into dispenserData and update dispenserList
        dispenserData = savedDispenserData
        dispenserList = Object.values(dispenserData).map(item => item.name)
        selectedDispenser = "1"
	}
     }
	




        Rectangle {
            id: drawer
            width: 600
            height: 300
            visible: false
            color: "#1e1e1e"
            radius: 12
            z: 998
            anchors.top: logoButton.bottom
            anchors.horizontalCenter: logoButton.horizontalCenter
            anchors.topMargin: 8
            border.color: "#3c3c3c"
            border.width: 1

            layer.enabled: true
            layer.effect: DropShadow {
                color: "#000000"
                radius: 8
                samples: 16
                verticalOffset: 4
            }

            Row {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                Rectangle {
                    width: 150
                    height: parent.height
                    color: "#2b2b2b"
                    radius: 8

                    ListView {
                        anchors.fill: parent
                        anchors.margins: 8
                        model: dispenserList
                        delegate: Row {
                            width: parent.width
                            height: 40
                            spacing: 8

                            Rectangle {
                                width: parent.width - 40
                                height: 40
                                color: selectedDispenser === modelData.split(" ")[1] ? "#3d3d3d" : "transparent"

                                Text {
                                    //text: modelData
				    text: dispenserData[modelData.split(" ")[1]].name
                                    color: "white"
                                    font.pixelSize: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        selectedDispenser = modelData.split(" ")[1]
                                    }
                                }
                            }

                            Image {
				source: "qrc:/res/pencil.svg"
                                width: 20				
                                height: 20
                                anchors.verticalCenter: parent.verticalCenter
				fillMode: Image.PreserveAspectFit
				smooth: true


                                MouseArea {
                                    id: editArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        editPopup.dispenserId = modelData.split(" ")[1]
                                        editPopup.dispenserName = dispenserData[modelData.split(" ")[1]].name
                                        editPopup.dispenserLatitude = dispenserData[editPopup.dispenserId].latitude
                                        editPopup.dispenserLongitude = dispenserData[editPopup.dispenserId].longitude
                                        editPopup.visible = true
                                   } 
                                }
                            }
                        }
                    }
                }

                Column {
                    spacing: 12
                    width: parent.width - 150 - 16

                    Text {
                        text: "Dispenser " + selectedDispenser
                        color: "white"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text { text: "Status: " + dispenserData[selectedDispenser].status; color: "lightgray"; font.pixelSize: 16 }
                    Text { text: "Temperature: " + dispenserData[selectedDispenser].temperature + "°C"; color: "lightgray"; font.pixelSize: 16 }
                    Text { text: "Humidity: " + dispenserData[selectedDispenser].humidity + "%"; color: "lightgray"; font.pixelSize: 16 }
                    Text { text: "Charger Status: " + dispenserData[selectedDispenser].chargerStatus; color: "lightgray"; font.pixelSize: 16 }
                    Text { text: "Errors: " + dispenserData[selectedDispenser].errors; color: "lightgray"; font.pixelSize: 16 }

                    Rectangle {
                        width: 300
                        height: 60
                        color: "red"
                        radius: 10

                        Text {
                            anchors.centerIn: parent
                            text: "LAUNCH"
                            font.bold: true
                            font.pixelSize: 32
                            color: "white"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                console.log("Launching Dispenser " + selectedDispenser)
                            }
                        }
                    }

                    Rectangle {
                        width: 40
                        height: 40
                        color: "gray"
                        anchors.right: parent.right

                        Text {
                            anchors.centerIn: parent
                            text: "☰"
                            color: "white"
                            font.pixelSize: 24
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                openClosePopup.visible = !openClosePopup.visible
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: openClosePopup
                visible: false
                width: 200
                height: 60
                color: "#333"
                radius: 8
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 8

                Row {
                    spacing: 10
                    anchors.centerIn: parent

                    Rectangle {
                        width: 80
                        height: 40
                        radius: 8
                        color: openArea.pressed ? "#3d3d3d" : (openArea.containsMouse ? "#2a2a2a" : "transparent")

                        MouseArea {
                            id: openArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                console.log("Open Dispenser clicked")
                                qgcApp.startUdpSender()
                                openClosePopup.visible = false
                            }
                        }

                        Text {
                            text: "Open"
                            color: "white"
                            font.pixelSize: 16
                            anchors.centerIn: parent
                        }
                    }

                    Rectangle {
                        width: 80
                        height: 40
                        radius: 8
                        color: closeArea.pressed ? "#3d3d3d" : (closeArea.containsMouse ? "#2a2a2a" : "transparent")

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                console.log("Close Dispenser clicked")
                                qgcApp.startUdpCloseSender()
                                openClosePopup.visible = false
                            }
                        }

                        Text {
                            text: "Close"
                            color: "white"
                            font.pixelSize: 16
                            anchors.centerIn: parent
                        }
                    }
                }
            }

            Rectangle {
                id: editPopup
                visible: false
                width: 300
                height: 200
                color: "#333"
                radius: 8
                anchors.centerIn: parent
                z: 999

                property string dispenserId: ""
                property string dispenserName: ""
                property real dispenserLatitude: 0
                property real dispenserLongitude: 0

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "Edit Dispenser " + editPopup.dispenserId
                        color: "white"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Row {
                        spacing: 8
                        Text {
                            text: "Name:"
                            color: "white"
                            font.pixelSize: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        TextField {
                            text: editPopup.dispenserName
                            color: "white"
                            font.pixelSize: 16
                            background: Rectangle {
                                color: "#555"
                                radius: 5
                            }
                            onTextChanged: editPopup.dispenserName = text
                        }
                    }

                    Row {
                        spacing: 8
                        Text {
                            text: "Latitude:"
                            color: "white"
                            font.pixelSize: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        TextField {
                            text: editPopup.dispenserLatitude
                            color: "white"
                            font.pixelSize: 16
                            background: Rectangle {
                                color: "#555"
                                radius: 5
                            }
                            onTextChanged: editPopup.dispenserLatitude = parseFloat(text) || 0
                        }
                    }

                    Row {
                        spacing: 8
                        Text {
                            text: "Longitude:"
                            color: "white"
                            font.pixelSize: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        TextField {
                            text: editPopup.dispenserLongitude
                            color: "white"
                            font.pixelSize: 16
                            background: Rectangle {
                                color: "#555"
                                radius: 5
                            }
                            onTextChanged: editPopup.dispenserLongitude = parseFloat(text) || 0
                        }
                    }

                    Row {
                        spacing: 10
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            width: 80
                            height: 40
                            radius: 8
                            color: saveArea.pressed ? "#3d3d3d" : (saveArea.containsMouse ? "#2a2a2a" : "green")

                            MouseArea {
                                id: saveArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {

					dispenserData[editPopup.dispenserId].name =editPopup.dispenserName
					dispenserData[editPopup.dispenserId].latitude = editPopup.dispenserLatitude
					dispenserData[editPopup.dispenserId].longitude = editPopup.dispenserLongitude
					dispenserData = dispenserData


					var newList = Object.values(dispenserData).map(item => item.name)
					dispenserList = newList								
					dispenserSettings.savedDispenserData = dispenserData

					editPopup.visible = false

                                }
                            }

                            Text {
                                text: "Save"
                                color: "white"
                                font.pixelSize: 16
                                anchors.centerIn: parent
                            }
                        }

                        Rectangle {
                            width: 80
                            height: 40
                            radius: 8
                            color: cancelArea.pressed ? "#3d3d3d" : (cancelArea.containsMouse ? "#2a2a2a" : "red")

                            MouseArea {
                                id: cancelArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    editPopup.visible = false
                                }
                            }

                            Text {
                                text: "Cancel"
                                color: "white"
                                font.pixelSize: 16
                                anchors.centerIn: parent
				}
                            }
                        }
                    }
                }
            }
        }
    

    Connections {
        target: receivers["1"].udp
        function onMessageReceived(message) {
            console.log("Received UDP message for dispenser 1:", message)
            dispenserData["1"].status = message.trim()
            dispenserData = dispenserData
        }
    }

    Connections {
        target: receivers["1"].temperature
        function onTemperatureReceived(temperature) {
            console.log("temperature for dispenser 1:", temperature)
            dispenserData["1"].temperature = temperature.trim()
            dispenserData = dispenserData
        }
    }

*/

/////////////////////////////////////////////////////////////////////////////////

/*

 //Fungerende

property var dispenserData: {
	"1": {

	status: "No message received",
	temperature: " ",
	humidity: " ", 
	chargerStatus: "Unknown", 
        errors: "NONE",
        latitude: 59.6574100,  // cribben
        longitude: 9.6441920   // cribben
    },

    "2": { 
        status: "No message received", 
        temperature: "pending...", 
        humidity: "25", 
        chargerStatus: "CHARGING", 
        errors: "NONE",
        latitude: 59.6555001,  
        longitude: 9.6457272
    }
}



// receiver for hver dispenser, pga scalability

property var receivers: {
	"1": {udp: udpReceiver, temperature: temperatureReceiver},
	"2": {udp: null, temperature: null }
}



Item {
    width: parent.width
    height: 95
    anchors.top: parent.top
    anchors.topMargin: -16


    // Centered logo
    MouseArea {
        id: logoButton
        width: 95
        height: 95
        anchors.horizontalCenter: parent.horizontalCenter
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            drawer.visible = !drawer.visible
        }

        Image {
            anchors.fill: parent
            source: "qrc:/qmlimages/kestrelLogo.svg"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    // Dispenser status text to the right of the logo
    Text {
        id: dispenserStatusText
        //text: "Dispenser status: " + udpMessage
	text: "Dispenser status: " + dispenserData[selectedDispenser].status
        color: "white"
        font.pixelSize: 18
        font.bold: true
        anchors.verticalCenter: logoButton.verticalCenter
        anchors.left: logoButton.right
        anchors.leftMargin: 12
    }

    // Drawer-style dropdown menu
    Rectangle {
        id: drawer
        width: 600  // Wider to accommodate two columns
        height: 300
        visible: false  // Set to true to debug visibility
        color: "#1e1e1e"
        radius: 12
        z: 998
        anchors.top: logoButton.bottom
        anchors.horizontalCenter: logoButton.horizontalCenter
        anchors.topMargin: 8
        border.color: "#3c3c3c"
        border.width: 1

        layer.enabled: true
        layer.effect: DropShadow {
            color: "#000000"
            radius: 8
            samples: 16
            verticalOffset: 4
        }

        Row {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            // Left: Dispenser List
            Rectangle {
                width: 150
                height: parent.height
                color: "#2b2b2b"
                radius: 8

                ListView {
                    anchors.fill: parent
                    anchors.margins: 8
                    model: dispenserList
                    delegate: Rectangle {
                        width: parent.width
                        height: 40
                        color: selectedDispenser === modelData.split(" ")[1] ? "#3d3d3d" : "transparent"
                        Text {
                            text: modelData
                            color: "white"
                            font.pixelSize: 16
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                selectedDispenser = modelData.split(" ")[1]
                                // Optionally update status fields dynamically here
                            }
                        }
                    }
                }
            }

            // Right: Dispenser Details
            Column {
                spacing: 12
                width: parent.width - 150 - 16  // Adjust for left panel and spacing

                // Header
                Text {
                   text: "Dispenser " + selectedDispenser// .split(" ")[1] //make header not become (dispenser dispenser 1)

                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }

                // Status Fields
		/*
                Text { text: "Status: " + dispenserData[SelectedDispenser].status; color: "lightgray"; font.pixelSize: 16 }
                Text { text: "Temperature: " + temperature + "°C"; color: "lightgray"; font.pixelSize: 16 }
                Text { text: "Humidity: " + humidity + "%"; color: "lightgray"; font.pixelSize: 16 }
                Text { text: "Charger Status: " + chargerStatus; color: "lightgray"; font.pixelSize: 16 }
                Text { text: "Errors: " + errorMessage; color: "lightgray"; font.pixelSize: 16 }
		*/
        /*

		Text { text: "Status: " + dispenserData[selectedDispenser].status; color: "lightgray"; font.pixelSize: 16 }  // Was: "Status: " + dispenserStatus
		Text { text: "Temperature: " + dispenserData[selectedDispenser].temperature + "°C"; color: "lightgray"; font.pixelSize: 16 }  // Was: "Temperature: " + temperature + "°C"
		Text { text: "Humidity: " + dispenserData[selectedDispenser].humidity + "%"; color: "lightgray"; font.pixelSize: 16 }  // Was: "Humidity: " + humidity + "%"
		Text { text: "Charger Status: " + dispenserData[selectedDispenser].chargerStatus; color: "lightgray"; font.pixelSize: 16 }  // Was: "Charger Status: " + chargerStatus
		Text { text: "Errors: " + dispenserData[selectedDispenser].errors; color: "lightgray"; font.pixelSize: 16 }  // Was: "Errors: " + errorMessage




                // Launch Button
                Rectangle {
                    width: 300
                    height: 60
                    color: "red"
                    radius: 10

                    Text {
                        anchors.centerIn: parent
                        text: "LAUNCH"
                        font.bold: true
                        font.pixelSize: 32
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            console.log("Launching Dispenser " + selectedDispenser)
                            // Add launch functionality here
                        }
                    }
                }

                // Menu Button for Open/Close Pop-up (Placeholder for missing menu.svg)
                Rectangle {
                    width: 40
                    height: 40
                    color: "gray"  // Placeholder for missing menu.svg
                    anchors.right: parent.right

                    Text {
                        anchors.centerIn: parent
                        text: "☰"  // Placeholder icon
                        color: "white"
                        font.pixelSize: 24
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            openClosePopup.visible = !openClosePopup.visible
                        }
                    }
                }
            }
        }

        // Bottom Pop-up for Open/Close
        Rectangle {
            id: openClosePopup
            visible: false
            width: 200
            height: 60
            color: "#333"
            radius: 8
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 8

            Row {
                spacing: 10
                anchors.centerIn: parent

                Rectangle {
                    width: 80
                    height: 40
                    radius: 8
                    color: openArea.pressed ? "#3d3d3d" : (openArea.containsMouse ? "#2a2a2a" : "transparent")

                    MouseArea {
                        id: openArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            console.log("Open Dispenser clicked")
                            qgcApp.startUdpSender()
                            openClosePopup.visible = false
                        }
                    }

                    Text {
                        text: "Open"
                        color: "white"
                        font.pixelSize: 16
                        anchors.centerIn: parent
                    }
                }

                Rectangle {
                    width: 80
                    height: 40
                    radius: 8
                    color: closeArea.pressed ? "#3d3d3d" : (closeArea.containsMouse ? "#2a2a2a" : "transparent")

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            console.log("Close Dispenser clicked")
                            qgcApp.startUdpCloseSender()
                            openClosePopup.visible = false
                        }
                    }

                    Text {
                        text: "Close"
                        color: "white"
                        font.pixelSize: 16
                        anchors.centerIn: parent
                    }
                }
            }
        }
    }

    Connections {
        //target: udpReceiver
	target: receivers["1"].udp
        function onMessageReceived(message) {
            console.log("Received UDP message for dispenser 1:", message)
	    dispenserData["1"].status = message.trim()
	    dispenserData = dispenserData	
            //udpMessage = message.trim()
        }
    }

    Connections {
        //target: temperatureReceiver
	target: receivers["1"].temperature
        function onTemperatureReceived(temperature) {
            console.log("temperature for dispenser 1:", temperature)
	    dispenserData["1"].temperature = temperature.trim()
	    dispenserData = dispenserData	
            //temperatureMessage = temperature.trim()
        }
    }
}

*/

////////////////

// Den som fungerer

/*

Item {

//add in connections here?


///





    width: parent.width
    height: 95
    anchors.top: parent.top
    anchors.topMargin: -16

    // Centered logo
    MouseArea {
        id: logoButton
        width: 95
        height: 95
        anchors.horizontalCenter: parent.horizontalCenter
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            drawer.visible = !drawer.visible
        }



        Image {
            anchors.fill: parent
            source: "qrc:/qmlimages/kestrelLogo.svg"
            fillMode: Image.PreserveAspectFit
            smooth: true
  //      }
    }
}


    // Dispenser status text to the right of the logo
    Text {
        id: dispenserStatusText
        text: "Dispenser status: " + udpMessage
        color: "white"
        font.pixelSize: 18
        font.bold: true
        anchors.verticalCenter: logoButton.verticalCenter
        anchors.left: logoButton.right
        anchors.leftMargin: 12
    }




// Drawer-style dropdown menu
Rectangle {
    id: drawer
    width: 280
    height: 200
    visible: false
    color: "#1e1e1e"
    radius: 12
    z: 998
//    anchors.top: topOverlayButton.bottom
//    anchors.horizontalCenter: topOverlayButton.horizontalCenter
	 anchors.top: logoButton.bottom
         anchors.horizontalCenter: logoButton.horizontalCenter


    anchors.topMargin: 8
    border.color: "#3c3c3c"
    border.width: 1

    layer.enabled: true
    layer.effect: DropShadow {
        color: "#000000"
        radius: 8
        samples: 16
        verticalOffset: 4
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        // Open Dispenser Button
        Rectangle {
            width: parent.width
            height: 40
            radius: 8
            color: openArea.pressed ? "#3d3d3d" : (openArea.containsMouse ? "#2a2a2a" : "transparent")

            MouseArea {
                id: openArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    console.log("Open Dispenser clicked")
                   // drawer.visible = false
		    qgcApp.startUdpSender();
                }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12

                // Optional icon
                // Image {
                //     source: "/qmlimages/Plan.svg"
                //     width: 24
                //     height: 24
                // }

                Text {
                    text: "Open Dispenser"
                    color: "white"
                    font.pixelSize: 16
                }
            }
        }

        // Close Dispenser Button
        Rectangle {
            width: parent.width
            height: 40
            radius: 8
            color: closeArea.pressed ? "#3d3d3d" : (closeArea.containsMouse ? "#2a2a2a" : "transparent")

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    console.log("Close Dispenser clicked")
                    //drawer.visible = false
		    qgcApp.startUdpCloseSender();
                }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12

                // Optional icon
                // Image {
                //     source: "/qmlimages/Analyze.svg"
                //     width: 24
                //     height: 24
                // }

                Text {
                    text: "Close Dispenser"
                    color: "white"
                    font.pixelSize: 16
                }
            }
        }

	
	Connections {  // kan være at temperature rev skal inn her......
	  target: udpReceiver
	 
	  function onMessageReceived(message) {
              console.log("Received UDP message:", message);
              udpMessage = message.trim(); // ta vekk ekstra ekstra fra data pakken
          }
      }








	  Connections {
              target: temperatureReceiver
 
              function onTemperatureReceived(temperature) {
                  console.log("temperature:", temperature);
                  temperatureMessage = temperature.trim();
              }
          }

	



        // Temperature display
        Text {
            text: "Temprature: " + temperatureMessage + "°C"        //  "℃"
            color: "lightgray"
            width: parent.width
            font.pixelSize: 16
            horizontalAlignment: Text.AlignLeft
	 // wrapMode: Text.NoWrap  // make sure celsius stays on same line
            elide: Text.ElideNone // make sure celsius stays on same line 
	    maximumLineCount : 1   // make sure celsius stays on same line	   
	 }
       }
    }
}

*/







//kest2

/*
	
property string udpMessage: "No message received"  // standard message for UI text box (received msg)  
property string temperatureMessage: " XX " 


Column {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.margins: 20
    spacing: 15

    Rectangle {
        width: 300
        height: 60
        border.width: 2
        border.color: "black"
        radius: 10
        color: "white"

        Text {
            id: receivedText
            text: "Received: " + udpMessage
            font.pixelSize: 18
            font.bold: true
            anchors.centerIn: parent
        }
    }

    Connections {  // kan være at temperature rev skal inn her......
        target: udpReceiver

        function onMessageReceived(message) {
            console.log("Received UDP message:", message);
            udpMessage = message.trim(); // ta vekk ekstra ekstra fra data pakken
        }
    }



    // Button 1 - Open Dispenser
    Button {
        width: 200
        height: 60
        background: Rectangle {
            id: openButtonBg
            radius: 15
            border.width: 2
            color: "white"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: openButtonBg.color = "#DDDDDD"
                onExited: openButtonBg.color = "white"
            }
        }

        contentItem: Text {
            text: "Open Dispenser"
            font.pixelSize: 18
            font.bold: true
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            anchors.centerIn: parent
        }

        onClicked: {
            console.log("Opening Dispenser...");
            qgcApp.startUdpSender()
        }
    }

    // Button 2 - Close Dispenser
    Button {
        width: 200
        height: 60
        background: Rectangle {
            id: closeButtonBg
            radius: 15
            border.width: 2
            color: "white"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: closeButtonBg.color = "#DDDDDD"
                onExited: closeButtonBg.color = "white"
            }
        }

        contentItem: Text {
            text: "Close Dispenser"
            font.pixelSize: 18
            font.bold: true
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            anchors.centerIn: parent
        }

        onClicked: {
            console.log("Close Dispenser Clicked!")
            qgcApp.startUdpCloseSender()
        }
    }

    // textfield - Temperature
    Rectangle {
        width: 200
        height: 80
        border.width: 2
	border.color: "black"
	radius: 10
        color: "white"

            Text {
                id: temperatureText
                text: "Dispenser temperature: " + temperatureMessage // add C
                font.pixelSize: 20
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }
        }

	
    Connections {
        target: temperatureReceiver

        function onTemperatureReceived(temperature) {
            console.log("temperature:", temperature);
            temperatureMessage = temperature.trim();
        }
    }

	
}



*/
///



    footer: LogReplayStatusBar {
        visible: QGroundControl.settingsManager.flyViewSettings.showLogReplayStatusBar.rawValue
    }

    function showToolSelectDialog() {
        if (mainWindow.allowViewSwitch()) {
            mainWindow.showIndicatorDrawer(toolSelectComponent, null)
        }
    }

    Component {
        id: toolSelectComponent

        ToolIndicatorPage {
            id:         toolSelectDialog
            //title:      qsTr("Select Tool")

            property real _toolButtonHeight:    ScreenTools.defaultFontPixelHeight * 3
            property real _margins:             ScreenTools.defaultFontPixelWidth

            contentComponent: Component {
                ColumnLayout {
                    width:  innerLayout.width + (toolSelectDialog._margins * 2)
                    height: innerLayout.height + (toolSelectDialog._margins * 2)

                    ColumnLayout {
                        id:             innerLayout
                        Layout.margins: toolSelectDialog._margins
                        spacing:        ScreenTools.defaultFontPixelWidth

                        SubMenuButton {
                            height:             toolSelectDialog._toolButtonHeight
                            Layout.fillWidth:   true
                            text:               qsTr("Plan Flight")
                            imageResource:      "/qmlimages/Plan.svg"
                            onClicked: {
                                if (mainWindow.allowViewSwitch()) {
                                    mainWindow.closeIndicatorDrawer()
                                    mainWindow.showPlanView()
                                }
                            }
                        }

                        SubMenuButton {
                            id:                 analyzeButton
                            height:             toolSelectDialog._toolButtonHeight
                            Layout.fillWidth:   true
                            text:               qsTr("Analyze Tools")
                            imageResource:      "/qmlimages/Analyze.svg"
                            visible:            QGroundControl.corePlugin.showAdvancedUI
                            onClicked: {
                                if (mainWindow.allowViewSwitch()) {
                                    mainWindow.closeIndicatorDrawer()
                                    mainWindow.showAnalyzeTool()
                                }
                            }
                        }

                        SubMenuButton {
                            id:                 setupButton
                            height:             toolSelectDialog._toolButtonHeight
                            Layout.fillWidth:   true
                            text:               qsTr("Vehicle Configuration")
                            imageResource:      "/qmlimages/Gears.svg"
                            onClicked: {
                                if (mainWindow.allowViewSwitch()) {
                                    mainWindow.closeIndicatorDrawer()
                                    mainWindow.showVehicleConfig()
                                }
                            }
                        }

                        SubMenuButton {
                            id:                 settingsButton
                            height:             toolSelectDialog._toolButtonHeight
                            Layout.fillWidth:   true
                            text:               qsTr("Application Settings")
                            imageResource:      "/res/QGCLogoFull.svg"
                            imageColor:         "transparent"
                            visible:            !QGroundControl.corePlugin.options.combineSettingsAndSetup
                            onClicked: {
                                if (mainWindow.allowViewSwitch()) {
                                    drawer.close()
                                    mainWindow.showSettingsTool()
                                }
                            }
                        }

                        SubMenuButton {
                            id:                 closeButton
                            height:             toolSelectDialog._toolButtonHeight
                            Layout.fillWidth:   true
                            text:               qsTr("Close %1").arg(QGroundControl.appName)
                            imageResource:      "/res/cancel.svg"
                            visible:            mainWindow.visibility === Window.FullScreen
                            onClicked: {
                                if (mainWindow.allowViewSwitch()) {
                                    mainWindow.finishCloseProcess()
                                }
                            }
                        }

                        ColumnLayout {
                            width:                  innerLayout.width
                            spacing:                0
                            Layout.alignment:       Qt.AlignHCenter

                            QGCLabel {
                                id:                     versionLabel
                                text:                   qsTr("%1 Version").arg(QGroundControl.appName)
                                font.pointSize:         ScreenTools.smallFontPointSize
                                wrapMode:               QGCLabel.WordWrap
                                Layout.maximumWidth:    parent.width
                                Layout.alignment:       Qt.AlignHCenter
                            }

                            QGCLabel {
                                text:                   QGroundControl.qgcVersion
                                font.pointSize:         ScreenTools.smallFontPointSize
                                wrapMode:               QGCLabel.WrapAnywhere
                                Layout.maximumWidth:    parent.width
                                Layout.alignment:       Qt.AlignHCenter

                                QGCMouseArea {
                                    id:                 easterEggMouseArea
                                    anchors.topMargin:  -versionLabel.height
                                    anchors.fill:       parent

                                    onClicked: (mouse) => {
                                        console.log("clicked")
                                        if (mouse.modifiers & Qt.ControlModifier) {
                                            QGroundControl.corePlugin.showTouchAreas = !QGroundControl.corePlugin.showTouchAreas
                                            showTouchAreasNotification.open()
                                        } else if (ScreenTools.isMobile || mouse.modifiers & Qt.ShiftModifier) {
                                            if(!QGroundControl.corePlugin.showAdvancedUI) {
                                                advancedModeOnConfirmation.open()
                                            } else {
                                                advancedModeOffConfirmation.open()
                                            }
                                        }
                                    }

                                    // This allows you to change this on mobile
                                    onPressAndHold: {
                                        QGroundControl.corePlugin.showTouchAreas = !QGroundControl.corePlugin.showTouchAreas
                                        showTouchAreasNotification.open()
                                    }

                                    MessageDialog {
                                        id:                 showTouchAreasNotification
                                        title:              qsTr("Debug Touch Areas")
                                        text:               qsTr("Touch Area display toggled")
                                        buttons:            MessageDialog.Ok
                                    }

                                    MessageDialog {
                                        id:                 advancedModeOnConfirmation
                                        title:              qsTr("Advanced Mode")
                                        text:               QGroundControl.corePlugin.showAdvancedUIMessage
                                        buttons:            MessageDialog.Yes | MessageDialog.No
                                        onButtonClicked: function (button, role) {
                                            switch (button) {
                                            case MessageDialog.Yes:
                                                QGroundControl.corePlugin.showAdvancedUI = true
                                                advancedModeOnConfirmation.close()
                                                break;
                                            }
                                        }
                                    }

                                    MessageDialog {
                                        id:                 advancedModeOffConfirmation
                                        title:              qsTr("Advanced Mode")
                                        text:               qsTr("Turn off Advanced Mode?")
                                        buttons:            MessageDialog.Yes | MessageDialog.No
                                        onButtonClicked: function (button, role) {
                                            switch (button) {
                                            case MessageDialog.Yes:
                                                QGroundControl.corePlugin.showAdvancedUI = false
                                                advancedModeOffConfirmation.close()
                                                break;
                                            case MessageDialog.No:
                                                resetPrompt.close()
                                                break;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Drawer {
        id:             toolDrawer
        width:          mainWindow.width
        height:         mainWindow.height
        edge:           Qt.LeftEdge
        dragMargin:     0
        closePolicy:    Drawer.NoAutoClose
        interactive:    false
        visible:        false

        property var backIcon
        property string toolTitle
        property alias toolSource:  toolDrawerLoader.source
        property var toolIcon

        // Unload the loader only after closed, otherwise we will see a "blank" loader in the meantime
        onClosed: {
            toolDrawer.toolSource = ""
        }
        
        Rectangle {
            id:             toolDrawerToolbar
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    parent.top
            height:         ScreenTools.toolbarHeight
            color:          qgcPal.toolbarBackground

            RowLayout {
                id:                 toolDrawerToolbarLayout
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                anchors.left:       parent.left
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                spacing:            ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    font.pointSize: ScreenTools.largeFontPointSize
                    text:           "<"
                }

                QGCLabel {
                    id:             toolbarDrawerText
                    text:           qsTr("Exit") + " " + toolDrawer.toolTitle
                    font.pointSize: ScreenTools.largeFontPointSize
                }
            }

            QGCMouseArea {
                anchors.fill: toolDrawerToolbarLayout
                onClicked: {
                    if (mainWindow.allowViewSwitch()) {
                        toolDrawer.visible = false
                    }
                }
            }
        }

        Loader {
            id:             toolDrawerLoader
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    toolDrawerToolbar.bottom
            anchors.bottom: parent.bottom

            Connections {
                target:                 toolDrawerLoader.item
                ignoreUnknownSignals:   true
                onPopout:               toolDrawer.visible = false
            }
        }
    }

    //-------------------------------------------------------------------------
    //-- Critical Vehicle Message Popup

    function showCriticalVehicleMessage(message) {
        closeIndicatorDrawer()
        if (criticalVehicleMessagePopup.visible || QGroundControl.videoManager.fullScreen) {
            // We received additional warning message while an older warning message was still displayed.
            // When the user close the older one drop the message indicator tool so they can see the rest of them.
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = true
        } else {
            criticalVehicleMessagePopup.criticalVehicleMessage      = message
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false
            criticalVehicleMessagePopup.open()
        }
    }

    Popup {
        id:                 criticalVehicleMessagePopup
        y:                  ScreenTools.toolbarHeight + ScreenTools.defaultFontPixelHeight
        x:                  Math.round((mainWindow.width - width) * 0.5)
        width:              mainWindow.width  * 0.55
        height:             criticalVehicleMessageText.contentHeight + ScreenTools.defaultFontPixelHeight * 2
        modal:              false
        focus:              true

        property alias  criticalVehicleMessage:             criticalVehicleMessageText.text
        property bool   additionalCriticalMessagesReceived: false

        background: Rectangle {
            anchors.fill:   parent
            color:          qgcPal.alertBackground
            radius:         ScreenTools.defaultFontPixelHeight * 0.5
            border.color:   qgcPal.alertBorder
            border.width:   2

            Rectangle {
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.top:                parent.top
                anchors.topMargin:          -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      vehicleWarningLabel.contentWidth + _margins
                height:                     vehicleWarningLabel.contentHeight + _margins

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 vehicleWarningLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Vehicle Error")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }

            Rectangle {
                id:                         additionalErrorsIndicator
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.bottom:             parent.bottom
                anchors.bottomMargin:       -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      additionalErrorsLabel.contentWidth + _margins
                height:                     additionalErrorsLabel.contentHeight + _margins
                visible:                    criticalVehicleMessagePopup.additionalCriticalMessagesReceived

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 additionalErrorsLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Additional errors received")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }
        }

        QGCLabel {
            id:                 criticalVehicleMessageText
            width:              criticalVehicleMessagePopup.width - ScreenTools.defaultFontPixelHeight
            anchors.centerIn:   parent
            wrapMode:           Text.WordWrap
            color:              qgcPal.alertText
            textFormat:         TextEdit.RichText
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                criticalVehicleMessagePopup.close()
                if (criticalVehicleMessagePopup.additionalCriticalMessagesReceived) {
                    criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false;
                    flyView.dropMainStatusIndicatorTool();
                } else {
                    QGroundControl.multiVehicleManager.activeVehicle.resetErrorLevelMessages();
                }
            }
        }
    }

    //-------------------------------------------------------------------------
    //-- Indicator Drawer

    function showIndicatorDrawer(drawerComponent, indicatorItem) {
        indicatorDrawer.sourceComponent = drawerComponent
        indicatorDrawer.indicatorItem = indicatorItem
        indicatorDrawer.open()
    }

    function closeIndicatorDrawer() {
        indicatorDrawer.close()
    }

    Popup {
        id:             indicatorDrawer
        x:              calcXPosition()
        y:              ScreenTools.toolbarHeight + _margins
        leftInset:      0
        rightInset:     0
        topInset:       0
        bottomInset:    0
        padding:        _margins * 2
        visible:        false
        modal:          true
        focus:          true
        closePolicy:    Popup.CloseOnEscape | Popup.CloseOnPressOutside
        dim:            false

        property var sourceComponent
        property var indicatorItem

        property bool _expanded:    false
        property real _margins:     ScreenTools.defaultFontPixelHeight / 4

        function calcXPosition() {
            if (indicatorItem) {
                var xCenter = indicatorItem.mapToItem(mainWindow.contentItem, indicatorItem.width / 2, 0).x
                return Math.max(_margins, Math.min(xCenter - (contentItem.implicitWidth / 2), mainWindow.contentItem.width - contentItem.implicitWidth - _margins - (indicatorDrawer.padding * 2) - (ScreenTools.defaultFontPixelHeight / 2)))
            } else {
                return _margins
            }
        }

        onOpened: {
            _expanded                               = false;
            indicatorDrawerLoader.sourceComponent   = indicatorDrawer.sourceComponent
        }
        onClosed: {
            _expanded                               = false
            indicatorItem                           = undefined
            indicatorDrawerLoader.sourceComponent   = undefined
        }

        background: Item {
            Rectangle {
                id:             backgroundRect
                anchors.fill:   parent
                color:          QGroundControl.globalPalette.window
                radius:         indicatorDrawer._margins
                opacity:        0.85
            }

            Rectangle {
                anchors.horizontalCenter:   backgroundRect.right
                anchors.verticalCenter:     backgroundRect.top
                width:                      ScreenTools.largeFontPixelHeight
                height:                     width
                radius:                     width / 2
                color:                      QGroundControl.globalPalette.button
                border.color:               QGroundControl.globalPalette.buttonText
                visible:                    indicatorDrawerLoader.item && indicatorDrawerLoader.item.showExpand && !indicatorDrawer._expanded

                QGCLabel {
                    anchors.centerIn:   parent
                    text:               ">"
                    color:              QGroundControl.globalPalette.buttonText
                }  

                QGCMouseArea {
                    fillItem: parent
                    onClicked: indicatorDrawer._expanded = true
                }
            }
        }

        contentItem: QGCFlickable {
            id:             indicatorDrawerLoaderFlickable
            implicitWidth:  Math.min(mainWindow.contentItem.width - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2), indicatorDrawerLoader.width)
            implicitHeight: Math.min(mainWindow.contentItem.height - ScreenTools.toolbarHeight - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2), indicatorDrawerLoader.height)
            contentWidth:   indicatorDrawerLoader.width
            contentHeight:  indicatorDrawerLoader.height

            Loader {
                id: indicatorDrawerLoader

                Binding {
                    target:     indicatorDrawerLoader.item
                    property:   "expanded"
                    value:      indicatorDrawer._expanded
                }

                Binding {
                    target:     indicatorDrawerLoader.item
                    property:   "drawer"
                    value:      indicatorDrawer
                }
            }
        }
    }

    // We have to create the popup windows for the Analyze pages here so that the creation context is rooted
    // to mainWindow. Otherwise if they are rooted to the AnalyzeView itself they will die when the analyze viewSwitch
    // closes.

    function createrWindowedAnalyzePage(title, source) {
        var windowedPage = windowedAnalyzePage.createObject(mainWindow)
        windowedPage.title = title
        windowedPage.source = source
    }

    Component {
        id: windowedAnalyzePage

        Window {
            width:      ScreenTools.defaultFontPixelWidth  * 100
            height:     ScreenTools.defaultFontPixelHeight * 40
            visible:    true

            property alias source: loader.source

            Rectangle {
                color:          QGroundControl.globalPalette.window
                anchors.fill:   parent

                Loader {
                    id:             loader
                    anchors.fill:   parent
                    onLoaded:       item.popped = true
                }
            }

            onClosing: {
                visible = false
                source = ""
            }
        }
    }

    Connections{
         target: activationbar
         function onActivationTriggered(value){
              _utmspSendActTrigger= value
         }
    }

    UTMSPActivationStatusBar{
         id:                         activationbar
         activationStartTimestamp:   UTMSPStateStorage.startTimeStamp
         activationApproval:         UTMSPStateStorage.showActivationTab && QGroundControl.utmspManager.utmspVehicle.vehicleActivation
         flightID:                   UTMSPStateStorage.flightID
         anchors.fill:               parent
    }
}

