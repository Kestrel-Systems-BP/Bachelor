#ifndef PROXIMITYCALCULATOR_H
#define PROXIMITYCALCULATOR_H

#include <QObject>
#include <QGeoCoordinate>

class ProximityCalculator : public QObject {
    Q_OBJECT
public:
    explicit ProximityCalculator(QObject* parent = nullptr);
    Q_INVOKABLE double calculateDistance(double latitude1, double longitude1, double latitude2, double longitude2);
};

#endif
