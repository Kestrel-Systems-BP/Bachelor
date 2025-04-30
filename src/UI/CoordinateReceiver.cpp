#include "CoordinateReceiver.h"
#include <QDebug>

CoordinateReceiver::CoordinateReceiver(QObject *parent)
    : QObject(parent), udpSocket(new QUdpSocket(this)) {
        qDebug() << "CoordinateReceiver starter opp";

    udpSocket->bind(QHostAddress::Any, 5009);
    connect(udpSocket, &QUdpSocket::readyRead, this, &CoordinateReceiver::readPendingDatagrams);
}

CoordinateReceiver::~CoordinateReceiver() {
    delete udpSocket;
}

void CoordinateReceiver::readPendingDatagrams() {
    while (udpSocket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(udpSocket->pendingDatagramSize());
        udpSocket->readDatagram(datagram.data(), datagram.size());

        QString coordinates = QString::fromUtf8(datagram).trimmed();
        qDebug() << "Received coordinates message:" << coordinates;


//make sure to trim for whitespace

	QStringList coordinatesList = coordinates.split(",");

	for (int i = 0; i < coordinatesList.size(); i++) {
		coordinatesList[i] = coordinatesList[i].trimmed();
	}




	if(coordinatesList.size() == 3) { // 2
		bool latitudeIsGood;
		bool longitudeIsGood;

		QString incidentType = coordinatesList[0];
		double latitude = coordinatesList[1].toDouble(&latitudeIsGood);
		double longitude = coordinatesList[2].toDouble(&longitudeIsGood);

		if(!incidentType.isEmpty() && latitudeIsGood && longitudeIsGood) {
			emit coordinatesReceived(incidentType, latitude, longitude);
			}

			else {
				qDebug() << "Parse coordinates failed" << coordinates;
				}
			}

		else {
			qDebug() << "bad coordinate format: "  << coordinates;
			}
    }
}





