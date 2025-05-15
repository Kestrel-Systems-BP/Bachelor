#ifndef RECEIVETCP_H
#define RECEIVETCP_H

#include <QObject>
#include <QTcpServer>
#include <QTcpSocket>

class ReceiveTCP : public QObject {
    Q_OBJECT
public:
    explicit ReceiveTCP(QObject *parent = nullptr);
    void startListening(quint16 port = 5004);

signals:
    void temperatureReceived(const QString &temperature);
    void humidityReceived(const QString &humidity);
    void lidStatusReceived(const QString &lidStatus);
    void chargingStatusReceived(const QString &chargerStatus);

private slots:
    void handleNewConnection();

private:
    QTcpServer *server;
};

#endif // RECEIVETCP_H
