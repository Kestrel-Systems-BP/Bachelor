#pragma once

#include <QObject>
#include <QUdpSocket>

class sendUdp : public QObject {
    Q_OBJECT
public:
    explicit sendUdp(QObject* parent = nullptr);

    Q_INVOKABLE void open();
    Q_INVOKABLE void close();
    Q_INVOKABLE void startCharging();
    Q_INVOKABLE void stopCharging();
    Q_INVOKABLE void heartbeat();

//hei
	

private:
    //void sendMessage(const QString& message, quint16 port = 5005);
    void sendMessage(const QString& message, quint16 port = 5005, const QHostAddress& address = QHostAddress("100.119.202.115"));

};
