#include "UdpSender.h"
#include <QCoreApplication>
#include <QDebug>

UdpSender::UdpSender(const QString& ip, quint16 port, QObject *parent)
    : QObject(parent), udpSocket(new QUdpSocket(this)), targetIp(ip), targetPort(port) {}

UdpSender::~UdpSender() {
}

void UdpSender::sendMessage() {
    QByteArray datagram = "open";
    udpSocket->writeDatagram(datagram, QHostAddress(targetIp), targetPort);
    qDebug() << "Open, sent to:" << targetIp << ":" << targetPort;

    // Exit after sending
    QCoreApplication::quit();
}

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
   // UdpSender sender("172.20.10.2", 5005); // ras pi IP og port
    // UdpSender sender("192.168.8.10", 5005);
    // UdpSender sender("255.255.255.255", 5005);
	UdpSender sender("100.119.202.115", 5005);

    sender.sendMessage();

    return 0; 
}
