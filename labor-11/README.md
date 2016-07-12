##Title: Den vollen Verkehr mitschreiben und entschlüsseln

###Was machen wir?

Wir schreiben den vollen HTTP Verkehr mit. Dazu entschlüsseln wir wo nötig den Verkehr.

###Warum tun wir das?


Im Alltag kommt es immer wieder vor, dass beim Betrieb eines Webservers oder eines Reverse Proxies Fehler auftreten, die nur mit Mühe bearbeitet werden können. In zahlreichen Fällen fehlt die Klarheit, was genau durch die Leitung ging, oder es herrscht Uneinigkeit, welcher Kommunikationsteilnehmer den Fehler genau verursacht hat. In diesen Fällen ist es wichtig, den gesamten Verkehr mitschreiben zu können, um auf dieser Basis den Fehler zu isolieren.

###Voraussetzungen

* Ein Apache Webserver, idealerweise mit einem File-Layout wie bei [Anleitung 1 (Kompilieren eines Apache Servers)](https://www.netnea.com/cms/apache_tutorial_1_apache_compilieren/)
* Verständnis der minimalen Konfiguration in [Anleitung 2 (Apache minimal konfigurieren)](https://www.netnea.com/cms/apache_tutorial_2_apache_minimal_konfigurieren/)
* Ein Apache Webserver mit SSL-/TLS-Unterstützung wie in [Anleitung 4 (Konfigurieren eines SSL Servers)](https://www.netnea.com/cms/apache-tutorial-4-ssl-server-konfigurieren)
* Ein Apache Webserver mit erweitertem Zugriffslog wie in [Anleitung 5 (Das Zugriffslog Ausbauen und Auswerten)](https://www.netnea.com/cms/apache-tutorial-5-zugriffslog-ausbauen/)
* Ein Apache Webserver mit ModSecurity wie in [Anleitung 6 (ModSecurity einbinden)](https://www.netnea.com/cms/apache-tutorial-6-modsecurity-einbinden/)
* Eine OWASP ModSecurity Core Rules Installation wie in [Anleitung 7 (ModSecurity Core Rules einbinden](https://www.netnea.com/cms/apache-tutorial-7-modsecurity-core-rules-einbinden/)
* Ein Reverse Proxy wie in [Anleitung 9 (Reverse Proxy einrichten)](https://www.netnea.com/cms/apache-tutorial-9-reverse-proxy-einrichten/)

###Schritt 1 : Mit ModSecurity den vollen Verkehr mitschreiben

Wir haben in der Anleitung 6 gesehen, wie wir ModSecurity konfigurieren können, damit es den gesamten Verkehr einer einzigen Client IP Adresse mitschreibt. Je nach Settings der Direktive `SecAuditLogParts` werden aber nicht sämtliche Teile der Anfragen festgehalten. Schauen wir uns die verschiedenen Optionen dieser Direktive an: Die Audit-Engine von ModSecurity bezeichnet verschiedene Teile des Audit-Logs mit verschiedenen Buchstabenkürzeln. Sie lauten wie folgt:

* Teil A: Der Startteil eines einzelnen Eintrages / Requests (zwingend)
* Teil B: Die HTTP Request Header
* Teil C: Der HTTP Request Body (inklusive rohe Dateien bei einem File Upload; nur wenn der Body-Zugriff mittels `SecRequestBodyAccess` gesetzt wurde)
* Teil E: Der HTTP Response Body (nur wenn der Body-Zugriff mittels `SecResponseBodyAccess` aktiviert wurde)
* Teil F: Die HTTP Response Header (Ohne die beiden Date- und Server-Header, die von Apache selbst kurz vor dem Verlassen des Servers gesetzt werden)
* Teil H: Weitere Informationen von ModSecurity zur Zusatzinfos zum Request, wie die hier repetierten Einträge des Apache Error-Logs, die ergriffene `Action`, Timinig-Informationen etc. Ein Blick lohnt sich.
* Teil I: Der HTTP Request Body in einer platzsparenden Version (hochgeladene Files in nicht ihrer vollen Länge einschliesst, sondern nur einzelne Schlüsselparameter dieser Dateien)
* Teil J: Zusätzliche Informationen über File Uploads
* Teil K: Liste sämtlicher Regeln, die eine positive Antwort lieferten (Die Regeln selbst werden normalisiert; inklusive sämtlicher vererbten Deklarationen)
* Teil Z: Abschluss eines einzelnen Eintrages / Requests (zwingend)

In der Anleitung 6 haben wir die folgende Auswahl für die einzelnen Header getroffen.:

```bash
SecAuditLogParts        ABIJEFHKZ
```

Damit haben wir ein sehr umfassendes Protokoll festgelegt. Das ist in einem Labor-Setup das richtige Vorgehen. In einer produktiven Umgebung macht dies allerdings nur in Ausnahmefällen Sinn. Eine typische Ausprägung dieser Direktive in einer produktiven Umgebung lautet deshalb:

```bash
SecAuditLogParts            "ABFHKZ"
```

Hier werden die Request- und Response-Bodies nicht mehr mitgeschrieben. Das spart sehr viel Speicherplatz, was gerade bei schlecht getunten Systemen wichtig ist. Diejenigen Teile der Bodies, welche einzelne Regeln verletzten, werden im Error-Log und im K-Teil dennoch notiert werden. Das reicht in vielen Fällen. Fallweise möchte man aber dennoch den gesamten Body mitschreiben. In diesen Fällen bietet sich eine `ctl`-Direktive für den Action-Teil der `SecRule` an. Mit `auditLogParts` können mehrere zusätzliche Teile angewählt werden:

```bash
SecRule REMOTE_ADDR  "@streq 127.0.0.1"   "id:10000,phase:1,pass,log,auditlog,msg:'Initializing full traffic log',ctl:auditLogParts=+EIJ"
```

###Schritt 2 : Mit ModSecurity den vollen Verkehr einer einzigen Session schreiben

Der erste Schritt erlaubte die dynamische Veränderung der Audit-Log-Teile für eine bekannte IP-Adresse. Was aber, wenn wir
das Logging dynamisch für ausgewählte Sessions dauerhaft einschalten und wie im obigen Beispiel gezeigt, auf den vollen Request ausdehnen möchten?

Ivan Ristić beschreibt in seinem ModSecurity Handbuch ein Beispiel in dem eine ModSecurity `Collection` herangezogen wird, um eine eigene Session zu erzeugen, welche über einen einzelnen Request hinaus aktiv bleibt. Wir benützen diese Idee als Basis und schreiben ein etwas komplexeres Beispiel:

```bash
SecRule TX:INBOUND_ANOMALY_SCORE  "@ge 5" \
  "phase:5,pass,id:10001,log,msg:'Logging enabled (High incoming anomaly score)', \
  expirevar:ip.logflag=600"

SecRule TX:OUTBOUND_ANOMALY_SCORE "@ge 5" \
  "phase:5,pass,id:10002,log,msg:'Logging enabled (High outgoing anomaly score)', \
  expirevar:ip.logflag=600"

SecRule &IP:LOGFLAG               "@eq 1" \
  "phase:5,pass,id:10003,log,msg:'Logging is enabled. Enforcing rich auditlog.', \
  ctl:auditEngine=On,ctl:auditLogParts=+EIJ"
```

Bei der in den vorangegangenen Anleitungen vorgeschlagenen Integration der Core Rules haben wir bereits
eine persistente `Collection` auf Basis der IP-Adresse des Anfrage-Stellers eröffnet. Diese über einen einzelnen
Request hinaus aufbewahrte `Collection` eignet sich, um zwischen verschiedenen Anfragen Daten festzuhalten.

Wir benützen diese Fähigkeit, um in der Logging-Phase des Requests, seinen `Core Rules Anomaly Score` zu überprüfen.
Liegt der auf 5 oder höher (was einem Alarm der Stufe `critical` entspricht,
setzen wir die Variable `ip.logflag` und geben Ihr mittels `expirevar` eine Lebenszeit von 600 Sekunden.
Dies bedeutet, dass diese Variable in der `IP-Collection` für zehn Minuten vorhanden bleibt und danach von selbst wieder
verschwindet.  In der darauf folgenden Regel wiederholt sich dieser Mechanismus für den `Outgoing Anomaly Score`.

In der dritten Regel sehen wir nach, ob dieses `Logflag` gesetzt ist. Wir haben die wundersame Verwandlung von
Variablennamen je nach Verwendungszweck in `ModSecurity` schon früher gesehen. Hier begegnen wir ihr wieder, indem
`ip.logflag` bei der Verwendung als Variable in einer `SecRule` als `IP:LOGFLAG` geschrieben werden muss. Das
vorangestellte `&`-Zeichen haben wir auch schon früher kennengelernt: Es bezeichnet die Anzahl der Variablen dieses 
Namens (0 oder 1).
Das heisst, wir können damit auf das Vorhandensein von `ip.logflag` prüfen. Ist das Flag gesetzt, also in
den beiden Regeln vorher, oder zu einem früheren Zeitpunkt innerhalb der letzten 10 Minuten, dann wird
die Audit-Engine aktiviert und zusätzlich noch um einige in der Standardkonfiguration nicht immer gesetzt Logteile
erweitert.

Das Erzwingen des Audit-Logs, das wir so noch nicht kennengelernt haben, ist nötig, denn wir wollen nun ja
Anfragen loggen, welche für sich genommen keine Regeln verletzt haben. Das heisst, das Auditlog ist für den
Request noch gar nicht aktiviert. Das holen wir mit dieser Regel nach.

Gemeinsam erlauben uns diese drei Regeln einen auffälligen Client über einen einzelnen verdächtigen Request hinaus genau
zu beobachten und ab dem Einsetzen des Verdachts den gesamten Verkehr dieses Clients im Audit-Log mitzuprotokollieren.

###Schritt 3 : Verkehr des Clients mit dem Server / Reverse Proxy mithören

Der Verkehr zwischen einem Client und dem Reverse Proxy lässt sich mit den oben geschilderten Techniken in aller Regel gut dokumentieren. Dazu kommen die Möglichkeiten auf dem Client den Verkehr zu dokumentieren. Die modernen Browser bringen dazu verschiedene Möglichkeiten und sie scheinen mir alle adäquat zu sein. Allerdings kommt es in der Praxis vor, dass Komplikationen das Mitschreiben des Verkehrs erschweren oder verunmöglichen. Sei es, dass ein Fat Client ausserhalb eines Browsers verwendet wird, der Client lediglich auf einem mobilen Gerät zum Einsatz kommt, ein zwischengeschalteter Proxy den Verkehr in die eine oder andere Richtung verändert, dass der Verkehr nach dem Verlassen von ModSecurity durch ein weiteres Modul nochmals verändert wird oder aber dass ModSecurity gar keinen Zugriff auf den Verkehr erhält. Letzteres ist ein einzelnen Fällen tatsächlich ein Problem, da ein Apache Modul die weitere Verarbeitung eines Requests abbrechen und damit den Zugriff durch ModSecurity unterdrücken kann.

In diesen Fällen ist es eine Möglichkeit, einen eigenen Proxy dazwischenzuschalten, um den Traffic mitzuschreiben. Es stehen verschiedene Hilfsmittel zur Verfügung. Namentlich `mitmproxy` scheint sehr interessante Features zu besitzen und ich setze es erfolgreich ein. Da die Weiterentwicklung dieser Software aber noch sehr dynamisch ist, gestaltet sich die Installation der aktuellen Version als recht anspruchsvoll, weshalb ich hier nicht näher darauf eingehe. Wir wählen eine etwas rohere Methode.

Es kann also vorkommen, dass die Einträge im Audit-Log nicht demjenigen entspricht, was tatsächlich auf dem Client ankam, oder nicht mehr dem entspricht, was der Client ursprünglich geschickt hatte. In diesen Fällen ist es wünschenswert, punktuell den tatsächlichen Traffic mitzuschreiben und die verschlüsselten Daten zu dechiffrieren. Diesem Ansinnen steht allerdings die starke Verschlüsselung gegenüber, welche wir in der vierten Anleitung konfiguriert haben, um sie abhörsicher zu machen. Die von uns favorisierten Ciphers setzen hiezu auf sogenannte `Forward Secrecy`. Das bedeutet, dass ein Mithörer so ausgeschaltet wird, dass selbst der Besitz des Chiffrierschlüssels ein Mithören nicht mehr erlaubt. Das heisst zwischen dem Client und dem Server ist jedes Mitschreiben des Verkehrs ausgeschlossen. Es sei denn wir postieren einen Prozess dazwischen, welcher die Verbindung terminiert und dem Client ein eigenes Zertifikat vorlegt.

In allen anderen Fällen, in denen wir eine Entschlüsselung erzwingen wollen, aber den Client nicht umkonfigurieren können, müssen wir eine andere, schwächere Verschlüsselsungsart einsetzen, die `Forward Secrecy` nicht beherrscht. Dazu eignet sich etwa der `AES256-SHA` Cipher, den wir auf dem Client als einzigen Cipher definieren und uns damit mit dem Server verbinden. Wenn wir den Cipher clientseitig nicht setzen können, dann müssen wir die Verschlüsselung für den kompletten Server schwächen. Es liegt auf der Hand, dass dies nicht erwünscht ist, und höchstens punktuell Sinn macht. Sei es dass wir den Client auf ein separates System binden oder die Umkonfiguration zeitlich beschränken.

Versuchsweise liess sich Apache mittels der konditionalen `<if>`-Direktive auch so konfigurieren, dass er einem einzelnen Client einen anderen Cipher präsentiert. Allerdings gelingt dies nur via ein `SSL-Renegotiate`. Dies bedeutet, dass ein SSL Handshake mit `Forward Secrecy` durchgeführt wurde, aber dieser danach mit einem schwächeren Cipher wiederholt wurde. Diese Technik vermochten in meinen Tests die gängigen Entschlüsselungshilfsmittel `wireshark` und `ssldump` wiederum nicht zu verarbeiten. Das heisst, für den Moment bleibt nur, den Server auf eine schwächere Verschlüsselung umzustellen. Im Hinblick auf die Sicherheit rate ich dringend dazu, zunächst alle anderen Mittel auszuschöpfen bevor auf diese Variante zurückgegriffen wird.

In der vierten Anleitung haben wir den lokalen Labor-Service mit dem lokal vorhandenen `Snake-Oil`-Schlüssel betrieben. Dieses Zertifikat ziehen wir auch jetzt wieder heran und instruieren den Server, den dechiffrierbaren `AES256-SHA` Cipher zu verwenden:

```bash
    ...


        SSLCertificateKeyFile   /etc/ssl/private/ssl-cert-snakeoil.key
        SSLCertificateFile      /etc/ssl/certs/ssl-cert-snakeoil.pem

        SSLProtocol             All -SSLv2 -SSLv3
    	SSLCipherSuite          'AES256-SHA'
        SSLHonorCipherOrder     On

    ...

```

###Schritt 4 : Verschlüsselten Verkehr des Clients mit dem Server / Reverse Proxy mitschreiben


Mit den obenstehenden Erklärungen haben wir die Grundlagen geschaffen, um den Verkehr mitzuschreiben und dann zu dechiffrieren. Wir machen das in zwei Schritten, also zunächst das Protokollieren des Verkehrs und dann die Entschlüsselung des Protokolls. Das Mitschreiben nennt man auch `ein PCAP ziehen`. Das heisst, wir stellen ein `PCAP`-File, also ein Netwerkverkehrsprotokoll im `PCAP`-Format. `PCAP` steht dabei für `Packet Capture`. Wir benützen dazu entweder das verbreitete Hilfsmittel `tcpdump` oder `tshark` aus der `Wireshark`-Suite. Es ist aber auch möglich, gleich in der grafischen `Wireshark`-Oberfläche zu arbeiten.

```bash
$> sudo tcpdump -i lo -w /tmp/localhost-port443.pcap -s0 port 443
tcpdump: listening on lo, link-type EN10MB (Ethernet), capture size 65535 bytes
...
```

Alternativ:

```bash
$> sudo tshark -i lo -w /tmp/localhost-port443.pcap -s0 port 443
tshark: Lua: Error during loading:
 [string "/usr/share/wireshark/init.lua"]:46: dofile has been disabled due to running Wireshark as superuser. See http://wiki.wireshark.org/CaptureSetup/CapturePrivileges for help in running Wireshark as an unprivileged user.
Running as user "root" and group "root". This could be dangerous.
Capturing on 'Loopback'
...
```

Die beiden Befehle, die ein identisches Protokoll erzeugen, werden hier instruiert, um auf dem lokalen `lo`-Interface und Port 443 zu hören und in die Datei `localhost-port443.pcap` zu schreiben. Wichtig ist die Option `-s0`. Es handelt sich um die sogenannte `Snaplength` oder `Capture Size`. Dies bezeichnet wieviele Daten aus einem IP-Paket genau mitgeschrieben werden soll. In unserem Fall wollen wir auf jeden Fall das komplette Paket. Die entsprechende Instruktion geschieht über den Wert 0, der automatisch alles meint. 

Mit diesen Befehlen ist das Protokoll gestartet und wir können nun den Verkehr in einem zweiten Fenster auslösen. Probieren wir es einfach mal mit `curl`:

```bash
$> curl -v --ciphers AES256-SHA -k https://127.0.0.1:443/index.html
* Hostname was NOT found in DNS cache
*   Trying 127.0.0.1...
* Connected to 127.0.0.1 (127.0.0.1) port 443 (#0)
* successfully set certificate verify locations:
*   CAfile: none
  CApath: /etc/ssl/certs
* SSLv3, TLS handshake, Client hello (1):
* SSLv3, TLS handshake, Server hello (2):
* SSLv3, TLS handshake, CERT (11):
* SSLv3, TLS handshake, Server finished (14):
* SSLv3, TLS handshake, Client key exchange (16):
* SSLv3, TLS change cipher, Client hello (1):
* SSLv3, TLS handshake, Finished (20):
* SSLv3, TLS change cipher, Client hello (1):
* SSLv3, TLS handshake, Finished (20):
* SSL connection using AES256-SHA
...

```

Kam die gewünschte Antwort vom Server zurück, so können wir im `Sniffing`-Fenster das Protokoll mit `STRG-c` respektive `CTRL-c` abbrechen:


```bash
$> sudo tcpdump -i lo -w /tmp/localhost-port443.pcap -s0 port 443
tcpdump: listening on lo, link-type EN10MB (Ethernet), capture size 65535 bytes
^C15 packets captured
30 packets received by filter
0 packets dropped by kernel
```

###Schritt 5 : Verkehr entschlüsseln

Versuchen wir also das `PCAP`-File zu entschlüsseln. Wir verwenden dazu wieder `tshark` aus der `Wireshark`-Suite. Das `GUI` funktioniert natürlich ebenso, ist aber weniger komfortabel. Wichtig ist es nun, dem Tool den Schlüssel, den wir auf dem Server verwendet haben, mitzuübergeben.

```bash
$> sudo tshark -r /tmp/localhost-port443.pcap -o "ssl.desegment_ssl_records: TRUE" -o "ssl.desegment_ssl_application_data: TRUE" -o "ssl.keys_list: 127.0.0.1,443,http,/etc/ssl/private/ssl-cert-snakeoil.key" -o "ssl.debug_file: /tmp/ssl-debug.log"
Running as user "root" and group "root". This could be dangerous.
  1   0.000000    127.0.0.1 -> 127.0.0.1    TCP 74 33517 > https [SYN] Seq=0 Win=43690 Len=0 MSS=65495 SACK_PERM=1 TSval=42610003 TSecr=0 WS=128
  2   0.000040    127.0.0.1 -> 127.0.0.1    TCP 74 https > 33517 [SYN, ACK] Seq=0 Ack=1 Win=43690 Len=0 MSS=65495 SACK_PERM=1 TSval=42610003 TSecr=42610003 WS=128
  3   0.000088    127.0.0.1 -> 127.0.0.1    TCP 66 33517 > https [ACK] Seq=1 Ack=1 Win=43776 Len=0 TSval=42610003 TSecr=42610003
  4   0.001381    127.0.0.1 -> 127.0.0.1    SSL 161 Client Hello
  5   0.001470    127.0.0.1 -> 127.0.0.1    TCP 66 https > 33517 [ACK] Seq=1 Ack=96 Win=43776 Len=0 TSval=42610004 TSecr=42610004
  6   0.002338    127.0.0.1 -> 127.0.0.1    TLSv1.2 865 Server Hello, Certificate, Server Hello Done
  7   0.002417    127.0.0.1 -> 127.0.0.1    TCP 66 33517 > https [ACK] Seq=96 Ack=800 Win=45312 Len=0 TSval=42610004 TSecr=42610004
  8   0.004330    127.0.0.1 -> 127.0.0.1    TLSv1.2 408 Client Key Exchange, Change Cipher Spec, Finished
  9   0.018200    127.0.0.1 -> 127.0.0.1    TLSv1.2 141 Change Cipher Spec, Finished
 10   0.019624    127.0.0.1 -> 127.0.0.1    TLSv1.2 199 Application Data
 11   0.028515    127.0.0.1 -> 127.0.0.1    TLSv1.2 428 Application Data, Application Data
 12   0.029827    127.0.0.1 -> 127.0.0.1    TLSv1.2 119 Alert (Level: Warning, Description: Close Notify)
 13   0.030056    127.0.0.1 -> 127.0.0.1    TCP 66 33517 > https [FIN, ACK] Seq=624 Ack=1237 Win=46976 Len=0 TSval=42610011 TSecr=42610010
 14   0.037327    127.0.0.1 -> 127.0.0.1    TLSv1.2 119 Alert (Level: Warning, Description: Close Notify)
 15   0.037417    127.0.0.1 -> 127.0.0.1    TCP 54 33517 > https [RST] Seq=625 Win=0 Len=0
```

Hier ist noch nicht viel lesbar. Wenn wir uns aber dem `Debug-File` zuwenden, dann sehen wir dort drinnen den Verkehr.

```bash
$> cat /tmp/ssl-debug.log

Wireshark SSL debug log 

Private key imported: KeyID bb:70:71:21:26:c6:6f:79:82:93:1a:08:ab:f9:db:1f:...
ssl_load_key: swapping p and q parameters and recomputing u
ssl_init IPv4 addr '127.0.0.1' (127.0.0.1) port '443' filename '/etc/ssl/private/ssl-cert-snakeoil.key' password(only for p12 file) ''
ssl_init private key file /etc/ssl/private/ssl-cert-snakeoil.key successfully loaded.
association_add TCP port 443 protocol http handle 0x1af0f10

dissect_ssl enter frame #4 (first time)
ssl_session_init: initializing ptr 0x7f0044d42438 size 688
  conversation = 0x7f0044d41e98, ssl_session = 0x7f0044d42438
  record: offset = 0, reported_length_remaining = 95
dissect_ssl3_record: content_type 22 Handshake
decrypt_ssl3_record: app_data len 90, ssl state 0x00
association_find: TCP port 33517 found (nil)
packet_from_server: is from server - FALSE
decrypt_ssl3_record: using client decoder
decrypt_ssl3_record: no decoder available

...



ssl_generate_keyring_material ssl_create_decoder(client)
ssl_create_decoder CIPHER: AES256
decoder initialized (digest len 20)
ssl_generate_keyring_material ssl_create_decoder(server)
ssl_create_decoder CIPHER: AES256
decoder initialized (digest len 20)
ssl_generate_keyring_material: client seq 0, server seq 0
ssl_save_session stored session id[0]:
ssl_save_session stored master secret[48]:

...

ssl_decrypt_record: allocating 160 bytes for decrypt data (old len 96)
Plaintext[128]:
| db 2f 9e 70 d4 79 7e 51 18 a7 6e 32 1f 95 8f b6 |./.p.y~Q..n2....|
| 47 45 54 20 2f 69 6e 64 65 78 2e 68 74 6d 6c 20 |GET /index.html |
| 48 54 54 50 2f 31 2e 31 0d 0a 55 73 65 72 2d 41 |HTTP/1.1..User-A|
| 67 65 6e 74 3a 20 63 75 72 6c 2f 37 2e 33 35 2e |gent: curl/7.35.|
| 30 0d 0a 48 6f 73 74 3a 20 31 32 37 2e 30 2e 30 |0..Host: 127.0.0|
| 2e 31 0d 0a 41 63 63 65 70 74 3a 20 2a 2f 2a 0d |.1..Accept: */*.|
| 0a 0d 0a 96 42 bc 7a 70 a9 e1 8c b7 38 00 cc ca |....B.zp....8...|
| 6a 90 e9 08 9c d5 b9 08 08 08 08 08 08 08 08 08 |j...............|
ssl_decrypt_record found padding 8 final len 119
checking mac (len 83, version 303, ct 23 seq 1)
tls_check_mac mac type:SHA1 md 2

...

Plaintext[256]:
| f1 0b 2a 1a bc 28 29 32 cf 40 98 6b 65 7f f0 a4 |..*..()2.@.ke...|
| 48 54 54 50 2f 31 2e 31 20 32 30 30 20 4f 4b 0d |HTTP/1.1 200 OK.|
| 0a 44 61 74 65 3a 20 57 65 64 2c 20 30 32 20 4d |.Date: Wed, 02 M|
| 61 72 20 32 30 31 36 20 31 31 3a 31 35 3a 30 34 |ar 2016 11:15:04|
| 20 47 4d 54 0d 0a 53 65 72 76 65 72 3a 20 41 70 | GMT..Server: Ap|
| 61 63 68 65 0d 0a 4c 61 73 74 2d 4d 6f 64 69 66 |ache..Last-Modif|
| 69 65 64 3a 20 4d 6f 6e 2c 20 31 31 20 4a 75 6e |ied: Mon, 11 Jun|
| 20 32 30 30 37 20 31 38 3a 35 33 3a 31 34 20 47 | 2007 18:53:14 G|
| 4d 54 0d 0a 45 54 61 67 3a 20 22 32 64 2d 34 33 |MT..ETag: "2d-43|
| 32 61 35 65 34 61 37 33 61 38 30 22 0d 0a 41 63 |2a5e4a73a80"..Ac|
| 63 65 70 74 2d 52 61 6e 67 65 73 3a 20 62 79 74 |cept-Ranges: byt|
| 65 73 0d 0a 43 6f 6e 74 65 6e 74 2d 4c 65 6e 67 |es..Content-Leng|
| 74 68 3a 20 34 35 0d 0a 43 6f 6e 74 65 6e 74 2d |th: 45..Content-|
| 54 79 70 65 3a 20 74 65 78 74 2f 68 74 6d 6c 0d |Type: text/html.|
| 0a 0d 0a 48 d5 2d 0c 88 7a b8 8c 31 8a d1 97 cc |...H.-..z..1....|
| c9 5d cd a4 6b 88 e3 08 08 08 08 08 08 08 08 08 |.]..k...........|
ssl_decrypt_record found padding 8 final len 247
```

Damit ist der HTTP Verkehr lesbar, wenn auch in einem etwas schwierigen Format.


###Schritt 6 : Verkehr des Reverse Proxies mit dem Applikationsserver mithören

Das Audit-Log von ModSecurity wird nach dem Versand der Antwort eines Requests geschrieben. Das macht bereits deutlich, dass das Audit-Log sich vor allem für die möglichst finale Version der Antwort interessiert. Auf einem Reverse Proxy wird diese Version der Anfrage und vor allem der Antwort nicht zwingend dem entsprechen, was auch wirklich vom Backend-System geschickt wurde, denn die verschiedenen Apache-Module haben je nachdem bereits in den Verkehr eingegriffen. Um diesen Verkehr mitschreiben zu können, benötigen wir andere Mittel. In der Entwicklungsschiene des Apache Webservers liegt das Modul `mod_firehose` vor. Damit lässt sich an beinahe beliebigem Ort im Verkehr ein Protokoll mitschreiben. Allerdings wurde von der Entwickler-Gemeinschaft entschieden, das Modul für Apache 2.4 nicht zur Verfügung zu stellen, sondern einer späteren Version vorzubehalten.

Das bedeutet, dass wir erneut mit dem Problem konfrontiert sind, den Netzwerk-Verkehr dechiffrieren zu müssen. Wir können dabei auf Seite des Reverse Proxies den zu verwendenden `Cipher` definieren. Dies geschieht über die Direktive `SSLProxyCipherSuite`. Dies wird aber nur funktionieren, wenn wir das Schlüsselmaterial des Applikationsservers und Diskussionspartners erhalten, um die Verschlüsselung in Klartext zurückzuverwandeln. Ist das gegeben, gestaltet sich der Vorgang wie oben beschrieben.

Der Schlüssel des Applikationsservers ist aber normalerweise nicht greifbar, so dass wir auf eine Alternative setzen müssen. Wir schalten einen kleines Tool `stunnel` zwischen Reverse Proxy und Backend. `Stunnel` übernimmt dabei die Verschlüsselung zum Backend für uns. Dies erlaubt es dem Reverse Proxy, `stunnel` im Klartext anzusprechen und uns gibt das die Möglichkeit, diese Verbindung 1:1 mitzuschreiben. Um alle anderen Mitleser auszuschalten betreiben wir `stunnel` auf dem Reverse Proxy selbst auf einer lokalen IP Adresse und einem separaten Port. Die Verschlüsselung findet danach zwischen `stunnel` und dem Backend statt. Hier zu Testzwecken auch auf dem Localhost Netzwerk-Interface. In der Praxis aber freilich auf einem entfernten Server.

Zur Illustration eine einfache Skizze des Setups:

```bash
                      ____ 
                     |    |
                     |____|
                     /::::/
                       |
                       |
                       v
    .---------------------------------------.
    |                                       |
    |     Reverse Proxy: localhost: 443     |
    |                                       |
    '---------------------------------------'
                       |            .-----------------------------------.
                       | <----------| $> tcpdump -i lo -A -s0 port 8000 |
                       v            '-----------------------------------'
    .---------------------------------------.
    |                                       |
    |        stunnel: localhost: 8000       |
    |                                       |
    '---------------------------------------'
                       |
                       |
                       |
                       |
                       |
                       v
    .---------------------------------------.
    |                                       |
    |       Backend: localhost: 8443        |
    |                                       |
    '---------------------------------------'

```


Zunächst die Konfiguration des Reverse Proxies:

```bash

	...

        RewriteRule             /proxy/(.*)     http://localhost:8000/$1 [proxy,last]
        ProxyPassReverse        /               http://localhost:8000/


        <Proxy http://localhost:8000/>

        </Proxy>

	...

```

Und hier die Konfiguration des `stunnel daemons`:

```bash
$> cat /tmp/stunnel.conf

foreground = yes
pid = /tmp/stunnel.pid

debug = 5
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[https]
client = yes
accept  = 8000
connect = localhost:8443
TIMEOUTclose = 0
```

Das File erklärt sich recht gut selbst, Wichtig ist die `client`-Option. Sie instruiert `stunnel` Klartext-Verbindungen zu akzeptieren und sie gegenüber dem Backend zu verschlüsseln. Der Default-Wert ist hier `no`, was genau das gegenteilige Verhalten mit sich bringt. Die Option `TIMEOUTclose` ist ein Erfahrungswert, der sich verschiedentlich in `stunnel` Anleitungen findet. Bleibt noch die Konfiguration des Backend Servers. Da wir ein Backend mit SSL-/TLS-Unterstützung benötigen, können wir uns nicht mehr mit einem `socat`-Backend wie in der Anleitung Nummer 9 behelfen:

```bash

PidFile logs/httpd-backend.pid

Listen	127.0.0.1:8443

...

<VirtualHost *:8443>
        ServerName localhost
        ServerAlias ubuntu

        SSLEngine               On
        RewriteEngine           On


        SSLCertificateKeyFile   /etc/ssl/private/ssl-cert-snakeoil.key
        SSLCertificateFile      /etc/ssl/certs/ssl-cert-snakeoil.pem
        SSLProtocol             All -SSLv2 -SSLv3
        SSLHonorCipherOrder     On
        SSLCipherSuite          "AES256-SHA"

        <Directory /apache/htdocs>

        </Directory>

</VirtualHost>

```

Da es sich um den zweiten parallel zu startenden Apache Server handelt, ist es wichtig, dass er sich nicht mit dem Reverse Proxy in die Haare gerät. Die Ports haben wir bereits unterschieden. Wichtig ist es, zusätzlich auch die `PidFile`-Datei zu separieren. Normalerweise setzen wir das nicht explizit und sind mit dem Default-Wert zufrieden. In unserem Fall müssen wir sie aber von Hand setzen. Das ist in obenstehender Konfiguration geschehen.

Nun starten wir die drei verschiedenen Server nacheinander. Wenn wir die Apaches mit dem Tool `apachex` steuern, dann leiden wir etwas darunter, dass `apachex` jeweils das jüngste Konfigurationsfile zu starten versucht. Ein kurzer `touch`-Befehl auf das jeweilig gewünschte Konfigurationsfile löst dieses Problem. Bei `stunnel` ist es wichtig, die jüngere Version `stunnel4` zu verwenden. Sie ist in `Debian/Ubuntu` in einem Paket gleichen Namens vorhanden. Der Start geht dann sehr leicht:

```bash
$> sudo stunnel4 /tmp/stunnel.conf
stunnel4 /tmp/stunnel.conf
2016.03.02 16:28:08 LOG5[8254:140331683964736]: stunnel 4.53 on x86_64-pc-linux-gnu platform
2016.03.02 16:28:08 LOG5[8254:140331683964736]: Compiled with OpenSSL 1.0.1e 11 Feb 2013
2016.03.02 16:28:08 LOG5[8254:140331683964736]: Running  with OpenSSL 1.0.1f 6 Jan 2014
2016.03.02 16:28:08 LOG5[8254:140331683964736]: Update OpenSSL shared libraries or rebuild stunnel
2016.03.02 16:28:08 LOG5[8254:140331683964736]: Threading:PTHREAD SSL:+ENGINE+OCSP Auth:LIBWRAP Sockets:POLL+IPv6
2016.03.02 16:28:08 LOG5[8254:140331683964736]: Reading configuration from file /tmp/stunnel.conf
2016.03.02 16:28:08 LOG5[8254:140331683964736]: Configuration successful
```

Damit ist der komplette Setup bereit für unseren Curl-Aufruf. Testen wir das nacheinander. Zuerst direkt das Backend, dann via den Stunnel und schliesslich via den Reverse Proxy:

```bash
$> curl -v -k https://localhost:8443/index.html
* Hostname was NOT found in DNS cache
*   Trying 127.0.0.1...
* Connected to localhost (127.0.0.1) port 8443 (#0)
...
> GET /index.html HTTP/1.1
> User-Agent: curl/7.35.0
> Host: localhost:8443
> Accept: */*
> 
< HTTP/1.1 200 OK
< Date: Thu, 03 Mar 2016 10:00:04 GMT
* Server Apache is not blacklisted
< Server: Apache
< Last-Modified: Mon, 11 Jun 2007 18:53:14 GMT
< ETag: "2d-432a5e4a73a80"
< Accept-Ranges: bytes
< Content-Length: 45
< Content-Type: text/html
< 
<html><body><h1>It works!</h1></body></html>
* Connection #0 to host localhost left intact
$> curl -v -k http://localhost:8000/index.html
* Hostname was NOT found in DNS cache
*   Trying 127.0.0.1...
* Connected to localhost (127.0.0.1) port 8000 (#0)
> GET /index.html HTTP/1.1
> User-Agent: curl/7.35.0
> Host: localhost:8000
> Accept: */*
> 
< HTTP/1.1 200 OK
< Date: Thu, 03 Mar 2016 10:01:04 GMT
* Server Apache is not blacklisted
< Server: Apache
< Last-Modified: Mon, 11 Jun 2007 18:53:14 GMT
< ETag: "2d-432a5e4a73a80"
< Accept-Ranges: bytes
< Content-Length: 45
< Content-Type: text/html
< 
<html><body><h1>It works!</h1></body></html>
* Connection #0 to host localhost left intact
$> curl -v -k https://localhost:443/proxy/index.html
* Hostname was NOT found in DNS cache
*   Trying 127.0.0.1...
* Connected to localhost (127.0.0.1) port 443 (#0)
...
> GET /proxy/index.html HTTP/1.1
> User-Agent: curl/7.35.0
> Host: localhost
> Accept: */*
> 
< HTTP/1.1 200 OK
< Date: Thu, 03 Mar 2016 10:01:29 GMT
* Server Apache is not blacklisted
< Server: Apache
< Last-Modified: Mon, 11 Jun 2007 18:53:14 GMT
< ETag: "2d-432a5e4a73a80"
< Accept-Ranges: bytes
< Content-Length: 45
< Content-Type: text/html
< 
<html><body><h1>It works!</h1></body></html>
* Connection #0 to host localhost left intact
```

Das hat also ganz gut funktioniert. Im `stunnel`-Fenster sehen wir dabei folgenden Output:

```bash
2016.03.03 11:03:49 LOG5[5667:140363675346688]: Service [https] accepted connection from 127.0.0.1:47818
2016.03.03 11:03:49 LOG5[5667:140363675346688]: connect_blocking: connected 127.0.0.1:8443
2016.03.03 11:03:49 LOG5[5667:140363675346688]: Service [https] connected remote server from 127.0.0.1:54593
2016.03.03 11:03:49 LOG3[5667:140363675346688]: transfer: s_poll_wait: TIMEOUTclose exceeded: closing
2016.03.03 11:03:49 LOG5[5667:140363675346688]: Connection closed: 190 byte(s) sent to SSL, 275 byte(s) sent to socket
```

`Stunnel` rapport hier also die einkommende Verbindung auf dem `Source-Port` 47818 und dass es selbst eine Verbindung zum 
Backend Host auf Port 8443 mit dem `Source-Port` 54593 aufgebaut hat; schliesslich noch zwei Zahlen zum Durchsatz.
Insgesamt können wir damit also schliessen, dass der Setup funktioniert und wir bereit sind für das Sniffen der Verbindung.
Aktivieren wir `tcpdump` oder `tshark`. Eine Entschlüsselung ist nun nicht mehr nötig, denn die von uns abzuhörende Verbindung 
zwischen den beiden Localhost `Sockets` ist nun im Klartext mitlesbar. Deshalb ist es beim Aufruf wichtig, dass wir neben 
der `Snaplength` auch den ASCII-Modus mittels `-A` aktivieren.

```bash
$> sudo tcpdump -i lo -A -s0 port 8000
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on lo, link-type EN10MB (Ethernet), capture size 65535 bytes
11:07:40.016067 IP localhost.47884 > localhost.8000: Flags [S], seq 2684270112, win 43690, options [mss 65495,sackOK,TS val 63198772 ecr 0,nop,wscale 7], length 0
E..<..@.@.\............@... .........0.........
..V4........
11:07:40.016103 IP localhost.8000 > localhost.47884: Flags [S.], seq 3592202505, ack 2684270113, win 43690, options [mss 65495,sackOK,TS val 63198772 ecr 63198772,nop,wscale 7], length 0
E..<..@.@.<..........@.....     ...!.....0.........
..V4..V4....
11:07:40.016154 IP localhost.47884 > localhost.8000: Flags [.], ack 1, win 342, options [nop,nop,TS val 63198772 ecr 63198772], length 0
E..4..@.@.\............@...!...
...V.(.....
..V4..V4
11:07:40.016647 IP localhost.47884 > localhost.8000: Flags [P.], seq 1:191, ack 1, win 342, options [nop,nop,TS val 63198772 ecr 63198772], length 190
E.....@.@.[............@...!...
...V.......
..V4..V4GET /index.html HTTP/1.1
Host: localhost
User-Agent: curl/7.35.0
Accept: */*
X-Forwarded-For: 127.0.0.1
X-Forwarded-Host: localhost
X-Forwarded-Server: localhost
Connection: close


11:07:40.016738 IP localhost.8000 > localhost.47884: Flags [.], ack 191, win 350, options [nop,nop,TS val 63198772 ecr 63198772], length 0
E..4.>@.@.=..........@.....
.......^.(.....
..V4..V4
11:07:40.041573 IP localhost.8000 > localhost.47884: Flags [P.], seq 1:231, ack 191, win 350, options [nop,nop,TS val 63198778 ecr 63198772], length 230
E....?@.@.<..........@.....
.......^.......
..V:..V4HTTP/1.1 200 OK
Date: Thu, 03 Mar 2016 10:07:40 GMT
Server: Apache
Last-Modified: Mon, 11 Jun 2007 18:53:14 GMT
ETag: "2d-432a5e4a73a80"
Accept-Ranges: bytes
Content-Length: 45
Connection: close
Content-Type: text/html


11:07:40.041627 IP localhost.47884 > localhost.8000: Flags [.], ack 231, win 350, options [nop,nop,TS val 63198778 ecr 63198778], length 0
E..4..@.@.\............@...........^.(.....
..V:..V:
11:07:40.041711 IP localhost.8000 > localhost.47884: Flags [P.], seq 231:276, ack 191, win 350, options [nop,nop,TS val 63198778 ecr 63198778], length 45
E..a.@@.@.=T.........@.............^.U.....
..V:..V:<html><body><h1>It works!</h1></body></html>

11:07:40.041745 IP localhost.47884 > localhost.8000: Flags [.], ack 276, win 350, options [nop,nop,TS val 63198778 ecr 63198778], length 0
E..4..@.@.\............@...........^.(.....
..V:..V:
11:07:40.042044 IP localhost.47884 > localhost.8000: Flags [F.], seq 191, ack 276, win 350, options [nop,nop,TS val 63198778 ecr 63198778], length 0
E..4..@.@.\............@...........^.(.....
..V:..V:
11:07:40.047226 IP localhost.8000 > localhost.47884: Flags [F.], seq 276, ack 192, win 350, options [nop,nop,TS val 63198779 ecr 63198778], length 0
E..4.A@.@.=..........@.............^.(.....
..V;..V:
11:07:40.047296 IP localhost.47884 > localhost.8000: Flags [.], ack 277, win 350, options [nop,nop,TS val 63198779 ecr 63198779], length 0
E..4..@.@.\............@...........^.(.....
..V;..V;

```

Geschafft! Wir lesen die Verbindungen zum Backend mit und sind nun sicher, was die beiden Server an Verkehr austauschen. In der Praxis, ist es oft unklar, ob ein Fehler wirklich auf dem Applikationsserver oder vielleicht eben doch auf dem Reverse Proxy verursacht wird. Mit diesem Konstrukt, das die SSL-Konfiguration des Backend Servers nicht berührt, haben wir ein Hilfsmittel, um in diesen relativ häufigen Fällen die endgültige Antwort zu geben.

###Verweise

* [Ivan Ristić: ModSecurity Handbook](https://www.feistyduck.com/books/modsecurity-handbook/)
* [Mod_firehose](http://httpd.apache.org/docs/trunk/de/mod/mod_firehose.html)
* [mitmproxy](https://mitmproxy.org/)
* [Wireshark SSL Howto including a Step by Step guide](https://wiki.wireshark.org/SSL)
* [Stunnel Howto](https://www.stunnel.org/howto.html)

### Lizenz / Kopieren / Weiterverwenden

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png" /></a><br />Diese Arbeit ist wie folgt lizenziert / This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.

