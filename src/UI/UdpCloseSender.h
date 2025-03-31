#ifndef UDPCLOSESENDER_H
#define UDPCLOSESENDER_H

#include <QObject>
#include <QUdpSocket>
#include <QTimer>

class UdpCloseSender : public QObject {
    Q_OBJECT 

public:
    explicit UdpCloseSender(const QString& ip, quint16 port, QObject *parent = nullptr);
    ~UdpCloseSender() override;
    void sendMessage();

private:
    QUdpSocket *udpSocket;
    QTimer timer;
    QString targetIp;
    quint16 targetPort;
};

#endif




