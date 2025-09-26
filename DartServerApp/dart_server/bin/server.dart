import 'dart:convert';
import 'dart:io';
import 'dart:math';

List<int> generatedNumbers = [];                  //存已經生成過的數字確保生成的數字不會重複
Map<String, Socket> connectClients = {};          //存每個client的資訊
void main() async {
  //連線
  final server = await ServerSocket.bind('0.0.0.0', 12345);
  print('TCP Server started on port 12345');

  int numberOfDevices = 0;
  int readyDevicesCount = 0;
  bool gameStarted = false;
  int okNumber = 0;

  await for (var socket in server) {
    print('Client connected: ${socket.remoteAddress}:${socket.remotePort}');
    numberOfDevices++;
    connectClients['${socket.remoteAddress}:${socket.remotePort}'] = socket;

    bool canSendNextNumber = false;       //是否可傳數字給client

    socket.listen(
      (List<int> data) async {
        final message = utf8.decode(data).trim();
        print('Received from client: $message');
        //判斷收到的訊息
        if (message == 'Ready') {
          //當遊戲還沒開始時要等待所有玩家都ready
          if (!gameStarted) {
            readyDevicesCount++;
          }
          //所有玩家都準備好時遊戲開始
          if (readyDevicesCount == numberOfDevices) {
            print('Numbers of device: $numberOfDevices');
            print('All clients ready, starting game');
            //要把訊息傳給所有client
            for (Socket socket in connectClients.values) {
              socket.write('game start');
            }
            gameStarted = true;
          }
        } 
        else if (message == 'ok') {
          //要等所有client都ok了才可以傳下一個數字
          okNumber++;
          if (okNumber == numberOfDevices) {
            canSendNextNumber = true;
          }
        } 
        else if (message == 'Game over') {
          print('Game over');
          for (Socket socket in connectClients.values) {
            socket.write('over');
          }
          //遊戲結束要將一些變數歸零
          numberOfDevices = 0;
          readyDevicesCount = 0;
          socket.close();
        } 
        else {
          print('Unknown message from client: $message');
          socket.write('Unknown message, closing connection');
          socket.close();
        }
        //當遊戲開始而且大家都ok則可以發送下一個數字
        if (gameStarted && canSendNextNumber) {
          sendNextNumber(socket, generatedNumbers);
          //ok的數量要歸零
          okNumber = 0;
          canSendNextNumber = false;
        }
      },
      onError: (error) {
        print('Error: $error');
        socket.close();
      },
      onDone: () {
        print('Client disconnected');
        readyDevicesCount--;
        numberOfDevices--;
        if (readyDevicesCount < 0) readyDevicesCount = 0;
      },
    );
  }
}
//隨機生成1~25但不重複的數字發送給clientS
void sendNextNumber(Socket socket, List<int> generatedNumbers) {
  final random = Random();
  int number;
  do {
    number = random.nextInt(25) + 1;
  } 
  while (generatedNumbers.contains(number));
  generatedNumbers.add(number);
  print('Sending number: $number');
  for (Socket socket in connectClients.values) {
    socket.write('$number');
  }
}
