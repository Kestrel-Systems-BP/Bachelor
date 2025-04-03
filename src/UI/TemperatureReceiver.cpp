#include "TemperatureReceiver.h"
#include <QDebug>

TemperatureReceiver::TemperatureReceiver(QObject *parent)
    : QObject(parent), udpSocket(new QUdpSocket(this)) {
	qDebug() << "Temperature Receiver starter opp";

    udpSocket->bind(QHostAddress::Any, 5007); // Listen on port 5007
    connect(udpSocket, &QUdpSocket::readyRead, this, &TemperatureReceiver::readPendingDatagrams);
}

TemperatureReceiver::~TemperatureReceiver() {
    delete udpSocket;
}

void TemperatureReceiver::readPendingDatagrams() {
    while (udpSocket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(udpSocket->pendingDatagramSize());
        udpSocket->readDatagram(datagram.data(), datagram.size());

        QString temperature = QString::fromUtf8(datagram);
        qDebug() << "Received temperature:" << temperature;

        emit temperatureReceived(temperature); // Send signal to UI
    }
}
