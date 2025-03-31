#include "UdpReceiver.h"
#include <QDebug>

UdpReceiver::UdpReceiver(QObject *parent)
    : QObject(parent), udpSocket(new QUdpSocket(this)) {
	qDebug() << "UdpReceiver starter opp";

    udpSocket->bind(QHostAddress::Any, 5006); // Listen on port 5006
    connect(udpSocket, &QUdpSocket::readyRead, this, &UdpReceiver::readPendingDatagrams);
}

UdpReceiver::~UdpReceiver() {
    delete udpSocket;
}

void UdpReceiver::readPendingDatagrams() {
    while (udpSocket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(udpSocket->pendingDatagramSize());
        udpSocket->readDatagram(datagram.data(), datagram.size());

        QString message = QString::fromUtf8(datagram);
        qDebug() << "Received UDP message:" << message;

        emit messageReceived(message); // Send signal to UI
    }
}
