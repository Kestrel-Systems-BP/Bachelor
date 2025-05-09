#include "sendUdp.h"
#include <QDebug>

sendUdp::sendUdp(QObject* parent)
    : QObject(parent)
{
}

void sendUdp::sendMessage(const QString& message, quint16 port, const QHostAddress& address) {
    QUdpSocket socket;
    QByteArray datagram = message.toUtf8();
    socket.writeDatagram(datagram, address, port);
    qDebug() << "Sent UDP message:" << message << "to Dispenser";



}

void sendUdp::open() {
    sendMessage("open");
}

void sendUdp::close() {
    sendMessage("close");
}

void sendUdp::startCharging(){
    sendMessage("start");
}

void sendUdp::stopCharging() {
    sendMessage("stop");
}

void sendUdp::heartbeat(){
    sendMessage("heartbeat");
}
