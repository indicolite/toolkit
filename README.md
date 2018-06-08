# tools

- **loading/*.py**
This code used to handle a big single file and load the filtered data into database, whose performance boost from 700+s to 8+s.
- **loading/shadowsocks-all.sh**
This code is from teddysun.com, which used to function auto-deploy shadowsocks in one step.
```
    ./shadowsocks-all.sh 2>&1 | tee shadowsocks-all.log
```
- **selenium/shadow_qrcode.py**
This code simulates selenium to crawl dynamic data, and then into database, also saves to QRcode, periodically.
- **selenium/crawling_blog.py**
This code simulates selenium to crawl blog data in xiami.group and save data into local postgresql database.
- **centos/shell/tcpdump_mysql.sh**
This code uses tcpdump to catch sql info.
- **centos/elks/***
This code used to create pods and service to kubernetes logging system, say, efk logging-data.
- **md/***
This code used to record some paper work.
- **ansible/***
This code used to generate ansible example codes.
- **centos/***
This code refers to something automation about centos7, plus with rpms for working.
- **snippet/***
This code refers to some linux socket snippets.
