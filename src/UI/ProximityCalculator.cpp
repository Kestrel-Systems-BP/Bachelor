#include "ProximityCalculator.h"
#include <cmath>

ProximityCalculator::ProximityCalculator(QObject* parent) : QObject(parent) {
}

double ProximityCalculator::calculateDistance(double latitude1, double longitude1, double latitude2, double longitude2) {


	const double radiusEarth = 6371e3; 

    	const double toRad = M_PI / 180.0;
   	const double phi1 = latitude1 * toRad;
    	const double phi2 = latitude2 * toRad;

    	const double deltaPhi = (latitude2 - latitude1) * toRad;
    	const double deltaLambda = (longitude2 - longitude1) * toRad;

    	const double a = std::sin(deltaPhi / 2) * std::sin(deltaPhi / 2) +
                     std::cos(phi1) * std::cos(phi2) *
                     std::sin(deltaLambda / 2) * std::sin(deltaLambda / 2);

    	const double c = 2 * std::atan2(std::sqrt(a), std::sqrt(1 - a));

    return radiusEarth * c; 
	//comes out as meters
}
