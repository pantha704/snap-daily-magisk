#!/system/bin/sh
sleep 15
setprop service.adb.tcp.port 5555
stop adbd
start adbd
