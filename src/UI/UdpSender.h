#ifndef UDPSENDER_H
#define UDPSENDER_H

#include <QObject>
#include <QUdpSocket>
#include <QTimer>

class UdpSender : public QObject {
    Q_OBJECT

public:
    explicit UdpSender(const QString& ip, quint16 port, QObject *parent = nullptr);
    ~UdpSender() override;
    void sendMessage();

private:
    QUdpSocket *udpSocket;
    QTimer timer;
    QString targetIp;
    quint16 targetPort;
};

#endif
