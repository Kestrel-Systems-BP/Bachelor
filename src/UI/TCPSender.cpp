#include "TCPSender.h"
#include <QDebug>

TCPSender::TCPSender(QObject *parent) : QObject(parent) {}

void TCPSender::sendMessage(const QString &message) {
    QTcpSocket *socket = new QTcpSocket(this);
    socket->connectToHost(_host, _port);

    if (socket->waitForConnected(1000)) {
        socket->write(message.toUtf8());
        socket->flush();
        socket->waitForBytesWritten();
        socket->disconnectFromHost();
        qDebug() << "Sent TCP to raspberry pi:" << message;
    } 
	else {
        	qWarning() << "No connection to raspebrry pi.";
    }
}
