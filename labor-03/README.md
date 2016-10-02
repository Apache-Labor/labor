##Konfigurieren eines SSL Servers

###Was machen wir?
Wir setzen einen mit Serverzertifikat gesicherten Apache Webserver auf.

###Warum tun wir das?

Das HTTP Protokoll ist ein Klartext-Protokoll, das sich sehr gut abhören lässt. Die Erweiterung HTTPS umgibt den HTTP-Verkehr mit einer SSL-/TLS-Schutzschicht, welche das Abhören verhindert und sicherstellt, dass wir wirklich mit demjenigen Server sprechen, den wir angesprochen haben. Die Übertragung der Daten geschieht dann nur noch verschlüsselt. Das bedeutet noch keinen sicheren Webserver, aber es ist die Basis für einen gesicherten HTTP-Verkehr.

###Voraussetzungen

* Ein Apache Webserver, idealerweise mit einem File-Layout wie bei [Anleitung 1 (Kompilieren eines Apache Servers)](http://www.netnea.com/cms/apache_tutorial_1_apache_compilieren/) erstellt.
* Verständnis der minimalen Konfiguration in [Anleitung 2 (Apache minimal konfigurieren)](http://www.netnea.com/cms/apache_tutorial_2_apache_minimal_konfigurieren/).

###Schritt 1: Server mit SSL/TLS, aber ohne offiziell signiertes Zertifikat konfigurieren

Ein SSL Server muss sich beim Kontakt mit dem Client durch ein signiertes Zertifikat ausweisen. Für eine erfolgreiche Verbindung muss die Signierstelle dem Client bekannt sein, was er durch eine Überprüfung der Zertifikatskette vom Server- bis zum Root-Zertifikat der Signierstelle, der Certificate Authority, überprüft. Offiziell signierte Zertifikate bezieht man deshalb von einem öffentlichen (oder privaten) Anbieter, dessen Root-Zertifikat dem Browser bekannt ist. 

Die Konfiguration eines SSL-Servers umfasst also zwei Schritte: Den Bezug eines offiziell signierten Zertifikats und die Konfiguration des Servers. Die Konfiguration des Servers ist der interessantere und einfachere Teil, weshalb wir ihn vorziehen. Dazu bedienen wir uns eines inoffiziellen Behelfzertifikats, das auf unserem System bereits vorhanden ist (zumindest wenn es aus der Debian-Familie stammt und das Paket _ssl-cert_ installiert ist).

Das Zertifikat und der zugehörige Schlüssel befinden sich unter:

```bash
/etc/ssl/certs/ssl-cert-snakeoil.pem
/etc/ssl/private/ssl-cert-snakeoil.key
```

Die Namen der Dateien deuten bereits darauf hin, dass es sich hier um ein wenig vertrauenerweckendes Paar handelt. Der Browser wird denn auch eine Zertifikatswarnung abgeben, wenn man sie für einen Server einsetzt.

Für einen ersten Konfigurationsversuch taugen sie aber durchaus:

```bash

ServerName              localhost
ServerAdmin             root@localhost
ServerRoot              /apache
User                    www-data
Group                   www-data

ServerTokens            Prod
UseCanonicalName        On
TraceEnable             Off

Timeout                 5
MaxRequestWorkers       250

Listen                  127.0.0.1:80
Listen                  127.0.0.1:443

LoadModule              mpm_event_module        modules/mod_mpm_event.so
LoadModule              unixd_module            modules/mod_unixd.so

LoadModule              log_config_module       modules/mod_log_config.so

LoadModule              authn_core_module       modules/mod_authn_core.so
LoadModule              authz_core_module       modules/mod_authz_core.so

LoadModule              ssl_module              modules/mod_ssl.so
LoadModule              headers_module         	modules/mod_headers.so

ErrorLogFormat          "[%{cu}t] [%-m:%-l] %-a %-L %M"
LogFormat               "%h %l %u [%{%Y-%m-%d %H:%M:%S}t.%{usec_frac}t] \"%r\" %>s %b \
\"%{Referer}i\" \"%{User-Agent}i\"" combined

LogLevel                debug
ErrorLog                logs/error.log
CustomLog               logs/access.log combined

SSLCertificateKeyFile   /etc/ssl/private/ssl-cert-snakeoil.key
SSLCertificateFile      /etc/ssl/certs/ssl-cert-snakeoil.pem

SSLProtocol             All -SSLv2 -SSLv3
SSLCipherSuite          'kEECDH+ECDSA kEECDH kEDH HIGH +SHA !aNULL !eNULL !LOW !MEDIUM \
!MD5 !EXP !DSS !PSK !SRP !kECDH !CAMELLIA !RC4'
SSLHonorCipherOrder     On

SSLRandomSeed           startup file:/dev/urandom 2048
SSLRandomSeed           connect builtin

DocumentRoot            /apache/htdocs

<Directory />
      
        Require all denied

        Options SymLinksIfOwnerMatch
        AllowOverride None

</Directory>

<VirtualHost 127.0.0.1:80>
      
      <Directory /apache/htdocs>

        Require all granted

        Options None
        AllowOverride None

      </Directory>

</VirtualHost>

<VirtualHost 127.0.0.1:443>

        SSLEngine On
		Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
		
        <Directory /apache/htdocs>

            Require all granted

            Options None
            AllowOverride None

        </Directory>

</VirtualHost>

```

Ich beschreibe nicht die gesamte Konfiguration, nur die gegenüber Lektion 2 hinzugekommenen Direktiven. Neu lauschen wir neben dem Port 80 auch noch auf Port 443; dem _HTTPS-Port_. Wie erwartet ist das *SSL-*Modul neu hinzugeladen und ferner das Header-Modul, das wir weiter unten benötigen. Dann konfigurieren wir den Schlüssel und das Zertifikat mittels der Direktiven _SSLCertificateKeyFile_ und _SSLCertificateFile_. In der Protokollzeile (_SSLProtocol_) ist es sehr wichtig, das wir das ältere und unsichere Protokoll _SSLv2_ ausschalten, aber auch _SSLv3_ ist seit der _POODLE_ Attacke nicht mehr länger sicher. Am besten wäre es, nurmehr _TLSv1.2_ zuzulassen, aber das beherrschen noch nicht alle Browser. Wir schliessen also einfach _SSLv2_ sowie _SSLv3_ vom Gebrauch aus und lassen damit zur Zeit faktisch TLSv1, das sehr seltene TLSv1.1 sowie das quantitativ dominierende TLSv1.2 zu. Der Handshake und die Verschlüsselung geschieht durch einen Satz von mehreren Algorithmen. Diese kryptographischen Algorithmen definieren wir mit der sogenannten _Cipher-Suite_. Es ist wichtig, eine saubere _Cipher-Suite_ zu verwenden, denn an dieser Stelle setzen Abhörangriffe typischerweise an: Sie nützen die Schwächen und die zu geringe Schlüssellänge älterer Algorithmen aus. Eine sehr eingeschränkte Suite verhindert allerdings, dass ältere Browser auf unseren Server zugreifen können. Die vorgeschlagene _Cipher-Suite_ weist eine hohe Sicherheit auf und berücksichtigt auch einige ältere Browser ab Windows Vista. Windows XP und sehr alte Android-Versionen schliessen wir damit aber von der Kommunikation aus.

Im Kern der _Cipher-Suite_ stehen die Algorithmen der Gruppe _HIGH_. Das ist die Gruppe der hochwertigen Ciphers, welche _OpenSSL_ uns via das _SSL-Modul_ zur Verfügung stellt. Die vor diesem Schlüsselwort angeführten Algorithmen, welche an sich auch Teil der _HIGH-Gruppe_ sind, erhalten durch das Voranstellen die Priorität. Danach fügen wir den Hashing-Algorithmus _SHA_ hinzu und schliessen dann eine Reihe von Algorithmen aus, die aus dem einen oder anderen Grund in unserer _Cipher-Suite_ nicht erwünscht sind.

Darauf folgt die Direktive _SSLHonorCipherOrder_. Sie ist von hoher Wichtigkeit. Man spricht bei SSL oft von _Downgrade Attacks_. Dabei versucht ein Angreifer, ein sogenannter Mittelsmann oder Man-in-the-Middle, in den Verkehr einzugreifen und beim Handshake die Parameter so zu beeinflussen, dass zum Schluss ein schlechteres Protokoll verwendet wird als eigentlich möglich wäre. Namentlich die in der _Cipher-Suite_ festgelegte Priorisierung wird damit ausgehebelt. Die Direktive _SSLHonorCipherOrder_ verhindert diese Angriffsart, indem auf der Algorithmen-Präferenz unseres Servers bestanden wird.

Verschlüsselung arbeitet mit Zufallszahlen. Der Zufallszahlengenerator will korrekt gestartet und benützt werden, wozu die Direktive _SSLRandomSeed_ dient. Dies ist wieder ein Punkt wo Performance und Sicherheit bedacht werden wollen. Beim Starten des Servers greifen wir auf die Zufallszahlen des Betriebssystems in _/dev/urandom_ zu. Während des Betriebs des Servers, beim _SSL-Handshake_ verwenden wir dann die apache-eigene Quelle für Zufallszahlen (_builtin_), die sich aus dem Verkehr des Servers speist. Zwar ist _/dev/urandom_ nicht die allerbeste Quelle für Zufallszahlen, aber es ist eine schnelle Quelle und zudem eine, die eine bestimmte Menge Entropie garantiert. Die qualitativ bessere Quelle _/dev/random_ könnte unseren Server unter widrigen Umständen beim Start blockieren, da nicht genügend Daten vorhanden sind, weshalb in aller Regel _/dev/urandom_ bevorzugt wird.

Wir haben auch noch einen zweiten _Virtual-Host_ eingeführt. Er gleicht dem _Virtual-Host_ für Port 80 sehr stark. Die Portnummer ist aber _443_ und wir aktivieren die _SSL-Engine_, die uns die Verschlüsselung des Verkehrs liefert und die oben gesetzen Konfigurationen erst aktiviert. Zusätzlich setzen wir mit Hilfe des oben geladenen Header-Moduls den _Strict-Tarnsport-Security_-Header (kurz _STS_-Header). Dieser HTTP Header ist Teil der Antwort und instruiert den Client, zukünftig für eine Dauer von 365 Tagen (dies entspricht 31536000 Sekunden) nurmehr verschlüsselt auf unseren Server zuzugreifen. Das Flag _includeSubDomains_ besagt, dass neben unserem Hostnamen auch Unter-Domänen in diese Option miteinbezogen werden soll. 

Der _STS_-Header ist der wichtigste einer Gruppe von neueren HTTP Antowrt Headern mit denen wir die Sicherheit unseres Servers verbessern können. Verschiedene Browser unterstützen unterschiedliche Header, so dass es nicht ganz einfach ist, den Überblick zu behalten. Der _STS_-Header sollte aber auf keinen Fall mehr fehlen. Wenn wir uns die Direktive _Header_ genauer ansehen, dann fällt noch das Flag _always_ ins Auge. Es gibt Fälle in denen das Modul nicht anspringt (etwa wenn eine Fehlermeldung an den Client retourniert wird). Mit _always_ garantieren wir, dass der Header in jedem Fall gesetzt wird.

Das wären alle Änderungen an unserer Konfiguration. Schreiten wir also zur Tat.

###Schritt 2: Ausprobieren

Zu Übungszwecken haben wir unseren Testserver wie in den vorangegangenen Lektionen auf der lokalen IP-Adresse _127.0.0.1_ konfiguriert. Probieren wir es also aus:

```bash
$> curl -v https://127.0.0.1/index.html
* Hostname was NOT found in DNS cache
*   Trying 127.0.0.1...
* Connected to 127.0.0.1 (127.0.0.1) port 443 (#0)
* successfully set certificate verify locations:
*   CAfile: none
  CApath: /etc/ssl/certs
* SSLv3, TLS handshake, Client hello (1):
* SSLv3, TLS handshake, Server hello (2):
* SSLv3, TLS handshake, CERT (11):
* SSLv3, TLS handshake, Server key exchange (12):
* SSLv3, TLS handshake, Server finished (14):
* SSLv3, TLS handshake, Client key exchange (16):
* SSLv3, TLS change cipher, Client hello (1):
* SSLv3, TLS handshake, Finished (20):
* SSLv3, TLS change cipher, Client hello (1):
* SSLv3, TLS handshake, Finished (20):
* SSL connection using ECDHE-RSA-AES256-GCM-SHA384
* Server certificate:
* 	 subject: CN=myhost.home
* 	 start date: 2013-10-26 18:00:21 GMT
* 	 expire date: 2023-10-24 18:00:21 GMT
* SSL: certificate subject name 'myhost.home' does not match target host name '127.0.0.1'
* Closing connection 0
* SSLv3, TLS alert, Client hello (1):
curl: (51) SSL: certificate subject name 'myhost.home' does not match target host name '127.0.0.1'
```

Leider waren wir noch nicht erfolgreich. Kein Wunder, denn wir haben einen Server unter der IP-Adresse _127.0.0.1_ angesprochen, er hat sich bei uns aber mit einem Zerifikat für _myhost.home_ gemeldet. Ein typischer Fall eines Handshake-Fehlers.

Wir können _curl_ instruieren, den Fehler zu ignorieren und dennoch eine Verbindung herzustellen. Dies geschieht mit dem Flag _--insecure_, respektive _-k_.:

```bash
curl -v -k https://127.0.0.1/index.html
* Hostname was NOT found in DNS cache
*   Trying 127.0.0.1...
* Connected to 127.0.0.1 (127.0.0.1) port 443 (#0)
* successfully set certificate verify locations:
*   CAfile: none
  CApath: /etc/ssl/certs
* SSLv3, TLS handshake, Client hello (1):
* SSLv3, TLS handshake, Server hello (2):
* SSLv3, TLS handshake, CERT (11):
* SSLv3, TLS handshake, Server key exchange (12):
* SSLv3, TLS handshake, Server finished (14):
* SSLv3, TLS handshake, Client key exchange (16):
* SSLv3, TLS change cipher, Client hello (1):
* SSLv3, TLS handshake, Finished (20):
* SSLv3, TLS change cipher, Client hello (1):
* SSLv3, TLS handshake, Finished (20):
* SSL connection using ECDHE-RSA-AES256-GCM-SHA384
* Server certificate:
* 	 subject: CN=myhost.home
* 	 start date: 2013-10-26 18:00:21 GMT
* 	 expire date: 2023-10-24 18:00:21 GMT
* 	 issuer: CN=myhost.home
* 	 SSL certificate verify ok.
> GET /index.html HTTP/1.1
> User-Agent: curl/7.35.0
> Host: 127.0.0.1
> Accept: */*
> 
< HTTP/1.1 200 OK
< Date: Thu, 01 Oct 2015 07:48:13 GMT
* Server Apache is not blacklisted
< Server: Apache
< Last-Modified: Thu, 24 Sep 2015 11:54:56 GMT
< ETag: "2d-5207ce664322e"
< Accept-Ranges: bytes
< Content-Length: 45
< 
<html><body><h1>It works!</h1></body></html>
* Connection #0 to host 127.0.0.1 left intact

```

Nun klappt es also und unser SSL-Server läuft. Freilich mit einem faulen Zertifikat und wir sind damit weit von einem produktiven Einsatz entfernt.

Im Folgenden geht es nun darum, ein offizielles Zertifikat zu beziehen, dieses dann korrekt zu installieren und unsere Konfiguration noch etwas zu verfeinern.



###Schritt 3a: SSL-Schlüssel und -Zertifikat beziehen

HTTPS erweitert das bekannte HTTP-Protokoll um eine SSL-Schicht. Technisch wurde SSL (_Secure Socket Layer_) zwar heute von TLS (_Transport Security Layer_) ersetzt, aber man spricht dennoch immer noch von SSL. Das Protokoll garantiert verschlüsselten und damit abhörsicheren Datenverkehr. Der Verkehr wird symmetrisch verschlüsselt, was einen hohen Durchsatz garantiert, setzt aber im Fall von HTTPS einen Public-/Private-Key Setup voraus, der den sicheren Austausch der symmetrischen Schlüssel durch sich zuvor unbekannte Kommunikationspartner voraus. Dieser Public-/Private-Key Handshake geschieht mit Hilfe eines Serverzertifikats, das durch eine offizielle Stelle signiert werden muss.

Serverzertifikate existieren in verschiedenen Formen, Validierungen und Gültigkeitsbereichen. Nicht jedes Merkmal ist wirklich technischer Natur, das Marketing spielt auch eine Rolle. Die Preisunterschiede sind sehr gross, weshalb sich ein Vergleich lohnt. Für unseren Test-Setup verwenden wir ein freies Zertifikat, das wir aber dennoch offiziell beglaubigen lassen. Diese Beglaubigung übernimmt Let's Encrypt für uns. Diese 2015 ins Leben gerufene Certificate Authority steht unentgeltlich zur Verfügung und vereinfacht den Signierungsprozess gegenüber den traditionellen, kommerziellen Signierungsstellen massiv.

Bevor Let's Encrypt uns ein validiertes Zertifikat für unseren Server aushändigt, muss die Certificate Authority sicherstellen, dass wir auch wirklich im Besitz der Domain sind, für die wir ein Zertifikat erstellen lassen möchten. Dies geschieht so, dass wir ein Test-Datei auf dem unserem Server platzieren müssen. Dann rufen wir eine URL bei Let's Encrypt auf und beauftragen die Zertifizierungsstelle mit der Überprüfung. Let's Encrypt spricht dann unseren Webserver auf und vergleicht den Inhalt der Testdatei mit den Daten im Auftrag. Stimmen die Daten überein, dann haben wir belegt, dass wir den Server mit der verlangten Domain tatsächlich kontrollieren und Let's Encrypt akzeptiert uns als Besitzer der besagten Domain. Darauf stellt es uns ein Zertifikat aus. Dieses installieren wir daraufhin auf dem Webserver.

Es gibt verschiedene Clients zum Umgang mit Let's Encrypt. Luca Käser hat mich auf `getssl` hingewiesen, das einfache Bedienung auf der Kommandozeile und maximale Kontrolle bietet. Es eignet sich auf für den produktiven Einsatz sehr gut, da es in der Lage ist, die Testdatei nicht nur auf dem lokalen System zu deponieren, sondern auch mittels `ssh` auf einem entfernten System einzustellen. Das ist dann von Vorteil, wenn man dem Webserver nicht erlaubt, selbst Anfragen ins Internet abzusetzen und damit der Auftrag an Let's Encrypt nicht vom Webserver selbst ausgelöst werden kann.

Aber dies ist ein fortgeschrittenes Szenario. Für den einfachen Fall rufen wir Let's Encrypt direkt auf. Zunächst müssen wir uns aber das Skript `getssl` besorgen, denn es ist so frisch, dass es noch nicht Teil der weit verbreiteten Linux Distributionen ist. Wir laden das Skript herunter. In meinem Fall lege ich es im privaten `bin`-Ordner ab. Je nach eigenem Setup wird man einen alternativen Platz dafür bestimmen. Wichtig ist, dass `getssl` in der Folge Teil des Shell-Suchpfades ist. Wir beziehen das Skript von Github. Es besteht die Möglichkeit, das gesamte Projektverzeichnis zu clonen. Wir machen es uns aber einfach, indem wir einfach das Skript herunterladen und ausführbar machen.

```bash
$> wget https://raw.githubusercontent.com/srvrco/getssl/master/getssl -O $HOME/bin/getssl && chmod +x $HOME/bin/getssl
...
```

Als Beispiel-Domain benütze ich `christian-folini.ch`. In einem ersten Schritt erstellen wir eine Grundkonfiguration für die Domain. 

```bash
$> getssl -c christian-folini.ch
...
```

Das Skript legt das Skript damit einen Vereichnisbaum an mit folgenden Verzeichnissen und Dateien an:

```bash
.getssl
.getssl/getssl.cfg
.getssl/christian-folini.ch
.getssl/christian-folini.ch/christian-folini.ch.crt
.getssl/christian-folini.ch/getssl.cfg
```

Bevor wir uns ein Zertifikat erstellen lassen können ist es wichtig, dass wir die beiden `getssl.cfg`-Dateien kurz bearbeiten. Zunächst die Grundkonfiguration in der Datei `.getssl/getssl.cfg`. In der Datei ist zu beachten, dass Let's Encrypt eine Test-CA mit der URL `https://acme-staging.api.letsencrypt.org` betreibt mit der man den eigenen Setup ausprobieren kann - und dann die richtige CA, welche die offiziellen Zertifikate ausstellt. Es ist sinnvoll, zunächst alles auf der Test-CA auszuprobieren und wenn die Pfade stimmen und die Validierung erfolgreich abgeschlossen wurde, die offizielle CA URL `https://acme-v01.api.letsencrypt.org` einzutragen. In der Datei `.getssl/getssl.cfg` ist per Default die Test-CA eingetragen. Zu Beginn gibt es deshalb nicht viel zu tun, lediglich die Variable `ACCOUNT_EMAIL` sollte sinnvollerweise ausgefüllt werden.

Schreiten wir dann zur Konfigurations-Datei der Domain `.getssl/christian-folini.ch/getssl.cfg`. Hier überprüfen wir den Wert `SANS` (ich vermute er bedeutet `Subject Alternative NameS`) und bezeichnet damit weitere Host-Namen oder in der CA-Sprache `Subject-Names`, die in das Zertifikat eingetragen werden. Im Fall der Domain `christian.folini.ch` erwarten wir hier `SANS=www.christian-folini.ch`. Die meisten anderen Werte sind auskommentiert, was bedeutet, dass diejenigen Werte, die in der übergeordneten Datei gesetzt wurden, weitervererbt und hier nicht mehr speziell gesetzt werden müssen. Ein wichtiger Wert bleibt aber zu setzen: `ACL`. Für den Laborsetup lege ich den Wert wie folgt fest: `ACL=/apache/htdocs/.well-known/acme-challenge`. Der Pfad-Teil ab `.well-known` entspricht damit dem Let's Encrypt Standard. Es sind aber beliebige andere Optionen möglich.

Nun starten wir den ersten Aufruf an Let's Encrypt:

```bash
$> getssl christian-folini.ch
archiving old certificate file to /home/dune73/.getssl/christian-folini.ch/christian-folini.ch.crt_2016-09-30_2016-12-29
creating account key /home/folini/.getssl/account.key
Generating RSA private key, 4096 bit long modulus
..................................................++
............................................................++
e is 65537 (0x10001)
creating domain key - /home/folini/.getssl/christian-folini.ch/christian-folini.ch.key
Generating RSA private key, 4096 bit long modulus
..............++
...................................++
e is 65537 (0x10001)
creating domain csr - /home/folini/.getssl/christian-folini.ch/christian-folini.ch.csr
Registering account
Registered
Verify each domain
Verifing christian-folini.ch
copying challenge token to /apache/htdocs/.well-known/acme-challenge/xiM4FlHAqxo9fuAG-Ag-BTV_DsUJAbegPoZ6-l_luSA
Pending
Verified christian-folini.ch
Verification completed, obtaining certificate.
Certificate saved in /home/folini/.getssl/christian-folini.ch/christian-folini.ch.crt
The intermediate CA cert is in /home/folini/.getssl/christian-folini.ch/chain.crt
getssl: christian-folini.ch - certificate obtained but certificate on server is different from the new certificate
```

Wir sehen schön, wie zunächst ein neuer Schlüssel erstellt wurde. Dann wurde ein `Certificate Signing Request` mit der Datei-Endung `csr` generiert und dann die Testdatei `/apache/htdocs/.well-known/acme-challenge/xiM4FlHAqxo9fuAG-Ag-BTV_DsUJAbegPoZ6-l_luSA` hinterlegt. Darauf folgt der Auftrag zur Überprüfung und Signierung an Let's Encrypt. Im Access Log des Servers sehen wir danach den folgenden Eintrag (Die IP Adressen des Validierungsservers können variieren):

```bash
66.133.109.36 US - [2016-10-02 06:26:40.635068] "GET /.well-known/acme-challenge/zg0bwpHNmRmFdXS4YeTgjBKiy84JoYDpu-cHON2mC9k HTTP/1.1" 200 87 "-" "Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)"
``` 
Wenn wir oben die Ausgabe des `getssl` Kommandos nochmals überprüfen, dann sehen wir, dass die Verifikation über die Bühne ging. Auch ein Zertifikat wurde erstellt und ausgeliefert. Dennoch lief etwas schief, denn auf der letzten Zeile rapportiert das Skript, dass das Zertifikat, das auf dem Server liege, nicht mit dem ausgelieferten übereinstimmt. Das ist tatsächlich der Fall, denn wir haben das Zertifikat, ja noch nicht auf dem Server installiert. Das Skript ist in der Lage, dies ebenfalls in einem Durchlauf zu erledigen (Dazu dienen die Variablen `DOMAIN_KEY_LOCATION` sowie `RELOAD_CMD` im Konfigurationsfile).

Schauen wir uns das erhaltene Zertifikat erst einmal genauer an. Wichtig sind die Felder Validity mit dem zeitlichen Geltungsbereich des Zertifikats (3 Monate), der Signierungsalgorithmus, der Public Key Algorithmus und natürlich Subject sowie Subject Alternative Name. Um all das zu überprüfen benutzen wir die Kommandozeilenversion von `openssl`:

```bash
$> openssl x509 -text -in ~/.getssl/christian-folini.ch/christian-folini.ch.crt
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            03:ff:3f:b2:c2:5f:1b:05:c7:b2:8f:79:92:9e:84:38:47:50
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=US, O=Let's Encrypt, CN=Let's Encrypt Authority X3
        Validity
            Not Before: Oct  2 03:33:00 2016 GMT
            Not After : Dec 31 03:33:00 2016 GMT
        Subject: CN=christian-folini.ch
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (4096 bit)
                Modulus:
                    00:9f:d8:47:62:a0:58:9b:57:7e:ee:43:1c:c0:2e:
                    71:2a:73:71:f5:89:f5:9b:3e:c1:f9:fd:63:78:56:
                    fd:91:52:69:6c:39:ec:47:75:8d:29:e0:66:bf:c1:
                    1c:d4:7b:ba:b2:5d:34:4b:e9:92:b2:a8:d4:07:5f:
                    51:ea:e7:93:c1:94:ad:93:15:57:dd:72:3c:e5:ad:
                    af:f1:c2:7d:fb:88:23:53:6f:44:93:ac:0f:e1:8b:
                    8b:d8:ef:b4:f3:ec:ff:d0:72:13:3e:a8:86:03:ef:
                    f0:69:1f:c4:05:b5:39:cb:65:57:6b:7a:11:7b:6c:
                    f1:fe:ef:4b:72:3d:13:20:ea:e5:f3:3f:85:2e:8d:
                    fa:fc:bb:5a:b9:25:9f:fd:b5:3a:bb:e9:7e:e8:4d:
                    3f:c4:fc:8d:6d:02:96:0e:ce:a1:0a:a1:86:b5:01:
                    f6:12:7f:5f:83:5c:2e:27:13:b3:27:4f:b8:b4:15:
                    bf:da:cc:de:7e:42:bf:c6:f2:b6:7e:fc:48:18:13:
                    c9:c2:7a:3c:79:af:6f:b7:ae:94:9c:a6:09:b7:6c:
                    e9:2e:3a:37:e2:29:ae:a0:30:80:4c:0d:10:52:3d:
                    74:2a:c4:f5:61:88:19:bc:16:1e:07:6e:d5:c2:04:
                    4c:e8:06:4b:2a:a2:2e:94:f6:3c:ab:60:aa:be:b9:
                    a4:fe:0e:b3:b1:80:dd:1f:30:d3:d8:24:24:0e:e1:
                    8c:4c:29:e1:e0:43:bf:63:e7:13:ba:40:d6:10:e0:
                    70:13:22:f7:8c:40:c5:27:44:68:00:b5:0c:a0:9e:
                    8b:50:cd:b7:d2:72:a1:97:b7:9e:20:65:58:bb:17:
                    30:25:c0:02:4d:b7:b7:ba:84:26:01:39:e4:e6:e5:
                    39:6e:3e:c6:16:8e:43:5b:67:a7:17:a0:5c:9a:fc:
                    f1:5e:ba:65:b9:e4:05:52:62:a8:3b:85:8a:0a:2a:
                    8f:3d:f7:64:57:cf:f4:3b:aa:a8:b1:9b:3b:b8:e3:
                    bc:b4:77:2c:1c:58:ed:d5:70:ad:79:01:40:4e:13:
                    86:15:32:2b:49:6d:23:c5:32:83:90:a8:a2:73:99:
                    be:0a:e8:8c:73:8e:52:f2:29:ba:f9:07:2d:34:f1:
                    9a:85:d0:bf:d4:65:86:ca:4b:27:d8:f1:62:1e:18:
                    e0:f5:e5:8d:71:d3:86:d4:52:8f:e4:20:20:70:59:
                    5f:3e:22:76:41:8c:31:2e:8d:7f:b4:a2:9b:15:a1:
                    19:d4:97:e3:27:fe:71:b6:b1:cf:27:4f:ce:1a:50:
                    03:e2:57:88:c3:62:40:48:7b:72:cb:4a:d2:df:8e:
                    22:ca:f6:2a:65:50:cc:5a:bd:bc:83:b3:1d:f6:5c:
                    5b:3d:0f
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Subject Key Identifier: 
                56:36:4C:45:62:06:78:97:C7:12:E2:F1:22:6B:DA:3E:80:1B:70:FD
            X509v3 Authority Key Identifier: 
                keyid:A8:4A:6A:63:04:7D:DD:BA:E6:D1:39:B7:A6:45:65:EF:F3:A8:EC:A1

            Authority Information Access: 
                OCSP - URI:http://ocsp.int-x3.letsencrypt.org/
                CA Issuers - URI:http://cert.int-x3.letsencrypt.org/

            X509v3 Subject Alternative Name: 
                DNS:christian-folini.ch
            X509v3 Certificate Policies: 
                Policy: 2.23.140.1.2.1
                Policy: 1.3.6.1.4.1.44947.1.1.1
                  CPS: http://cps.letsencrypt.org
                  User Notice:
                    Explicit Text: This Certificate may only be relied upon by Relying Parties and only in accordance with the Certificate Policy found at https://letsencrypt.org/repository/

    Signature Algorithm: sha256WithRSAEncryption
         2b:a8:79:e6:92:c1:e2:aa:d4:2f:a3:95:c1:e8:4c:17:e8:7e:
         c7:6f:be:cb:b8:2d:ea:c4:98:5e:ca:08:86:df:88:55:77:3d:
         bd:56:b9:61:79:c2:a0:74:05:88:42:b7:09:d6:c5:f7:28:9a:
         dd:2c:a2:6f:79:b7:66:47:04:47:52:4e:8d:d5:a1:be:87:1f:
         0a:23:ff:9b:75:f3:cb:ab:52:24:4f:9e:fa:56:88:ce:42:1d:
         0f:95:cb:b1:d1:ac:29:8b:a1:bd:9f:7a:cd:47:66:25:29:26:
         47:09:18:7c:8b:00:ad:de:ba:be:4c:ee:8e:16:bc:51:77:94:
         16:e9:87:8e:6a:66:e3:d3:66:38:f2:15:e0:76:65:e8:3f:26:
         62:55:e1:22:ee:4d:a6:48:cf:50:30:3d:f4:af:03:d7:54:cb:
         a3:2b:cf:9c:45:a9:52:33:11:81:5c:29:44:a9:c7:66:0a:f8:
         2d:0b:c3:a7:15:dc:1b:03:17:fe:52:b2:54:93:02:16:56:43:
         74:d9:bd:04:19:dc:b7:75:78:36:13:97:a8:73:8b:14:9e:70:
         78:18:10:f3:ad:2c:12:48:44:dd:9a:ad:87:a4:c9:1f:2d:a3:
         e7:48:8f:e0:ca:6b:31:11:f6:d0:60:9d:20:d2:18:84:94:e1:
         4f:cd:9c:ee
-----BEGIN CERTIFICATE-----
MIIGEjCCBPqgAwIBAgISA/8/ssJfGwXHso95kp6EOEdQMA0GCSqGSIb3DQEBCwUA
MEoxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MSMwIQYDVQQD
ExpMZXQncyBFbmNyeXB0IEF1dGhvcml0eSBYMzAeFw0xNjEwMDIwMzMzMDBaFw0x
NjEyMzEwMzMzMDBaMCIxIDAeBgNVBAMTF3d3dy5jaHJpc3RpYW4tZm9saW5pLmNo
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAn9hHYqBYm1d+7kMcwC5x
KnNx9Yn1mz7B+f1jeFb9kVJpbDnsR3WNKeBmv8Ec1Hu6sl00S+mSsqjUB19R6ueT
wZStkxVX3XI85a2v8cJ9+4gjU29Ek6wP4YuL2O+08+z/0HITPqiGA+/waR/EBbU5
y2VXa3oRe2zx/u9Lcj0TIOrl8z+FLo36/LtauSWf/bU6u+l+6E0/xPyNbQKWDs6h
CqGGtQH2En9fg1wuJxOzJ0+4tBW/2szefkK/xvK2fvxIGBPJwno8ea9vt66UnKYJ
t2zpLjo34imuoDCATA0QUj10KsT1YYgZvBYeB27VwgRM6AZLKqIulPY8q2Cqvrmk
/g6zsYDdHzDT2CQkDuGMTCnh4EO/Y+cTukDWEOBwEyL3jEDFJ0RoALUMoJ6LUM23
0nKhl7eeIGVYuxcwJcACTbe3uoQmATnk5uU5bj7GFo5DW2enF6BcmvzxXrplueQF
UmKoO4WKCiqPPfdkV8/0O6qosZs7uOO8tHcsHFjt1XCteQFAThOGFTIrSW0jxTKD
kKiic5m+CuiMc45S8im6+QctNPGahdC/1GWGyksn2PFiHhjg9eWNcdOG1FKP5CAg
cFlfPiJ2QYwxLo1/tKKbFaEZ1JfjJ/5xtrHPJ0/OGlAD4leIw2JASHtyy0rS344i
yvYqZVDMWr28g7Md9lxbPQ8CAwEAAaOCAhgwggIUMA4GA1UdDwEB/wQEAwIFoDAd
BgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwDAYDVR0TAQH/BAIwADAdBgNV
HQ4EFgQUVjZMRWIGeJfHEuLxImvaPoAbcP0wHwYDVR0jBBgwFoAUqEpqYwR93brm
0Tm3pkVl7/Oo7KEwcAYIKwYBBQUHAQEEZDBiMC8GCCsGAQUFBzABhiNodHRwOi8v
b2NzcC5pbnQteDMubGV0c2VuY3J5cHQub3JnLzAvBggrBgEFBQcwAoYjaHR0cDov
L2NlcnQuaW50LXgzLmxldHNlbmNyeXB0Lm9yZy8wIgYDVR0RBBswGYIXd3d3LmNo
cmlzdGlhbi1mb2xpbmkuY2gwgf4GA1UdIASB9jCB8zAIBgZngQwBAgEwgeYGCysG
AQQBgt8TAQEBMIHWMCYGCCsGAQUFBwIBFhpodHRwOi8vY3BzLmxldHNlbmNyeXB0
Lm9yZzCBqwYIKwYBBQUHAgIwgZ4MgZtUaGlzIENlcnRpZmljYXRlIG1heSBvbmx5
IGJlIHJlbGllZCB1cG9uIGJ5IFJlbHlpbmcgUGFydGllcyBhbmQgb25seSBpbiBh
Y2NvcmRhbmNlIHdpdGggdGhlIENlcnRpZmljYXRlIFBvbGljeSBmb3VuZCBhdCBo
dHRwczovL2xldHNlbmNyeXB0Lm9yZy9yZXBvc2l0b3J5LzANBgkqhkiG9w0BAQsF
AAOCAQEAK6h55pLB4qrUL6OVwehMF+h+x2++y7gt6sSYXsoIht+IVXc9vVa5YXnC
oHQFiEK3CdbF9yia3Syib3m3ZkcER1JOjdWhvocfCiP/m3Xzy6tSJE+e+laIzkId
D5XLsdGsKYuhvZ96zUdmJSkmRwkYfIsArd66vkzujha8UXeUFumHjmpm49NmOPIV
4HZl6D8mYlXhIu5NpkjPUDA99K8D11TLoyvPnEWpUjMRgVwpRKnHZgr4LQvDpxXc
GwMX/lKyVJMCFlZDdNm9BBnct3V4NhOXqHOLFJ5weBgQ860sEkhE3Zqth6TJHy2j
50iP4MprMRH20GCdINIYhJThT82c7g==
-----END CERTIFICATE-----
```

Falls dieses Zertifikat unseren Vorstellungen entspricht, kopieren wir es gemeinsam mit dem Schlüssel auf den Server:


```bash
$> cp ~/.getssl/christian-folini.ch.key /etc/ssl/private/
$> cp ~/.getssl/christian-folini.ch.crt /etc/ssl/certs/
``` 

Danach tragen wir die neuen Pfade in der Konfiguration ein:

```bash
SSLCertificateKeyFile   /etc/ssl/private/christian-folini.ch.key
SSLCertificateFile      /etc/ssl/certs/christian-folini.ch.crt
```

FIXME: Chain File / Intermediate Cert


Und nun bleibt noch der Start oder Neustart des Servers und wir haben ein offiziell signiertes Zertifikat komplett installiert.

FIXME ###Schritt 4: Zertifikat für die Vertrauenskette beziehen

Ich setze voraus, dass Sie ein offiziell signiertes Zertifikat mit zugehörigem Schlüssel wie beschrieben bezogen oder selbst generiert und offiziell signiert haben.

Die Funktionsweise des _SSL-/TLS_-Protokolls ist anspruchsvoll. Eine gute Einführung bietet das _OpenSSL Cookbook_ von Ivan Ristić (siehe Links) oder sein umfassenderes Werk _Bulletproof SSL und TLS_. Ein Bereich, der schwer verständlich ist, umfasst die Vertrauensbeziehungen, die _SSL_ garantiert. Der Webbrowser vertraut von Beginn weg einer Liste von Zertifizierungs-Authoritäten, wozu auch _StartSSL_ gehört. Beim Aufbau der _SSL_-Verbindung wird dieses Vertrauen auf unseren Webserver erweitert. Dies geschieht mit Hilfe des Zertifikates. Es wird eine Vertrauenskette zwischen der Zertifizierungs-Authorität und unserem Server gebildet. Aus technischen Gründen gibt es ein Zwischenglied zwischen der Zertifizierungs-Authorität und unserem Webserver. Dieses Glied müssen wir in der Konfiguration auch definieren. Zunächst müssen wir die Datei aber beziehen:

```bash
$> wget https://www.startssl.com/certs/sub.class1.server.ca.pem -O startssl-class1-chain-ca.pem
```

Ich wähle beim Herunterladen einen etwas anderen Datei-Namen als vorgegeben. Wir gewinnen dadurch an Klarheit für die Konfiguration. Die signierten Dateien werden bei der Überprüfung durch den Client aneinandergereiht. Gemeinsam bilden die Signaturen auf den Zertifikaten dann die Vertrauenskette von unserem Zertifikat zur _Certificate Authority_.


FIXME ###Schritt 5: SSL Schlüssel und Zertifikate installieren

Damit sind nun der Schlüssel und die zwei benötigten Zertifikate vorhanden. Konkret:

* server.key _Server-Schlüssel_
* server.crt _Server-Zertifikat_
* startssl-class1-chain-ca.pem _StartSSL-Chainfile_

Wir installieren sie in zwei speziell gesicherte Unterverzeichnisse des Konfigurations-Ordners:

```bash
$> mkdir /apache/conf/ssl.key
$> chmod 700 /apache/conf/ssl.key
$> mv server.key /apache/conf/ssl.key
$> chmod 400 /apache/conf/ssl.key/server.key
$> mkdir /apache/conf/ssl.crt
$> chmod 700 /apache/conf/ssl.crt
$> mv server.crt /apache/conf/ssl.crt
$> chmod 400 /apache/conf/ssl.crt/server.crt
$> mv startssl-class1-chain-ca.pem /apache/conf/ssl.crt/
$> chown -R root:root /apache/conf/ssl.*/
```

###Schritt 6: Passphrase Dialog automatisch beantworten

Beim Beziehen des Schlüssels mussten wir eine Passphrase definieren, um den Schlüssel zu entsperren. Damit unser Webserver den Schlüssel benutzen kann, müssen wir ihm diesen Code bekannt geben. Er wird uns beim Starten des Servers danach fragen. Möchten wir das nicht, dann müssen wir es in der Konfiguration mit angeben. Wir tun dies mittels einer separaten Datei, die auf Anfrage die Passphrase liefert. Nennen wir diese Datei _/apache/bin/gen_passphrase.sh_ und tragen wir die oben gewählte Passphrase ein:

```bash
#!/bin/sh
echo "S7rh29Hj3def-07hdkBgj4jDfg_skDg$48JuPhd"
```

Diese Datei muss speziell gesichert und vor fremden Augen geschützt werden.

```bash
$> sudo chmod 700 /apache/bin/gen_passphrase.sh
$> sudo chown root:root /apache/bin/gen_passphrase.sh
```

FIXME ###Schritt 7: Apache konfigurieren

Nun sind alle Vorbereitungen abgeschlossen und wir können den Webserver final konfigurieren. Ich liefere hier nicht mehr die komplette Konfiguration, sondern nur noch den korrekten Servernamen und den verfeinerten SSL-Teil:


```bash
ServerName		www.example.com

...

LoadModule              socache_shmcb_module    modules/mod_socache_shmcb.so

...

SSLCertificateKeyFile   conf/ssl.key/server.key
SSLCertificateFile      conf/ssl.crt/server.crt
SSLCertificateChainFile conf/ssl.crt/startssl-class1-chain-ca.pem
SSLPassPhraseDialog     exec:bin/gen_passphrase.sh

SSLProtocol             All -SSLv2 -SSLv3
SSLCipherSuite		'kEECDH+ECDSA kEECDH kEDH HIGH +SHA !aNULL !eNULL !LOW !MEDIUM \
!MD5 !EXP !DSS !PSK !SRP !kECDH !CAMELLIA !RC4'
SSLHonorCipherOrder	On

SSLRandomSeed           startup file:/dev/urandom 2048
SSLRandomSeed           connect builtin

SSLSessionCache 	"shmcb:/apache/logs/ssl_gcache_data(1024000)"
SSLSessionTickets	On


...


<VirtualHost 127.0.0.1:443>

	ServerName              www.example.com
	
	SSLEngine On
	Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"

	...
```

Sinnvoll ist es, den mit dem Zertifikat übereinstimmenden _ServerName_ auch im _VirtualHost_ bekanntzugeben. Wenn wir das nicht tun, wird Apache eine Warnung ausgeben (und dann dennoch den einzigen konfigurierten VirtualHost wählen und korrekt weiterfunktionieren).

Neu hinzugekommen sind auch die beiden Optionen _SSLSessionCache_ sowie _SSLSessionTickets_. Die beiden Direktiven kontrollieren das Verhalten des _SSL Session Caches_. Voraussetzung für den Cache ist das Modul *socache_shmcb*, welches die Caching-Funktionalität zur Verfügung stellt und von *mod_ssl* angesprochen wird. Das funktioniert folgendermassen: Während des SSL Handshakes werden Parameter der Verbindung wie etwa der Schlüssel und ein Verschlüsselungsalgorithmus ausgehandelt. Dies geschieht im Public-Key Modus, der sehr rechenintensiv ist. Ist der Handshake erfolgreich beendet, verkehrt der Server mit dem Client über die performantere symmetrische Verschlüsselung mit Hilfe der eben ausgehandelten Parameter. Ist der Request beendet und die _Keep-Alive_ Periode ohne neue Anfrage verstrichen, dann gehen die TCP-Verbindung und die mit der Verbindung verhängten Parameter verloren. Wird die Verbindung kurze Zeit später neu aufgebaut, müssen die Parameter neu ausgehandelt werden. Das ist aufwändig, wie wir eben gesehen haben. Besser wäre es, man könnte die vormals ausgehandelten Parameter re-aktivieren. Diese Möglichkeit besteht in der Form des _SSL Session Caches_. Traditionell wird dieser Cache serverseitig verwaltet.

Beim Session Cache via Tickets werden die Parameter in einem Session Ticket zusammengefasst und dem Client übergeben, wo sie clientseitig gespeichert werden, was auf dem Webserver Speicherplatz spart. Beim Aufbau einer neuen Verbindung sendet der Client die Parameter an den Server und dieser konfiguriert die Verbindung entsprechend. Um eine Manipulation der Parameter im Ticket zu verhindern, signiert der Server das Ticket vorgängig und überprüft es beim Aufbei einer Verbindung wieder. Bei diesem Mechanismus ist daran zu denken, dass die Signatur von einem Signierschlüssel abhängt und es sinnvoll ist, diesen meist dynamisch erzeugten Schlüssel regelmässig zu erneuern. Ein neues Laden des Server gewährleistet dies.

SSL Session Tickets sind jünger und nunmehr von allen relevanten Browsern unterstützt. Sie gelten auch als sicher. Das ändert aber nichts an der Tatsache, dass zumindest eine theoretische Verwundbarkeit besteht, indem die Session Parameter clientseitig gestohlen werden können. 

Beide Varianten des Session Caches lassen sich ausschalten. Dies geschieht wie folgt: 

```bash
SSLSessionCache         nonenotnull
SSLSessionTickets	Off
```

Natürlich bleibt diese Anpassung nicht ohne Folgen für die Performance. Allerdings nimmt sich der Performance-Verlust durchaus klein aus. Es wäre überraschend, wenn ein Last-Test auf das Ausschalten mit einem Leistungsrückgang von mehr als 10% reagieren würde.


###Schritt 8: Ausprobieren

Zu Übungszwecken haben wir unseren Testserver erneut auf der lokalen IP-Adresse _127.0.0.1_ konfiguriert. Um das Funktionieren der Zertifikatskette zu testen, dürfen wir den Server nicht einfach mittels der IP-Adresse ansprechen, sondern wir müssen ihn mit dem korrekten Hostnamen kontaktieren. Und dieser Hostname muss natürlich mit demjenigen auf dem Zertifikat übereinstimmen. Im Fall von _127.0.0.1_ erreichen wir dies, indem wir das _Host-File_ unter _/etc/hosts_ anpassen:

```bash
127.0.0.1	localhost myhost www.example.com
...
```

FIXME Nun können wir entweder mit dem Browser oder mit curl auf die URL [https://www.example.com](https://www.example.com) zugreifen. Wenn dies ohne eine Zertifikats-Warnung funktioniert, dann haben wir den Server korrekt konfiguriert. Etwas genauer lässt sich die Verschlüsselung und die Vertrauenskette mit dem Kommendozeilen-Tool _OpenSSL_ überprüfen. Da _OpenSSL_ aber anders als der Browser und curl keine Liste mit Zertifikatsauthoritäten besitzt, müssen wir dem Tool das Zertifikat der Authorität auch mitgeben. Wir besorgen es uns bei _StartSSL_.

```bash
$> wget https://www.startssl.com/certs/ca.pem
...
$> openssl s_client -showcerts -CAfile ca.pem -connect www.example.com:443
```
Hier instruieren wir _OpenSSL_, den eingebauten client zu verwenden, uns die vollen Zertifikatsinformationen zu zeigen, das eben heruntergeladene CA-Zertifikat zu verwenden und mit diesen Parametern auf unseren Server zuzugreifen. Im optimalen Fall sieht der Output (leicht gekürzt) wie folgt aus:

```bash
CONNECTED(00000003)
---
Certificate chain
 0 s:/description=329817-gqai4gyx3JMxBbCV/C=CH/O=Persona Not Validated/OU=StartCom Free Certificate …
   i:/C=IL/O=StartCom Ltd./OU=Secure Digital Certificate Signing/CN=StartCom Class 1 Primary …
-----BEGIN CERTIFICATE-----
MIIHtDCCBpygAwIBAgIDArSFMA0GCSqGSIb3DQEBBQUAMIGMMQswCQYDVQQGEwJJ
...
...
...
x94JRF4camVVVDe3ae7TXZ/xl/Y8vR7TMbZJx4vg33IjnmLS6FOlf97BP6wA7wZN
zZnCQe+3NTU=
-----END CERTIFICATE-----
 1 s:/C=IL/O=StartCom Ltd./OU=Secure Digital Certificate Signing/CN=StartCom Class 1 Primary …
   i:/C=IL/O=StartCom Ltd./OU=Secure Digital Certificate Signing/CN=StartCom Certification …
-----BEGIN CERTIFICATE-----
MIIGNDCCBBygAwIBAgIBGDANBgkqhkiG9w0BAQUFADB9MQswCQYDVQQGEwJJTDEW
...
...
...
p/EiO/h94pDQehn7Skzj0n1fSoMD7SfWI55rjbRZotnvbIIp3XUZPD9MEI3vu3Un
0q6Dp6jOW6c=
-----END CERTIFICATE-----
---
Server certificate
subject=/description=329817-gqai4fgt3JMxBbCV/C=CH/O=Persona Not Validated/OU=StartCom Free Certificate ...
issuer=/C=IL/O=StartCom Ltd./OU=Secure Digital Certificate Signing/CN=StartCom Class 1 Primary ...
---
No client certificate CA names sent
---
SSL handshake has read 4526 bytes and written 319 bytes
---
New, TLSv1/SSLv3, Cipher is AES256-SHA
Server public key is 2048 bit
Secure Renegotiation IS supported
Compression: NONE
Expansion: NONE
SSL-Session:
    Protocol  : TLSv1
    Cipher    : AES256-SHA
    Session-ID: FE496BB191B6888EA9CA3ED4E166707857186D5B32F1A0D9E418145D1B721CB4
    Session-ID-ctx: 
    Master-Key: 1BF16E22B0DF086E1AF4E13D9158AC0A3B1039E334C0C7F177A8757694B516E00E20AC3D6250B10D…
    Key-Arg   : None
    Start Time: 1294591828
    Timeout   : 300 (sec)
    Verify return code: 0 (ok)
---
```

Damit haben wir einen sauberen _HTTPS-Server_ konfiguriert. 

Interessanterweise gibt es im Internet so etwas wie eine Hitparade, was sichere _HTTPS-Server_ betrifft. Das sehen wir uns nun noch als Bonus an.


###Schritt 9 (Bonus): Qualität der SSL Sicherung extern überprüfen lassen

Ivan Ristić, der oben erwähnte Autor von mehreren Büchern über Apache und SSL, betreibt im Dienst von Qualys einen Analyse-Service zur Überprüfung von _SSL-Webservern_. Er befindet sich unter [www.ssllabs.com](https://www.ssllabs.com/ssldb/index.html). Ein Webserver wie oben konfiguriert brachte mir im Test die Höchstnote von _A+_ ein.

![Screenshot: SSLLabs](./apache-tutorial-03-screenshot-ssllabs.png)
Die Höchstnote ist mit dieser Anleitung in Reichweite.

###Verweise

* [Wikipedia OpenSSL](http://de.wikipedia.org/wiki/Openssl)
* [Apache Mod_SSL](http://httpd.apache.org/docs/2.4/mod/mod_ssl.html)
FIXME * [StartSSL Zertifikate](https://www.startssl.com)
* [SSLLabs](https://www.ssllabs.com)
* [OpenSSL Cookbook](https://www.feistyduck.com/books/openssl-cookbook/)
* [Bulletproof SSL und TLS](https://www.feistyduck.com/books/bulletproof-ssl-and-tls/)
* [Keylength.com - Hintergrundinformationen zu Ciphers und Keys](http://www.keylength.com)


### Lizenz / Kopieren / Weiterverwenden

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png" /></a><br />Diese Arbeit ist wie folgt lizenziert / This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.

