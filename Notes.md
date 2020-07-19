# Membangun Mail Server sendiri dengan debian, postfi, dovecot dan Vimbadmin

1. Tentang Postfix
2. Persiapan untuk Mail Server
3. Install Postfix
4. Configure Postfix
5. Install Dovecot IMAP Server & Enable TLS Encryption

1) Tentang Postfix
   Postfix ini merupakan MTA (Message Transfer Agent) atau SMTP Server yang memiliki 2 tugas sekaligus:

   - Bertanggung jawab menerima email dari email client (outlook, thunderbird) atau MUA (Mail User Agent) ke remote SMTP Server
   - Bertanggung jawab menerima email dari SMTP Server lain.

   Postfix menggunakan protocol tcp port 25 untuk operasinya, harus dipastikan terlebih dahulu tcp/25 ini open baik inbound maupun outbond

2) Persiapan untuk Mail Server
   Yang harus disiapkan untuk menjalankan Mail Server:

   - domain name dengan record MX pada DNS mengarah ke FQDN (Fully Qualified Domain Name) yang tertuju pada IP Address Mail Server yang akan dipakai. Misal:
     - domainname: widiastono.my.id _#ns: ns1.widiastono.my.id, ns2.widiastono.my.id_
     - mail.widiastono.my.id IN A 192.168.1.100 _#mengarahkan mail.widiastono.my.id ke IP Address 192.168.1.100_
     - @ IN MX 10 mail.widiastono.my.id _#mengarahkan MX dari widiastono.my.id ke FQDN mail.widiastono.my.id dengan priority 10_
     - Set PTR record pada DNS IP Address, ada sebagian Mail Server di luar sana yang verifikasi dengan reverse DNS (PTR) apakah IP **192.168.1.100** benar diarahkan untuk domain **mail.widiastono.my.id**, setting di panel vps kalo kita pakai vps, jika lewat ISP silahkan hubungi ISPnya
     - Checking domain name dan PTR:
       ```
       whois widiastono.my.id #untuk melihat informasi domain termasuk arah ns-nya
       dig mail.widiastono.my.id #untuk melihat arah mail.widiastono.my.id sudah ke IP Address 192.168.1.100
       dig -t mx widiastono.my.id #untuk melihat apakah MX widiastono.my.id sudah benar ke mail.widiastono.my.id
       dig -x 192.168.1.100 # untuk melihat apakah IP 192.168.1.100 benar untuk FQDN mail.widiastono.my.id
       ```
   - pastikan hostname pada server sudah sesuai dengan FQDN diatast (mail.widiastono.my.id)
     - cek dengan : `sudo hostname -f` atau `sudo hostnamectl`
     - set hostname server: `hostnamectl mail.widiastono.my.id` lanjut logout - login lagi untuk mengaktifkannya

3) Install postfix

   ```
   sudo apt update -y
   sudo apt install -y postfix mailutils
   ```

   - pilih Internet Site _jika mail sever untuk ke Internet / LAN_
   - mail name _masukkan domainname-nya saja (widiastono.my.id), email-nya nanti jadi me@widiastono.my.id_
   - check installed postfix: `postconf mail_version`
   - test open port 25 baik inbound maupun outbond:
     - dari perangkat lain: `telnet mail.widiastono.my.id 25`
     - dari internal server: `telnet mail.google.com 25`

4) Configure Postfix

   - configure main.cf

     ```
     hostname = mail.widiastono.my.id
     ### standard attachment 10MB --> change to 25MB
     ### message_size_limit tdak boleh lebih besar dari mailbox_size_limit
     #message_size_limit = 10240000
     message_size_limit = 26214400

     ### standard mailbox_size_limit 48MB --> change to 50
     ### mailbox_size_limit = 0 --> 0 sama dengan unlimited
     #mailbox_size_limit = 51200000
     mailbox_size_limit = 52428800

     ### standard semua protocol ip dipakai baik ipv4 maupun ipv6 --> savely pakai ipv4
     #inet_protocols = all
     inet_protocols = ipv4
     ```

   - configure /etc/aliases

     ```
     # /etc/aliases
     mailer-daemon: postmaster
     postmaster: root
     nobody: root
     hostmaster: root
     usenet: root
     news: root
     webmaster: root
     www: root
     ftp: root
     abuse: root
     noc: root
     security: root
     root: widiastono
     ```

     karena root@widiastono.my.id jarang dipakai sebaiknya arahkan ke widiastono@widiastono.my.id (last-line) lalu jalankan: `sudo newaliases`

5) Install Dovecot IMAP Server & Enable TLS Encryption

   - pastikan port-port tcp berikut open dari luar: 80, 110, 443, 587, 465, 143, 993, 995
   - install certbot & plugin-nya untuk NGiNX

   ```
   sudo apt install -y certbot python3-certbot-nginx
   ```

   - create folder and change owner

     ```
     sudo mkdir /var/www/html/mail.widiastono.my.id
     sudo chown -R www-data:www-data /var/www/html/mail.widiastono.my.id
     ```

   - configure certbot

     ```
     sudo certbot --nginx --agree-tos --redirect --hsts --staple-ocsp --email widiastono@gmail.com -d mail.widiastono.my.id
     ```

   - configure submission (/etc/postfix/master.cf) --> open port 587 (STARTTLS)

     ```
     submission     inet     n    -    y    -    -    smtpd
       -o syslog_name=postfix/submission
       -o smtpd_tls_security_level=encrypt
       -o smtpd_tls_wrappermode=no
       -o smtpd_sasl_auth_enable=yes
       -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
       -o smtpd_recipient_restrictions=permit_mynetworks,permit_sasl_authenticated,reject
       -o smtpd_sasl_type=dovecot
       -o smtpd_sasl_path=private/auth
     ```

   - configure submission for Microsoft Outlook (/etc/postfix/master.cf) --> open port 465 (STARTTLS)

     ```
     smtps     inet  n       -       y       -       -       smtpd
       -o syslog_name=postfix/smtps
       -o smtpd_tls_wrappermode=yes
       -o smtpd_sasl_auth_enable=yes
       -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
       -o smtpd_recipient_restrictions=permit_mynetworks,permit_sasl_authenticated,reject
       -o smtpd_sasl_type=dovecot
       -o smtpd_sasl_path=private/auth
     ```

   - edit (/etc/postfix/main.cf) TLS parameter:

     ```
     smtpd_tls_cert_file=/etc/letsencrypt/live/mail.your-domain.com/fullchain.pem
     smtpd_tls_key_file=/etc/letsencrypt/live/mail.your-domain.com/privkey.pem
     smtpd_tls_security_level=may
     smtpd_tls_loglevel = 1
     smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache

     smtp_tls_security_level = may
     smtp_tls_loglevel = 1
     smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache

     #Enforce TLSv1.3 or TLSv1.2
     smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
     smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
     smtp_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
     smtp_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
     ```

   - restart postfix : `sudo service postfix restart`
   - install dovecot

   ```
   sudo apt install -y dovecot-core dovecot-imapd dovecot-pop3d
   sudo dovecot --version
   ```

   - Enabling IMAP/POP3 on Dovecot (/etc/dovecot/dovecot.conf)

   ```
   protocols = imap pop3
   ```

   - configure Maildir location (/etc/dovecot/conf.d/10-mail.conf)

   ```
   mail_location = maildir:~/Maildir
   mail_privileged_group = mail
   ```

   - adding dovecot to mail group

   ```
   sudo adduser dovecot mail
   ```

   - authentication mechanism (/etc/dovecot/conf.d/10-auth.conf)

     ```
     disable_plaintext_auth = yes
     ### username only without @domain.com
     auth_username_format = %n
     auth_mechanisms = plain login
     ```

   - configure SSL/TLS Encryption (/etc/dovecot/conf.d/10-ssl.conf)

     ```
     ssl = required
     ssl_cert = </etc/letsencrypt/live/mail.widiastono.my.id/fullchain.pem
     ssl_key = </etc/letsencrypt/live/mail.widiastono.my.id/privkey.pem
     ssl_prefer_server_ciphers = yes
     ssl_protocols = !SSLv3 !TLSv1 !TLSv1.1
     ssl_min_protocol = TLSv1.2
     ```

   - SSL Authentication between Postfix and Dovecot (/etc/dovecot/conf.d/master.conf)

   ```
   service auth {
       unix_listener /var/spool/postfix/private/auth {
         mode = 0660
         user = postfix
         group = postfix
       }
   }
   ```

   - Auto Create Folder (/etc/dovecot/conf.d/15-mailboxes.conf)

   ```
   mailbox Trash {
   auto = create
   special_use = \Trash
   }
   mailbox Junk {
   auto = create
   special_use = \Junk
   }
   mailbox Draft {
   auto = create
   special_use = \Draft
   }
   mailbox Sent {
   auto = create
   special_use = \Sent
   }
   ```

   - restart dovecot, restart postfix & check port 143, 993, 110 dan 995

   - install Dovecot LMTP Server: `sudo apt install -y dovecot-lmptd`
   - configure Dovecot LMTP Server (/etc/dovecot/dovecot.conf)

     ```
     protocols = imap pop3 lmtp
     ```

   - configure LMTP service (/etc/dovecot/conf.d/10-master.conf)

     ```
     service lmtp {
       unix_listener /var/spool/postfix/private/dovecot-lmtp {
         mode = 0600
         user = postfix
         group = postfix
       }
     }
     ```

     - configure postfix (/etc/postfix/main.cf)

     ```
     mailbox_transport = lmtp:unix:private/dovecot-lmtp
     smtputf8_enable = no
     ```

     - restart postfix & dovecot: `sudo systemctl restart postfix dovecot`
     - test dengan mail client (STARTTLS)

     - Auto Renew TLS Certificate (crontab)
       `@daily certbot renew --quiet && systemctl reload postfix dovecot nginx`
