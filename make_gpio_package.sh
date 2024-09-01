#!/bin/bash

mkdir uconsole-cm4-gpio && mkdir uconsole-cm4-gpio/DEBIAN

mkdir -p uconsole-cm4-gpio/usr/local/bin 
mkdir -p uconsole-cm4-gpio/etc/systemd/system

cat << 'EOF' > uconsole-cm4-gpio/usr/local/bin/temp_fan_daemon.py
###devterm raspberry pi fan control daemon
import lgpio
import os
import time

def isDigit(x):
    try:
        float(x)
        return True
    except ValueError:
        return False

def measure_temp():
    temp = os.popen("/usr/bin/vcgencmd measure_temp").readline()
    temp2 = temp.replace("temp=","")
    temp3 = temp2.replace("'C","").strip()
    #print(temp3)
    if isDigit(temp3):
        return float(temp3)
    else:
        return 0


def init_fan_gpio():
    FAN = lgpio.gpiochip_open(0)
    lgpio.gpio_claim_output(FAN, PIN)
    
def fan_on():
    init_fan_gpio()
    lgpio.gpio_write(FAN, PIN, 1)

def fan_off():
    init_fan_gpio()
    lgpio.gpio_write(FAN, PIN, 0)


MAX_TEMP=65
PIN=17
init_fan_gpio()

while True:
    temp =  measure_temp()
    if(temp > MAX_TEMP):
        fan_on()
    else:
        fan_off()
    
    time.sleep(5)
EOF

cat << 'EOF' > uconsole-cm4-gpio/usr/local/bin/sound-patch.py
import lgpio
import time
import os
import sys

def start():
    try:
        open(path, "w").close()
        while os.path.exists(path):
            tmp = lgpio.gpio_read(headphones, 10)
            #print(tmp)
            if tmp == 0:
                #print("on")
                lgpio.gpio_write(speaker, 11, 1)
            elif tmp == 1:
                #print("off")
                lgpio.gpio_write(speaker, 11, 0)
            time.sleep(5)
    except:
        #Stop the speaker
        lgpio.gpio_write(speaker, 11, 0)
    stop()

def stop():
    # delete the file
    os.remove(path)
    lgpio.gpio_write(speaker, 11, 0)
    lgpio.gpiochip_close(speaker)
    lgpio.gpiochip_close(headphones)


speaker = lgpio.gpiochip_open(0)
lgpio.gpio_claim_output(speaker, 11)

headphones = lgpio.gpiochip_open(0)
lgpio.gpio_claim_input(headphones, 10)

path = "/tmp/.sound-patch"

if(sys.argv[1] == "start"):
    start()
elif(sys.argv[1] == "stop"):
    stop()
else:
    print("Invalid argument")

EOF

# 4gextension fix for Ubuntu / Armbian
cat << 'EOF' > uconsole-cm4-gpio/usr/local/bin/uconsole-4g-cm4.py
import lgpio
import time
import sys

def tip():
    print("use mmcli -L to see 4G modem or not")

def tip():
    print("use mmcli -L to see 4G modem or not")

def enable4g():
    print("Power on 4G module on uConsole cm4")

    h = lgpio.gpiochip_open(0)
    if h < 0:
        print("Can't open gpiochip")
        sys.exit()

    lgpio.gpio_claim_output(h, PIN_1)
    lgpio.gpio_claim_output(h, PIN_2)
    time.sleep(5)

    lgpio.gpio_write(h, PIN_1, 1)
    lgpio.gpio_write(h, PIN_2, 1)
    lgpio.gpio_write(h, PIN_2, 0)
    print("waiting...")
    time.sleep(13)
    print("done")

def disable4g():
    print("Power off 4G module on uConsole cm4")

    h = lgpio.gpiochip_open(0)
    if h < 0:
        print("Can't open gpiochip")
        sys.exit()
    lgpio.gpio_claim_output(h, PIN_1)

    lgpio.gpio_write(h, PIN_1, 0)
    lgpio.gpio_write(h, PIN_1, 1)
    time.sleep(3)
    lgpio.gpio_write(h, PIN_1, 0)
    time.sleep(20)
    print("Done")

PIN_1 = 24
PIN_2 = 15

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 uconsole-4g-cm4.py enable|disable")
        sys.exit(1)
    if sys.argv[1] == "enable":
        enable4g()
    elif sys.argv[1] == "disable":
        disable4g()
    else:
        print("Usage: python3 uconsole-4g-cm4.py enable|disable")
        tip()
        sys.exit(1)
    sys.exit(0)
EOF

cat << 'EOF' > uconsole-cm4-gpio/etc/systemd/system/devterm-fan-temp-daemon.service
[Unit]
Description=devterm raspberry pi cm4 fan control daemon

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/temp_fan_daemon.py


[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' > uconsole-cm4-gpio/etc/systemd/system/sound-patch.service
[Unit]
Description=Clockworkpi patch for audio speaker

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/sound-patch.py start &
ExecStop=/usr/bin/rm /tmp/.sound-patch
ExecStopPost=/usr/bin/python3 /usr/local/bin/sound-patch.py stop

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' > uconsole-cm4-gpio/etc/systemd/system/uconsole-4g-cm4.service
[Unit]
Description=4G extension patch service for ClockworkPi devices

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/uconsole-4g-cm4.py enable
ExecStop=/usr/bin/python3 /usr/local/bin/uconsole-4g-cm4.py disable

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' > uconsole-cm4-gpio/DEBIAN/control
Package: uconsole-cm4-gpio
Version: 0.2
Maintainer: ElijaxApps
Architecture: all
Description: uConsole CM4 GPIO control scripts.
EOF

chmod +x uconsole-cm4-gpio/usr/local/bin/sound-patch.py
chmod +x uconsole-cm4-gpio/usr/local/bin/uconsole-4g-cm4.py
chmod +x uconsole-cm4-gpio/usr/local/bin/temp_fan_daemon.py

#create postinst script
cat << 'EOF' > uconsole-cm4-gpio/DEBIAN/postinst
#!/bin/bash

systemctl daemon-reload

systemctl enable --now sound-patch.service
systemctl enable --now uconsole-4g-cm4.service
systemctl enable --now devterm-fan-temp-daemon.service

EOF

chmod +x uconsole-cm4-gpio/DEBIAN/postinst

dpkg-deb --build uconsole-cm4-gpio
