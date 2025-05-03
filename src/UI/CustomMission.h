#ifndef CUSTOMMISSION_H
#define CUSTOMMISSION_H

#include <QObject>
#include "Vehicle.h"

class CustomMission : public QObject {
    Q_OBJECT
public:
    explicit CustomMission(QObject* parent = nullptr);

    // Q_INVOKABLE function to create a mission with provided coordinates
    Q_INVOKABLE void createAutomaticMission(Vehicle* vehicle, double latitude, double longitude, double altitude);
};

#endif // CUSTOMMISSION_H
