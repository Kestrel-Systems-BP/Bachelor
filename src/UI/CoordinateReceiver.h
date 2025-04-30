#ifndef COORDINATERECEIVER_H
#define COORDINATERECEIVER_H

#include <QObject>
#include <QUdpSocket>

class CoordinateReceiver : public QObject {
    Q_OBJECT
public:
    explicit CoordinateReceiver(QObject *parent = nullptr);
    ~CoordinateReceiver();

signals:
    //void messageReceived(QString coordinates); // Signal to update UI
	void coordinatesReceived(QString accidentType, double latitude, double longitude);

private slots:
    void readPendingDatagrams(); 

private:
    QUdpSocket *udpSocket;
};

#endif 




