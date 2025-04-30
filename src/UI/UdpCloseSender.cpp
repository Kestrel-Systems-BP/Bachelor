
#include "UdpCloseSender.h"
#include <QCoreApplication>
#include <QDebug>

UdpCloseSender::UdpCloseSender(const QString& ip, quint16 port, QObject *parent)
    : QObject(parent), udpSocket(new QUdpSocket(this)), targetIp(ip), targetPort(port) {}

UdpCloseSender::~UdpCloseSender() {
}

void UdpCloseSender::sendMessage() {
    QByteArray datagram = "Close";
    udpSocket->writeDatagram(datagram, QHostAddress(targetIp), targetPort);
    qDebug() << "Sent UDP message to" << targetIp << ":" << targetPort;

    QCoreApplication::quit();
}

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    //UdpCloseSender sender("172.20.10.2", 5005);
    //UdpCloseSender sender("192.168.8.11", 5005);
   // UdpCloseSender sender("192.168.8.10", 5005);
    // UdpCloseSender sender("255.255.255.255", 5005);
 	UdpCloseSender sender("100.119.202.115", 5005);

    sender.sendMessage();

    return 0;  
}



