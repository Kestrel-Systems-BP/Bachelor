import socket

pc_ip = "100.90.56.83"
udp_port = 5007

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

message = "69"
sock.sendto(message.encode(), (pc_ip, udp_port))

sock.close()
