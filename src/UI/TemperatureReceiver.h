#ifndef TEMPERATURERECEIVER_H
#define TEMPERATURERECEIVER_H

#include <QObject>
#include <QUdpSocket>

class TemperatureReceiver : public QObject {
    Q_OBJECT
public:
    explicit TemperatureReceiver(QObject *parent = nullptr);
    ~TemperatureReceiver();

signals:
    void temperatureReceived(QString temperature); // Signal to update UI

private slots:
    void readPendingDatagrams(); // Handles incoming UDP packets

private:
    QUdpSocket *udpSocket;
};

#endif 
