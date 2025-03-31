#ifndef UDPRECEIVER_H
#define UDPRECEIVER_H

#include <QObject>
#include <QUdpSocket>

class UdpReceiver : public QObject {
    Q_OBJECT
public:
    explicit UdpReceiver(QObject *parent = nullptr);
    ~UdpReceiver();

signals:
    void messageReceived(QString message); // Signal to update UI

private slots:
    void readPendingDatagrams(); // Handles incoming UDP packets

private:
    QUdpSocket *udpSocket;
};

#endif // UDPRECEIVER_H
