##Konfigurieren eines SSL Servers

###Was machen wir?
Wir setzen einen mit Serverzertifikat gesicherten Apache Webserver auf.

###Warum tun wir das?

Das HTTP Protokoll ist ein Protokoll, das sich sehr gut abhören lässt. Die Erweiterung HTTPS umgibt den HTTP-Verkehr in einer SSL-Schutzschicht,
welche das Abhören verhindert und sicherstellt, dass wir wirklich mit demjenigen Server sprechen, den wir angesprochen haben. Die Übertragung der Daten geschieht dann nur noch verschlüsselt. Das bedeutet noch keinen sicheren Webserver,
aber es ist die Basis für jeglichen gesicherten HTTP-Betrieb.

###Voraussetzungen

* Ein Apache Webserver, idealerweise mit einem File-Layout wie bei FIXME: <a href="?q=apache_tutorial_1_apache_compilieren">Lektion 1 (Compilieren eines Apache Servers)</a>, erstellt.
* Verständnis der minimalen Konfiguration in FIXME: <a href="?q=apache_tutorial_2_apache_minimal_konfigurieren">Lektion 2 (Apache minimal Konfigurieren)</a>.


###Schritt 1: Apache mit SSL compilieren

Zwar haben wir in Lektion 1 einen Apache Server mit möglichst vielen Modulen compiliert. Aber das _ssl_-Modul
war dennoch nicht dabei. Wir müssen das nun nachholen. Zunächst fehlt uns das nötige _ssl-Enwicklungspaket_, dann compilieren wir neu.

```bash
$> sudo apt-get install libssl-dev
$> cd /usr/src/apache/httpd-2.2.25
$> ./configure --prefix=/opt/apache-2.2.25 --with-mpm=worker --enable-mods-shared="all ssl" --with-included-apr &&
make && sudo make install
```

Zum bekannten _configure_ ist beim Parameter _enable-mods-shared_ neben dem _all_ noch das Modul _ssl_
dazugekommen. Die beschränkte Wirkung von _all_ ist nicht ganz logisch, aber lassen wir uns davon nicht aufhalten.

Nach der erfolgreichen Konfiguration wird obenstehende Befehlszeile den Compiler
aufrufen und nach dessen erfolgreichem Abschluss den neu-compilierten Server
installieren.

###Schritt 2: SSL Schlüssel und Zertifikat beziehen

HTTPS ist das bekannte HTTP Protokoll um eine SSL-Schicht erweitert. Technisch wurde SSL (_Secure Socket Layer_) zwar heute von TLS (_Transport Security Layer_) ersetzt, aber man spricht dennoch immer noch von SSL. Das Protokoll garantiert verschlüsselten und damit abhörsicheren Datenverkehr. Der Verkehr wird symmetrisch verschlüsselt, was einen hohen Durchsatz garantiert, setzt aber im Fall von HTTPS einen Public-/Private-Key Setup voraus, der den sicheren Austausch der symmetrischen Schlüssel durch sich zuvor unbekannte Kommunikationspartner voraus. Dieser Public-/Private-Key Setup geschieht durch ein Serverzertifikat, das durch eine offizielle Stelle signiert werden muss.

Serverzertifikate existieren in verschiedenen Formen, Validierungen und Gültigkeitsbereichen. Nicht jedes Merkmal ist wirklich technischer Natur, das Marketing spielt auch eine Rolle. Die Preisunterschiede sind sehr gross, weshalb sich ein Vergleich lohnt (FIXME: <a href="http://en.wikipedia.org/wiki/Comparison_of_SSL_certificates_for_web_servers">Wikipedia</a>). Für unseren Test-Setup verwenden wir ein freies Zertifikat, das wir aber dennoch offiziell beglaubigen lassen. Bei FIXME: <a href="https://www.startssl.com">_StartSSL_</a> lässt sich beides einfach und ohne Bezahlung mit einer Laufzeit von 12 Monaten beziehen. Dieses Zertifikat ist an sich auch für einen sicheren Einsatz auf einem produktiven Server geeignet, allerdings bringt es nicht die erweiterte Validierung mit, welche im Browser durch das grüne Hinterlegen der Adresszeile hervorgehoben wird. Übrigens hat diese Hintergrundfarbe keinen technischen Sicherheitsvorteil. Aber die sorgfältigere Ausgabe der Zertifikate und die Gewöhnung der Benutzer lassen diese erweiterten Zertifikate dennoch als gute, wenn auch etwas kostspieligere Investition erscheinen.

_StartSSL_ überprüft zunächst die Identität eines Antragsstellers und dann vor der Ausstellung des Zertifikats auch noch dessen Berechtigung ein bestimmtes Zertifikat für eine bestimmte Domain zu erhalten. Diese Überprüfung geschieht durch ein Email an eine vordefinierte Adresse der gewünschten Zertifikats-Domäne. Konkret bedeutet dies im Fall der Domäne _example.com_, dass _StartSSL_ eine Email-Nachricht mit einem Sicherheitscode an eine der drei Adressen _postmaster@example.com_, _webmaster@example.com_ oder _hostmaster@example.com_ versendet. Dies verhindert, dass jemand ein Zertifikat für eine fremde Domäne beziehen kann, denn in diesem Fall ginge die Nachricht mit dem Code in die Leere.

Zur Zeit (Januar 2011) kommt man über die folgenden Schritte zu einem Server-Zertifikat:

* Registrieren
* Persönliche Email-Adresse überprüfen
* Zertifikats-Erstellung starten
* Berechtigung für Domäne überprüfen
* Zertifikats-Erstellung abschliessen
* Zertifikat signieren


Es ist durchaus üblich, ein Zertifikat selbst zu erstellen und es dann online nur noch signieren zu lassen. _StartSSL_ lässt diese flexible Option auch zu. Allerdings ist die Möglichkeit auch das Zertifikat selbst online erstellen zu lassen sehr hilfreich. Wichtig ist in beiden Varianten, dass man den Schlüssel durch ein starkes Passwort schützt. Dieses Passwort benötigen wir später bei der Konfiguration des Servers.

###Schritt 2b: Zertifikat selbst erstellen und offiziell signieren lassen

Bei _StartSSL_ lassen sich auch Zertifikate zu selbst erstellen Schlüsseln signieren. Dies bietet einem zusätzliche Möglichkeiten beim Design des Zertifikats. Wenn man also ein Super Zertifikat möchte, eines das in der Sonne einen solchen speziellen Glanz versprüht, dann ist dies ein guter Weg. Einen sehr guten Schlüssel generieren wir wie folgt:

```bash
$> openssl genrsa -des3 -out server.key 2048
```

Die Generierung des Schlüssels dürfte einen Moment in Anspruch nehmen, denn eine Länge von 2048 wie angegeben ist ziemlich gross und die notwendige Entropie muss erst gefunden werden. Es wäre auch möglich, mit einer Länge von 496 zu arbeiten, aber der geringe cryptographische Mehrwert wird durch eine mehrfach schlechtere Performance erkauft. Wir erwarten folgenden Ablauf des Aufrufs:
 
```bash
Generating RSA private key, 2048 bit long modulus
.+++++++++++++++++++++++++++...
...
e is 65537 (0x10001)
Enter pass phrase for server.key:
Verifying - Enter pass phrase for server.key:
```

Merken Sie sich diese Passphrase gut.  Mit dem neuen Schlüssel generieren wir nun einen Signierungsantrag, einen _Certificate Signing Request_, kurz _CSR_:

```bash
$> openssl req -new -key server.key > server.csr
```

Hier werden ein paar weitere Fragen gestellt, die wir gewissenhaft beantworten:

```bash
Enter pass phrase for server.key:
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:CH
State or Province Name (full name) [Some-State]:Bern
Locality Name (eg, city) []:Bern
Organization Name (eg, company) [Internet Widgits Pty Ltd]:example.com
Organizational Unit Name (eg, section) []:-
Common Name (eg, YOUR name) []:Christian Folini
Email Address []:webmaster@example.com

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:sjk3hrer8jk   
An optional company name []:sjk3hrer8jk
```

Wir erhalten darauf einen _CSR_ mit Namen server.csr. Damit gehen wir zu _StartSSL_ und lassen ihn signieren.


###Schritt 3: Zertifikat für die Vertrauenskette beziehen

Ich setze voraus, dass Sie ein offiziell signiertes Zertifikat mit zugehörigem Schlüssel wie beschrieben bezogen oder selbst generiert und offiziell signiert haben.



Die Funktionsweise des _SSL/TLS_-Protokolls ist anspruchsvoll. Eine gute Einführung bietet das erste Kapitel des Buches FIXME: <a href="http://oreilly.com/catalog/9780596002701">_Network Security with OpenSSL_</a> aus dem _O'Reilly_-Verlag. Das Buch ist zwar nicht mehr neu, aber das Einführungskapitel liefert nach wie vor einen hervorragenden Einstieg in das Thema. Ein Bereich, der schwer verständlich ist, umfasst die Vertrauensbeziehungen, die _SSL_ garantiert. Der Webbrowser vertraut von Beginn weg einer Liste von Zertifizierungs-Authoritäten, wozu auch _StartSSL_ gehört. Beim Aufbau der _SSL_-Verbindung wird dieses Vertrauen auf unseren Webserver erweitert. Dies geschieht mit Hilfe des Zertifikates. Es wird eine Vertrauenskette zwischen der Zertifizierungs-Authorität und unserem Server gebildet. Aus technischen Gründen gibt es ein Zwischenglied zwischen der Zertifizierungs-Authorität und unserem Webserver. Dieses Glied müssen wir auch definieren. Diese geschieht mittels weiterer Zertifikats-Dateien, die wir einzeln beziehen.

```bash
$> wget https://www.startssl.com/certs/sub.class1.server.ca.pem -O startssl-class1-chain-ca.pem
```

Ich wähle hier einen etwas andere Datei-Namen als vorgegeben. Wir gewinnen dadurch an Klarheit.

###Schritt 4: SSL Schlüssel und Zertifikate installieren

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
$> mv startssl-class1-chain-ca.pem /apache/conf/ssl.crt
```

###Schritt 5: Passphrase Dialog automatisch beantworten

Beim Beziehen des Schlüssels mussten wir ein Passwort definieren. Damit unser Webserver den Schlüssel benutzen kann müssen wir ihm dieses Passwort
bekannt geben. Er wird uns beim Starten des Servers danach fragen. Möchten wir das nicht, dann müssen wir es in der Konfiguration mit angeben. 
Wir tun dies mittels einer separaten Datei, die auf Anfrage das Passwort liefert. Nennen wir diese Datei _/apache/bin/gen_passphrase.sh_:

```bash
#!/bin/sh
echo "S7rh29Hj3def-07h"
```

Diese Datei muss speziell gesichert und vor fremden Augen geschützt werden.

```bash
$> sudo chmod 700 /apache/bin/gen_passphrase.sh
$> sudo chown root:root /apache/bin/gen_passphrase.sh
```

###Schritt 6: Apache konfigurieren

Nun sind alle Vorbereitungen abgeschlossen und wir können den Webserver konfigurieren.

```bash
ServerName		www.exmaple.com
ServerAdmin		webmaster@example.com
ServerRoot		/apache
User			www-data
Group			www-data
PidFile			/apache/logs/httpd.pid

ServerTokens		Prod
UseCanonicalName	On
TraceEnable		Off

Timeout			30
MaxClients		100

Listen			127.0.0.1:80
Listen			127.0.0.1:443

LoadModule		authz_host_module	modules/mod_authz_host.so
LoadModule		mime_module  		modules/mod_mime.so
LoadModule		log_config_module	modules/mod_log_config.so
LoadModule		ssl_module		modules/mod_ssl.so

LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined

LogLevel		debug
ErrorLog		logs/error.log
CustomLog		logs/access.log combined

DefaultType		text/html

SSLCertificateKeyFile   conf/ssl.key/server.key
SSLCertificateFile      conf/ssl.crt/server.crt
SSLCertificateChainFile conf/ssl.crt/startssl-class1-chain-ca.pem
SSLPassPhraseDialog     exec:bin/gen_passphrase.sh
SSLProtocol             -All +TLSv1
SSLCipherSuite		AES256-SHA

SSLSessionCache         shm:logs/ssl_scache(1024000)

SSLMutex                file:logs/ssl_mutex
SSLRandomSeed           startup file:/dev/urandom 1024
SSLRandomSeed           connect builtin

DocumentRoot		/apache/htdocs

<Directory />
	Order Deny,Allow
	Deny from all

	Options SymLinksIfOwnerMatch
	AllowOverride None
</Directory>

<VirtualHost 127.0.0.1:80>
	
	<Directory /apache/htdocs>
		Order Deny,Allow
		Allow from all

		Options None
		AllowOverride None
	</Directory>

</VirtualHost>

<VirtualHost 127.0.0.1:443>
	
	SSLEngine On

	<Directory /apache/htdocs>
		Order Deny,Allow
		Allow from all

		Options None
		AllowOverride None
	</Directory>

</VirtualHost>
```

Ich beschreibe nicht die gesamte Konfiguration, nur die gegenüber Lektion 2 neu hinzugekommenen Direktiven. Neu lauschen wir neben dem Port 80 auch noch auf Port 443, dem _HTTPS-Port_. Wie erwartet ist das _SSL-_Modul neu hinzugeladen. . Dann konfigurieren wird den Schlüssel und die Zertifikate mittels der Direktiven _SSLCertificateKeyFile_, _SSLCertificateFile_ und _SSLCertificateChainFile_. Danach folgt der Passphrase-Dialog, der uns das Passwort zurückliefert (_SSLPassPhraseDialog_). In der Protokollzeile (_SSLProtocol_) ist es sehr wichtig, das wir das ältere und unsichere Protokoll _SSLv2_ ausschalten. Wir machen hier Nägel mit Köpfen und legen fest, dass nur TLSv1 in Frage kommt. Die Verschlüsselung geschieht durch einen Satz von mehreren Algorithmen. Diese kryptographischen Algorithmen definieren wir mit der sogenannten _Cipher-Suite_. Es ist wichtig, eine saubere _Cipher-Suite_ zu verwenden, den hier setzen Abhörangriffe typischerweise an: Sie nützen die Schwächen und die zu geringe Schlüssellänge älterer Algorithmen aus. Eine sehr eingeschränkte Suite verhindert allerdings, dass ältere Browser auf unseren Server zugreifen können. Die vorgeschlagene _Cipher-Suite_ umfasst nur noch einen einzigen sehr starken Cipher. Das ist für den Client sehr anspruchsvoll. Sollte die _Cipher-Suite_ in der Praxis Probleme machen, so wäre folgender Vorschlag eine etwas laxere Alternative, die immer noch sehr sicher ist: _aNULL:!eNULL:!LOW:!EXP:AES:3DES:RC4:!ADH:!MD5_.

Im folgenden Definieren wir einen _SSL-Session Cache_ im _Shared Memory_ des Servers (_SSLSessionCache_). Dies garantiert, dass mehrere parallel laufende Requests eines Clients nur einen einzigen _SSL-Handshake_ durchführen müssen und sich ansonsten die Session teilen. Dieses Verhalten ist aus Performance-Gründen anzustreben. Wir konfigurieren dann ein _Mutex-File_, um Kollisionen zu verhindern und legen fest, wie die Zufallszahlen erzeugt werden sollen. Dies ist wieder ein Punkt wo Performance und Sicherheit bedacht werden wollen. Beim Starten des Servers greifen wir auf die Zufallszahlen des Betriebssystems in _/dev/urandom_ zu. Während des Betriebs des Servers, beim _SSL-Handshake_ verwenden wir dann die apache-eigene Quelle für Zufallszahlen. Zwar ist _/dev/urandom_ nicht die allerbeste Quelle für Zufallszahlen, aber es ist eine schnelle Quelle und zudem eine, die eine bestimmte Menge Entropie garantiert. Die qualitativ bessere Quelle _/dev/random_ könnte unseren Server unter widrigen Umständen beim Start blockieren, da nicht genügend Zufallszahlen vorhanden sind.

Wir haben auch noch einen zweiten _Virtual-Host_ eingeführt. Er gleicht dem _Virtual-Host_ für Port 80 sehr stark. Die Portnummer ist allerdings anders und wir aktivieren die _SSL-Engine_.

###Schritt 7: Ausprobieren

Zu Übungszwecken haben wir unseren Testserver erneut auf der lokalen IP-Adresse _127.0.0.1_ konfiguriert. Um das Funktionieren der Zertifikatskette zu testen dürfen wir den Server nicht einfach mittels der IP-Adresse ansprechen, sondern wir müssen ihn mit dem korrekten Hostnamen kontaktieren. Und dieser Hostname muss natürlich mit demjenigen auf dem Zertifikat übereinstimmen. Im Fall von _127.0.0.1_ erreichen wir dies, idem wir das _Host-File_ unter _/etc/hosts_ anpassen:

```bash
127.0.0.1	localhost myhost www.example.com
...
```

Nun können wir entweder mit dem Browser, oder mit curl auf die URL FIXME: <a href="https://www.example.com">https://www.example.com</a> zugreifen. Wenn dies ohne eine Zertifikats-Warnung funktioniert, dann haben wir den Server korrekt konfiguriert. Etwas genauer lässt sich die Verschlüsselung und die Vertrauenskette mit dem Kommendozeilen-Tool _OpenSSL_ überprüfen. Da _OpenSSL_ aber anders als der Browser und curl keine Liste mit Zertifikatsauthoritäten besitzt müssen wir dem Tool das Zertifikat der Authorität auch mitgeben. Wir besorgen es uns bei _StartSSL_.

```bash
$> wget https://www.startssl.com/certs/ca.pem
...
$> openssl s_client -showcerts -CAfile ca.pem -connect www.example.com:443
```

Wir instruieren _OpenSSL_, den eingebauten client zu verwenden, uns die vollen Zertifikatsinformationen zu zeigen, das eben heruntergeladene CA-Zertifikat zu verwenden und mit diesen Parametern auf unseren Server zuzugreifen. Im optimalen Fall sieht der Output (leicht gekürzt) wie folgt aus:

```bash
CONNECTED(00000003)
---
Certificate chain
 0 s:/description=329817-gqai4gyx3JMxBbCV/C=CH/O=Persona Not Validated/OU=StartCom Free Certificate ...
   i:/C=IL/O=StartCom Ltd./OU=Secure Digital Certificate Signing/CN=StartCom Class 1 Primary ...
-----BEGIN CERTIFICATE-----
MIIHtDCCBpygAwIBAgIDArSFMA0GCSqGSIb3DQEBBQUAMIGMMQswCQYDVQQGEwJJ
...
...
...
x94JRF4camVVVDe3ae7TXZ/xl/Y8vR7TMbZJx4vg33IjnmLS6FOlf97BP6wA7wZN
zZnCQe+3NTU=
-----END CERTIFICATE-----
 1 s:/C=IL/O=StartCom Ltd./OU=Secure Digital Certificate Signing/CN=StartCom Class 1 Primary ...
   i:/C=IL/O=StartCom Ltd./OU=Secure Digital Certificate Signing/CN=StartCom Certification ...
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
    Master-Key: 1BF16E22B0DF086E1AF4E13D9158AC0A3B1039E334C0C7F177A8757694B516E00E20AC3D6250B10D...
    Key-Arg   : None
    Start Time: 1294591828
    Timeout   : 300 (sec)
    Verify return code: 0 (ok)
---
```

Damit haben wir einen sauberen _HTTPS-Server_ konfiguriert. Interessanterweise gibt es im Internet so etwas wie eine Hitparade, was sichere _HTTPS-Server_ betrifft. Das sehen wir uns nun noch als Bonus an.


###Schritt 8 (Bonus): Qualität der SSL Sicherung extern überprüfen lassen

Ivan Ristic, der Autor von _Apache Security_ betreibt im Netz einen Analyse-Service zur Konfiguration von _SSL-Webservern_. Er befindet sich bei FIXME: <a href="https://www.ssllabs.com/ssldb/index.html">www.ssllabs.com</a>. Ein Webserver wie oben konfiguriert und mit einem Gratis-Zertifikat von StartSSL brachte mir im Test einen Score on 97 ein. Das ist zur Zeit (Januar 2011) die Topposition und das höchste, was man mit Apache erreichen kann.

FIXME: <img src="files/ssllabs-com.png"><br/>
<span class="caption">So weit kann man mit einem sorgfältig konfigurierten Apache ungefähr gelangen.</span>

###Verweise

* FIXME: <a href="http://de.wikipedia.org/wiki/Openssl">Wikipedia OpenSSL</a>
* FIXME: <a href="http://httpd.apache.org/docs/2.2/mod/mod_ssl.html">Apache Mod_SSL</a>
* FIXME: <a href="https://www.startssl.com">StartSSL Zertifikate</a>
* FIXME: <a href="https://www.ssllabs.com">SSLLabs</a>
* FIXME: <a href="http://oreilly.com/catalog/9780596002701">O'Reilly Buch: OpenSSL</a>
* FIXME: <a href="http://www.keylength.com">Keylength.com - Hintergrundinformationen zu Ciphers und Keys</a>


