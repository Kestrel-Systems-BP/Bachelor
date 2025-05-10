#include "receiveTCP.h"
#include <QStringList>
#include <QDebug>

ReceiveTCP::ReceiveTCP(QObject *parent) : QObject(parent) {
    server = new QTcpServer(this);
    connect(server, &QTcpServer::newConnection, this, &ReceiveTCP::handleNewConnection);
}

void ReceiveTCP::startListening(quint16 port) {
    if (!server->listen(QHostAddress::Any, port)) {
        qWarning() << "ReceiveTCP failed and is not working. Check directory /src/UI" << port;
    } else {
        qDebug() << "ReceiveTCP: started succesfully" << port;
    }
}

void ReceiveTCP::handleNewConnection() {
    QTcpSocket *socket = server->nextPendingConnection();

    connect(socket, &QTcpSocket::readyRead, this, [this, socket]() {
        const QString message = QString::fromUtf8(socket->readAll()).trimmed();
        qDebug() << "msg from dispenser:" << message;

        if (message.contains(',')) {
            QStringList parts = message.split(',');
            if (parts.size() == 2) {
                emit temperatureReceived(parts[0].trimmed());
                emit humidityReceived(parts[1].trimmed());
            }
        } else if (message == "Open" || message == "Closed") {
            emit lidStatusReceived(message);
        } else if (message == "Charging" || message == "Not charging") {
            emit chargingStatusReceived(message);
        } else {
            qWarning() << "ReceiveTCP: WRONG FORMAT!.";
        }
    });
}
