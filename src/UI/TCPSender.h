#ifndef TCPSENDER_H
#define TCPSENDER_H

#include <QObject>
#include <QTcpSocket>

class TCPSender : public QObject {
    Q_OBJECT
public:
    explicit TCPSender(QObject *parent = nullptr);
    Q_INVOKABLE void sendMessage(const QString &message);

private:
    QString _host = "100,119,202,115";  // Tailscale IP, RPI 
    quint16 _port = 5003;            // send on port 5003. Qt unsigned integer. 
};

#endif 
