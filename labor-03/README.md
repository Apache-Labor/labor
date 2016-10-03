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

Schreiten wir dann zur Konfigurations-Datei der Domain `.getssl/christian-folini.ch/getssl.cfg`. Hier überprüfen wir den Wert `SANS` (ich vermute er bedeutet `Subject Alternative NameS`) und bezeichnet damit weitere Host-Namen oder in der CA-Sprache `Subject-Names`, die in das Zertifikat eingetragen werden. Im Fall der Domain `christian.folini.ch` erwarten wir hier `SANS=www.christian-folini.ch`. Die meisten anderen Werte sind auskommentiert, was bedeutet, dass diejenigen Werte, die in der übergeordneten Datei gesetzt wurden, weitervererbt und hier nicht mehr speziell gesetzt werden müssen. Ein wichtiger Wert bleibt aber zu setzen: `ACL`. Für den Laborsetup lege ich den Wert wie folgt fest: 

```bash
acl=('/apache/htdocs/.well-known/acme-challenge' '/apache/htdocs/.well-known/acme-challenge')
```

Dieses nicht ganz einsichtige Format bezeichnet die Haupt-Domain unseres Zertifikats und dann, mit einem Leerschlag getrennt, die `ACL` für den unter `SANS` definierten zweiten Domain-Namen.



Der Pfad-Teil ab `.well-known` entspricht damit dem Let's Encrypt Standard. Es sind aber beliebige andere Optionen möglich.

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
Verifing www.christian-folini.ch
copying challenge token to /apache/htdocs/.well-known/acme-challenge/QK4x1EyQ1Su7qZ-XTJL7EIqP6brNCRY8ZcGpZpyEc3E
Verified www.christian-folini.ch
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
            03:42:97:46:58:7d:dd:38:6e:1d:b2:fa:76:1c:57:50:b5:22
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=US, O=Let's Encrypt, CN=Let's Encrypt Authority X3
        Validity
            Not Before: Oct  2 06:24:00 2016 GMT
            Not After : Dec 31 06:24:00 2016 GMT
        Subject: CN=christian-folini.ch
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (4096 bit)
                Modulus:
                    00:ac:e6:34:3a:6d:83:37:31:6e:7a:c5:d1:50:99:
                    93:59:b7:12:d6:28:be:fd:cf:3a:25:f0:d0:0f:9d:
                    c2:d9:8f:77:7b:6c:c8:38:41:26:43:c0:ec:91:46:
                    c9:d4:e7:02:40:e9:90:e0:1f:82:f1:00:53:92:1f:
                    bd:af:47:15:f5:59:03:71:0e:e7:ac:cf:d5:89:f2:
                    fc:b7:8a:84:26:37:f4:0d:16:5e:79:c8:8a:87:ec:
                    8c:c0:de:cb:1e:23:36:68:6a:c0:9c:51:04:77:cc:
                    21:01:47:02:3c:d4:6b:fe:c7:b4:d7:b0:05:04:ad:
                    42:e8:fd:41:2d:28:69:85:ba:eb:f2:f9:73:a6:5b:
                    50:1e:a7:df:ec:ae:ab:69:fd:99:f3:90:f0:2b:89:
                    1c:0d:9b:08:5b:ab:5a:6d:70:aa:9e:9c:72:bd:32:
                    dc:8a:91:b1:78:b8:c1:87:2a:7c:53:64:d7:69:00:
                    5b:06:07:14:21:80:13:9e:f3:9c:fd:c9:41:93:60:
                    6f:5a:55:4f:66:f5:50:e7:a9:dc:e2:51:5e:19:5a:
                    a3:5d:a3:58:b1:cb:96:b8:62:80:f1:73:cd:32:9c:
                    fd:b2:3c:44:05:a2:d1:0f:78:0b:2a:2e:43:15:21:
                    2f:81:b0:30:73:8d:ba:fb:e5:ce:0e:49:f5:08:62:
                    dd:af:bb:bb:6a:57:04:e6:43:53:b8:d0:ba:c5:bf:
                    6a:0a:17:12:7e:23:a3:bf:c3:a3:ff:50:ad:fc:54:
                    75:84:f6:e0:0c:5e:75:83:aa:cd:ba:ce:e2:43:cf:
                    e6:65:92:55:b7:3e:02:72:6d:0b:5d:45:18:ae:09:
                    a1:ab:b8:b8:24:d1:ae:74:43:dc:e5:4f:0a:37:b9:
                    05:8e:37:b0:67:01:5e:50:b4:7c:89:52:90:d2:fa:
                    59:c0:33:31:f3:f0:35:80:38:a1:1b:fb:7f:c9:d2:
                    5e:40:75:0f:33:73:1e:eb:dc:e3:9a:d1:dc:d6:94:
                    a9:55:2a:f0:71:20:5e:64:71:b0:cf:03:3e:45:76:
                    a6:ff:f1:12:93:5d:0c:d1:2b:5f:fd:1d:6e:ef:71:
                    69:74:f1:dc:a8:64:c0:6b:a8:14:fc:7b:77:4d:d2:
                    42:41:15:fc:10:84:9f:9b:78:bb:64:b1:6c:22:e4:
                    c1:7d:6b:25:95:2a:91:70:16:4a:87:82:38:cd:7f:
                    0a:03:ce:f0:68:c7:29:e5:63:f0:8a:ea:37:2f:ad:
                    fd:ee:89:89:47:12:59:e8:95:c1:48:49:95:96:39:
                    e8:a0:c5:7e:6f:83:6b:bb:fd:8a:00:74:91:54:a4:
                    f9:89:2c:b9:5b:80:d5:d3:52:5e:41:c4:aa:c5:a5:
                    f6:bb:e5
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Subject Key Identifier: 
                18:46:FD:E3:B3:4C:25:57:46:4A:38:DA:23:78:94:34:23:32:F3:39
            X509v3 Authority Key Identifier: 
                keyid:A8:4A:6A:63:04:7D:DD:BA:E6:D1:39:B7:A6:45:65:EF:F3:A8:EC:A1

            Authority Information Access: 
                OCSP - URI:http://ocsp.int-x3.letsencrypt.org/
                CA Issuers - URI:http://cert.int-x3.letsencrypt.org/

            X509v3 Subject Alternative Name: 
                DNS:christian-folini.ch, DNS:www.christian-folini.ch
            X509v3 Certificate Policies: 
                Policy: 2.23.140.1.2.1
                Policy: 1.3.6.1.4.1.44947.1.1.1
                  CPS: http://cps.letsencrypt.org
                  User Notice:
                    Explicit Text: This Certificate may only be relied upon by Relying Parties and only in accordance with the Certificate Policy found at https://letsencrypt.org/repository/

    Signature Algorithm: sha256WithRSAEncryption
         53:12:78:10:52:13:29:ae:6c:a2:2d:94:1b:34:5a:07:25:0f:
         e0:0e:e7:cd:bb:b6:ea:14:ef:93:76:ad:19:92:aa:9f:9a:b0:
         cf:a1:b9:2f:96:80:af:1d:5f:df:2a:2b:52:fd:05:be:23:21:
         ab:0d:a0:15:c1:62:50:8d:fa:d8:56:f5:af:73:d6:90:72:6c:
         7e:05:1b:db:a6:6f:d6:b7:cb:f0:89:bd:03:73:b2:ce:a4:2a:
         5b:ab:27:6e:16:be:79:9f:b5:74:74:7e:75:d8:b5:e0:d0:0c:
         69:0a:f1:cf:09:b2:84:be:cd:72:1a:cb:45:97:25:e2:be:1d:
         ff:d2:40:8b:bf:d6:29:95:cf:a6:3d:b8:10:d1:eb:33:38:d4:
         35:39:28:27:a8:c1:f8:c2:1e:e5:52:c9:b2:c6:4a:a1:1d:98:
         ea:94:06:2f:af:5e:8e:0b:a3:05:3a:f2:e9:92:e8:63:9a:b8:
         33:3b:86:b9:60:52:a0:90:40:30:80:b8:fa:4a:15:22:cb:34:
         bf:91:5e:9b:51:7e:8b:a7:6d:4c:59:1e:2c:a4:70:d4:cd:9b:
         ae:6b:57:ce:9e:fb:43:8c:ef:c6:a7:f4:be:39:fd:34:61:4c:
         84:21:e0:fb:74:4d:31:bd:45:c3:1a:58:97:c7:bb:15:be:2a:
         74:c0:7a:dd
-----BEGIN CERTIFICATE-----
MIIGIzCCBQugAwIBAgISA0KXRlh93ThuHbL6dhxXULUiMA0GCSqGSIb3DQEBCwUA
MEoxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MSMwIQYDVQQD
ExpMZXQncyBFbmNyeXB0IEF1dGhvcml0eSBYMzAeFw0xNjEwMDIwNjI0MDBaFw0x
NjEyMzEwNjI0MDBaMB4xHDAaBgNVBAMTE2NocmlzdGlhbi1mb2xpbmkuY2gwggIi
MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCs5jQ6bYM3MW56xdFQmZNZtxLW
KL79zzol8NAPncLZj3d7bMg4QSZDwOyRRsnU5wJA6ZDgH4LxAFOSH72vRxX1WQNx
Duesz9WJ8vy3ioQmN/QNFl55yIqH7IzA3sseIzZoasCcUQR3zCEBRwI81Gv+x7TX
sAUErULo/UEtKGmFuuvy+XOmW1Aep9/srqtp/ZnzkPAriRwNmwhbq1ptcKqenHK9
MtyKkbF4uMGHKnxTZNdpAFsGBxQhgBOe85z9yUGTYG9aVU9m9VDnqdziUV4ZWqNd
o1ixy5a4YoDxc80ynP2yPEQFotEPeAsqLkMVIS+BsDBzjbr75c4OSfUIYt2vu7tq
VwTmQ1O40LrFv2oKFxJ+I6O/w6P/UK38VHWE9uAMXnWDqs26zuJDz+ZlklW3PgJy
bQtdRRiuCaGruLgk0a50Q9zlTwo3uQWON7BnAV5QtHyJUpDS+lnAMzHz8DWAOKEb
+3/J0l5AdQ8zcx7r3OOa0dzWlKlVKvBxIF5kcbDPAz5Fdqb/8RKTXQzRK1/9HW7v
cWl08dyoZMBrqBT8e3dN0kJBFfwQhJ+beLtksWwi5MF9ayWVKpFwFkqHgjjNfwoD
zvBoxynlY/CK6jcvrf3uiYlHElnolcFISZWWOeigxX5vg2u7/YoAdJFUpPmJLLlb
gNXTUl5BxKrFpfa75QIDAQABo4ICLTCCAikwDgYDVR0PAQH/BAQDAgWgMB0GA1Ud
JQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAMBgNVHRMBAf8EAjAAMB0GA1UdDgQW
BBQYRv3js0wlV0ZKONojeJQ0IzLzOTAfBgNVHSMEGDAWgBSoSmpjBH3duubRObem
RWXv86jsoTBwBggrBgEFBQcBAQRkMGIwLwYIKwYBBQUHMAGGI2h0dHA6Ly9vY3Nw
LmludC14My5sZXRzZW5jcnlwdC5vcmcvMC8GCCsGAQUFBzAChiNodHRwOi8vY2Vy
dC5pbnQteDMubGV0c2VuY3J5cHQub3JnLzA3BgNVHREEMDAughNjaHJpc3RpYW4t
Zm9saW5pLmNoghd3d3cuY2hyaXN0aWFuLWZvbGluaS5jaDCB/gYDVR0gBIH2MIHz
MAgGBmeBDAECATCB5gYLKwYBBAGC3xMBAQEwgdYwJgYIKwYBBQUHAgEWGmh0dHA6
Ly9jcHMubGV0c2VuY3J5cHQub3JnMIGrBggrBgEFBQcCAjCBngyBm1RoaXMgQ2Vy
dGlmaWNhdGUgbWF5IG9ubHkgYmUgcmVsaWVkIHVwb24gYnkgUmVseWluZyBQYXJ0
aWVzIGFuZCBvbmx5IGluIGFjY29yZGFuY2Ugd2l0aCB0aGUgQ2VydGlmaWNhdGUg
UG9saWN5IGZvdW5kIGF0IGh0dHBzOi8vbGV0c2VuY3J5cHQub3JnL3JlcG9zaXRv
cnkvMA0GCSqGSIb3DQEBCwUAA4IBAQBTEngQUhMprmyiLZQbNFoHJQ/gDufNu7bq
FO+Tdq0ZkqqfmrDPobkvloCvHV/fKitS/QW+IyGrDaAVwWJQjfrYVvWvc9aQcmx+
BRvbpm/Wt8vwib0Dc7LOpCpbqyduFr55n7V0dH512LXg0AxpCvHPCbKEvs1yGstF
lyXivh3/0kCLv9Yplc+mPbgQ0eszONQ1OSgnqMH4wh7lUsmyxkqhHZjqlAYvr16O
C6MFOvLpkuhjmrgzO4a5YFKgkEAwgLj6ShUiyzS/kV6bUX6Lp21MWR4spHDUzZuu
a1fOnvtDjO/Gp/S+Of00YUyEIeD7dE0xvUXDGliXx7sVvip0wHrd
-----END CERTIFICATE-----
```

Falls dieses Zertifikat unseren Vorstellungen entspricht, kopieren wir es gemeinsam mit dem Schlüssel auf den Server. Neben Zertifikat und Schlüssel müssen wir aber auch das Chain-File Mitübertragen. Worum geht es dabei? Der Webbrowser vertraut von Beginn weg einer Liste von Zertifizierungs-Authoritäten. Beim Aufbau der _SSL_-Verbindung wird dieses Vertrauen auf unseren Webserver erweitert. Zu diesem Zweck versucht der Browser von unserem Zertifikat in mehreren Schritten eine Vertrauenskette zu einer der ihm bekannten Zertifizierungsstellen herzustellen. Neben dem Serverzertifikat verläuft dieses Kette über mehrere signierte Zwischenzertifikate, die wir dem Browser in der Form des Chain-Files ausliefern. Das heisst, ein dem Browser bekanntes Root-Zertifikat hat das erste Element des Chain-Files signiert. Dieses Zertifikat wiederum wurde dazu verwendet, um das nächste Zertifikat in der Kettte zu signieren und das dann wieder für das nächste und so weiter, bis wir endlich zu unserem kürzlich erhaltenen Zertifikat gelangen. Lassen sich alle diese Zertifikate erfolgreich prüfen, dann ist die Vertrauenskette intakt und der Browser nimmt an, dass er mit dem gewünschten Server spricht. Dem Chain-File kommt als Bindeglied zwischen Certificate Authority und unserem Zertifikat als eine grosse Bedeutung zu. Deshalb hat `getssl` diese Datei auch gleich besorgt und neben Schlüssel und Zertifikat abgelegt. Nehmen wir also diese drei Dateien und kopieren wir sie auf den Server:

```bash
$> sudo cp ~/.getssl/christian-folini.ch/christian-folini.ch.key /etc/ssl/private/
$> sudo cp ~/.getssl/christian-folini.ch/christian-folini.ch.crt /etc/ssl/certs/
$> sudo cp ~/.getssl/christian-folini.ch/chain.crt /etc/ssl/certs/lets-encrypt-chain.crt
``` 

Wichtig ist, dass die Permissions korrekt eingestellt sind:

```bash
$> chmod 400 /etc/ssl/private/christian-folini.key
$> chown root:root /etc/ssl/private/christian-folini.key
$> chmod 644 /etc/ssl/certs/christian-folini.crt
$> chown root:root /etc/ssl/certs/christian-folini.crt
$> chmod 644 /etc/ssl/certs/christian-folini.crt
$> chown root:root /etc/ssl/certs/lets-encrypt-chain.crt
```

Danach tragen wir die neuen Pfade in der Konfiguration ein:

```bash
SSLCertificateKeyFile   /etc/ssl/private/christian-folini.ch.key
SSLCertificateFile      /etc/ssl/certs/christian-folini.ch.crt
SSLCertificateChainFile /etc/ssl/certs/lets-encrypt-chain.crt
```

Und nun bleibt noch der Start oder Neustart des Servers und wir haben ein offiziell signiertes Zertifikat komplett installiert.

FIXME: unterbringen:
Die Funktionsweise des _SSL-/TLS_-Protokolls ist anspruchsvoll. Eine gute Einführung bietet das _OpenSSL Cookbook_ von Ivan Ristić (siehe Links) oder sein umfassenderes Werk _Bulletproof SSL und TLS_. Ein Bereich, der schwer verständlich ist, umfasst die Vertrauensbeziehungen, die _SSL_ garantiert. 

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

