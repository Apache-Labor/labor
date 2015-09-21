##Konfigurieren eines minimalen Apache Servers

###Was machen wir?

Wir konfigurieren einen minimalen Apache Webserver und sprechen ihn mit curl, der TRACE-Methode und ab an.

###Warum tun wir das?

Ein sicherer Server ist ein Server, der nur soviel zulässt, wie wirklich benötigt wird. Idealerweise baut man einen Server also auf Basis eines minimalen Systems auf, indem man weitere Features nacheinander einzeln zuschaltet. Dies ist auch aus Verständnisgründen vorzuziehen, denn nur in diesem Fall versteht man, was wirklich konfiguriert ist.
Ferner ist es bei der Fehlersuche hilfreich, von einem minimalen System auszugehen. Ist der Fehler im minimalen System noch nicht vorhanden, werden die Features einzeln zugeschaltet und neu nach dem Fehler gesucht. Sobald er auftaucht, ist er bei der zuletzt zugeschalteten Konfigurationsdirektive isoliert.

###Voraussetzungen

Ein Apache Webserver, idealerweise mit einem File-Layout wie bei [Anleitung 1 (Kompilieren eines Apache Servers)](http://www.netnea.com/cms/apache_tutorial_1_apache_compilieren/) erstellt.

###Schritt 1: Minimale Konfiguration erstellen

Unser Webserver ist via /apache erreichbar. Unter /apache/conf/httpd.conf liegt seine Standard-Konfiguration. Diese ist sehr umfangreich und nur schwer zu verstehen. Ein Problem, das auch die Standard-Konfigurationen in den gängigen Linux-Distrubutionen mit sich bringen.
Wir ersetzen dieses Konfigurationsfile mit der folgenden einfachen Konfiguration.

```bash
ServerName            localhost
ServerAdmin           root@localhost
ServerRoot            /apache
User                  www-data
Group                 www-data
PidFile               /apache/logs/httpd.pid

ServerTokens          Prod
UseCanonicalName      On
TraceEnable           Off

Timeout               30
MaxClients            100

Listen                127.0.0.1:80

LoadModule            authz_host_module      modules/mod_authz_host.so
LoadModule            mime_module            modules/mod_mime.so
LoadModule            log_config_module      modules/mod_log_config.so

LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined

LogLevel              debug
ErrorLog              logs/error.log
CustomLog             logs/access.log combined

DefaultType           text/html

DocumentRoot          /apache/htdocs

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
```

###Schritt 2: Konfiguration verstehen

Gehen wir diese Konfiguration Schritt für Schritt durch.

Wir setzen den `ServerName` auf `Localhost`, weil wir immer noch an einem Laborsetup arbeiten. Für die Produktion ist hier der voll qualifizierte Hostname des Services einzutragen. Kurz: Umgangssprachlich die URL.

Der Server braucht vor allem für die Fehlerseiten eine Emailadresse des Administrators. Sie wird mit dem `ServerAdmin` gesetzt.

Das `ServerRoot` Verzeichnis bezeichnet das Haupt- oder Wurzelverzeichnis des Servers. Es ist der in Anleitung 1 als Kniff gesetzte Symlink. Dies kommt uns nun zu gute, denn durch Umlegen dieses Symlinks können wir nebeneinander verschieden kompilierte Apache Versionen ausprobieren, ohne an der Konfigurationsdatei etwas verändern zu müssen.

Dann weisen wir dem Server mit `User` und `Group` den Benutzer und dessen Gruppe zu. Dies ist sinnvoll, denn wir möchten vermeiden, dass der Server als Root-Prozess läuft. Vielmehr wird der Masterprozess als Root laufen, aber die eigentlichen Serverprozesse und deren Threads laufen unter dem hier gesetzten Namen. Der User `www-data` ist der unter einem Debian-/Ubuntu-System übliche Name. Andere Distributionen verwenden andere Namen. Bitte stellen Sie sicher, dass der von Ihnen gewählte Username und die zugehörige Gruppe auf dem System auch tatsächlich vorhanden ist.

Das `PidFile` gibt an, in welches File Apache seine Prozess-ID Nummer schreiben soll. Diese Zahl zu kennen, wird uns zukünftig zu pass kommen.

`ServerTokens` definiert die Selbstbezeichnung des Servers. Produktive Tokens werden mit `Prod` festgelegt. Dies bedeutet, dass sich der Server nur als `Apache` und nicht auch noch mit Versionsnummer und geladenen Modulen ausweist. Machen wir uns keine Illusionen: Die Serverversion lässt sich über das Internet mit wenig Aufwand feststellen, aber wir brauchen es ja trotzdem nicht gerade in die Welt hinauszuschreien.

`UseCanonicalName` teilt dem Server mit, welchen `Hostnamen` und welchen `Port` er verwenden soll, wenn er einen Link auf sich selbst zu schreiben hat. Mit dem Wert `On` bestimmen wir, dass der `ServerName` zu verwenden ist. Eine Alternative wäre es, den vom Client gesendeten Host-Header zu verwenden, was wir aber in unserem Setup nicht möchten.

Die `TraceEnable`-Direktive verhindert gewisse Spionageattacken auf unseren Setup. Die HTTP Methode `TRACE` instruiert den Webserver, die von ihm erhaltene Anfrage 1:1 zu retournieren. Dies erlaubt es festzustellen, ob ein Proxy-Server zwischengeschaltet ist und ob dieser den Request verändert hat. In unserem simplen Setup ist damit noch nichts verloren, aber in einem Unternehmensnetz möchte man diese Informationen lieber geheim halten. Schalten wir `TraceEnable` also sicherheitshalber per Default aus.

`Timeout` bezeichnet grob gesagt die Zeit in Sekunden, welche für die Verarbeitung eines Requests maximal verwendet werden darf. Tatsächlich verhält es sich damit etwas komplizierter, aber die Details brauchen uns für den Moment nicht zu interessieren. Der Standard-Wert ist mit 300 Sekunden sehr hoch. Wir reduzieren ihn auf 10 Sekunden.

`MaxClients` ist die maximale Anzahl Clients, welche parallel bedient werden. Korrekter ist die Erklärung, es sei die maximale Anzahl von Anfragen, die parallel verarbeitet werden. Der Standard-Wert ist wieder etwas hoch. Setzen wir ihn auf 100. Sollten wir diesen Wert in der Produktion erreichen, haben wir schon recht viel Verkehr.

Standardmässig hört der Apache Server auf jeder verfügbaren Adresse ins Netz. Für unsere Tests lassen wir ihn aber erst mal nur auf der `IPv4 Localhost` Adresse und auf dem Standard-HTTP-Port 80 lauschen. Mehrere `Listen`-Direktiven nacheinander sind problemlos möglich.

Nun laden wir drei Module:

* `authz_host_module` : Einfacher Zugriffsschutz
* `mime_module` : MIME Dateiformate
* `log_config_module` : Detaillierte Definition des Zugriffs-Logfiles

Wir hatten in der Lektion 1 ja alle mitgelieferten Module vorkompiliert. Hier nehmen wir nur zwei der wichtigsten in unsere Konfiguration auf. Das zweite Modul benützen wir auch gleich in der nächsten Anweisung:

Mit `LogFormat` definieren wir ein Format für das Zugriffs-Logfile. Wir nennen es `combined`. Dieses gängige Format schliesst Client-IP-Adresse, Zeitstempel, Methode, Pfad, HTTP-Version, HTTP-Status-Code, Antwort-Grösse, Referer und die Bezeichnung des Browsers (User-Agent) mit ein.

Den `LogLevel` für das Fehler-Logfile stellen wir mit `Debug` auf die höchste Stufe. Das ist für die Produktion zu gesprächig, im Labor macht das aber durchaus Sinn. Apache ist gemeinhin nicht sehr gesprächig, so dass man mit der Datenmenge meist gut zurecht kommt.

Dem Fehler-Logfile weisen wir mit `ErrorLog` den Pfad `logs/error.log` zu. Dieser Pfad ist relativ zum `ServerRoot`-Verzeichnis.

Das definierte `LogFormat combined` benützen wir nun für unser Zugriffs-Logfile namens `logs/access.log`.

Auf der nächsten Zeile halten wir fest, dass wir prinzipiell vor allem html-Dokumente, nämlich Dokumente mit dem `MIME-Type text/html`, ausliefern werden.

Der Webserver liefert Dateien aus. Diese sucht er auf einer Diskpartition, oder er generiert sie mit Hilfe einer installierten Applikation. Wir sind noch beim einfachen Fall und geben dem Server mittels `DocumentRoot bekannt`, wo er die Dateien findet. `/apache/htdocs` ist ein absoluter Pfad unter dem `ServerRoot`. Hier könnte auch wieder ein relativer Pfad stehen, aber arbeiten wir besser mit klaren Verhältnissen! Konkret bedeutet `DocumentRoot`, dass der URL-Pfad `/` auf `/apache/htdocs` gemappt wird.

Nun folgt ein `Directory-Block`. Mit diesem Block verhindern wir, dass Dateien ausserhalb des von uns bezeichneten `DocumentRoot` ausgeliefert werden. Für den Pfad / verbieten wir jeglichen Zugriff mittels der Direktive `Deny from all`. Auf der Zeile davor wird mittels Order angegeben, dass wir beim Definieren von Zugriffen zunächst Verbieten (Deny) und danach Erlauben (Allow) wollen. Dies entspricht dem Standard-Wert und wird hier nur der Klarheit wegen nochmals definiert.

Die Direktive `Options` setzen wir auf `SymLinksIfOwnerMatch`. Mit `Options` können wir festlegen welche Spezialfeatures beim Ausliefern des Verzeichnisses / beachtet werden sollen. Eigentlich gar keine und in der Produktion würden wir deshalb Options `None` schreiben. In unserem Fall haben wir aber das `DocumentRoot` auf einen symbolischen Link gelegt und der wird nur dann gesucht und auch gefunden, wenn wir den Server mit `SymLinksIfOwnerMatch` anweisen, unterhalb von / auch Symlinks zuzulassen. Zumindest wenn die Besitzverhältnisse sauber sind. Auf produktiven Systemen ist aus Sicherheitsgründen beim Servieren von Files besser auf Symlinks zu verzichten. Aber bei unserem Testsystem geht der Komfort noch vor.

`AllowOverride` teilt dem Server mit, dass er nicht auf sogenannte `.htaccess`-Dateien zu achten braucht, denn wir planen nicht, damit zu arbeiten. Diese Dateien sind vor allem für Webhoster und Shared-Hosting von Interesse. Dies trifft auf uns eher nicht zu.

Nun eröffnen wir einen `VirtualHost`. Er korrespondiert mit der oben definierten `Listen`-Direktive. Zusammen mit dem eben definierten `Directory`-Block legt er fest, dass unser Webserver per Default gar keinen Zugriff zulässt. Auf der IP-Adresse `127.0.0.1, Port 80` wollen wir aber Zugriffe zulassen und die werden innerhalb dieses Blocks definiert.

Konkret lassen wir Zugriffe auf unser `DocumentRoot` zu. Schlüsselanweisung ist hier das `Allow from all`. Anders als oben sind ab diesem Pfad nun keine Symlinks mehr vorgesehen und auch sonst keine Spezialfähigkeiten: `Options None`.

###Schritt 3: Server starten

Damit ist unser minimaler Server beschrieben. Es wäre möglich, einen noch knapperen Server zu definieren. Aber damit liesse sich nicht mehr so komfortabel arbeiten wie mit unserem und er wäre auch nicht mehr sicher. Eine gewisse Grundsicherung ist aber angebracht. Denn wenn wir nun im Labor einen Service aufbauen, dann sollte der sich auch in eine produktive Umgebung verschieben lassen. Einen Service kurz vor der Produktivschaltung noch von Grund auf sichern zu wollen ist illusorisch.

Starten wir den Server wieder wie in Lektion 1 im Vordergrund und nicht als Daemon:

```bash
$> cd /apache
$> sudo ./bin/httpd -X
```

###Schritt 4: Server mit Curl ansprechen

Wir können den Server nun wieder mit dem Browser ansprechen. Aber aus der Shell heraus lässt es sich erst mal sauberer arbeiten und besser verstehen, was passiert:

```bash
$> curl http://localhost/index.html
```

Dies liefert folgendes Resultat.

```bash
<html><body><h1>It works!</h1></body></html>$>
```

Etwas verwirrend ist es für mich, dass der Antwort der Zeilenumbruch fehlt. Das Cursor-Prompt schliesst sich also an die Antwort an.

###Schritt 5: Anfrage und Antwort untersuchen

Das passiert also bei einer HTTP-Anfrage. Aber was antwortet der Server uns eigentlich genau? Dazu rufen wir `curl` nochmals auf. Dieses Mal mit der Option verbose.

```bash
$> curl --verbose http://localhost/index.html
* About to connect() to localhost port 80 (#0)
*   Trying ::1... Connection refused
*   Trying 127.0.0.1... connected
* Connected to localhost (127.0.0.1) port 80 (#0)
> GET /index.html HTTP/1.1
> User-Agent: curl/7.22.0 (x86_64-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3
> Host: localhost
> Accept: */*
> 
< HTTP/1.1 200 OK
< Date: Tue, 02 Jul 2013 08:32:00 GMT
< Server: Apache
< Last-Modified: Tue, 02 Jul 2013 07:11:36 GMT
< ETag: "282f66-2c-4e0820e3b9a00"
< Accept-Ranges: bytes
< Content-Length: 44
< Content-Type: text/html
< 
* Connection #0 to host localhost left intact
* Closing connection #0

<html><body><h1>It works!</h1></body></html>$>
```

Die mit einem * bezeichneten Zeilen beschreiben den Aufbau und den Abbau der Verbindung: Zunächst erfolglos über `IPv6`, dann erfolgreich über `IPv4`. Dann folgt mit > die Anfrage und mit < die Antwort.

Konrekt besteht eine HTTP-Anfrage aus 4 Teilen:

* Request-Zeile und Request-Header
* Request-Body (optional und hier bei einem GET-Request fehlend)
* Response-Header
* Response-Body

Die ersten Teile brauchen hier noch nicht zu interessieren. Interessant sind die `Response-Header`. Das ist der Teil, mit dem der Webserver die Antwort beschreibt. Die eigentliche Antwort, der `Response-Body`, folgt dann nach einer Leerzeile und nachdem curl mitgeteilt hat, dass die Verbindung nun beendet sei.

Was sagen die Header nacheinander?

Zunächst folgt die `Status`-Zeile mit dem `Protokoll` und dem `Status-Code`. `200 OK` ist die normale Antwort eines Webservers. Danach das Datum und die Uhrzeit des Servers. Dann folgt die `Server`-Zeile, auf der sich unser Webserver als Apache identifiziert. Dies ist die knappste mögliche Identifikation. Wir haben sie mit ServerTokens Prod definiert.

Dann teilt der Server mit, wann das der Antwort zu Grunde liegende File zum letzten Mal verändert wurde; also die `Unix Modified-Timestamp`. `ETag` und `Accept`-Ranges brauchen für den Moment nicht zu interessieren. Interessanter ist die `Content-Length`. Diese gibt an, wieviele Bytes im `Response-Body` erwartet werden dürfen. In unserem Fall sind das 44 Bytes. Es folgt zum Schluss der `Content-Type` mit dem einem Browser mitgeteilt wird, was für eine Art von Inhalt er erwarten darf. Hier wird eine Antwort im `Mime-Format text/plain` in Aussicht gestellt. Das ist tatsächlich aber nicht ganz korrekt, denn unser `index.html` ist vielmehr vom Typ `text/html`. Wir könnten dem mit einer `Direktive DefaultType text/html` abhelfen, oder indem wir das Mime-Modul konfigurieren. Aber wir wollten ja einen möglichst einfachen Server und deshalb können wir mit so einer kleinen Ungenauigkeit leben. Zumal die Browser an diesen Fehler gewöhnt sind und tolerant reagieren.

Übrigens ist die Reihenfolge dieser Header charakteristisch für einen Webserver. Der Microsoft IIS verwendet eine andere Reihenfolge. Apache lässt sich deshalb auch identifizieren, wenn die Server-Zeile uns in die Irre führen sollte.

###Schritt 6: Mit Trace Methode arbeiten

Oben habe ich die Direktive `TraceEnable` beschrieben. Wir haben sie sicherheitshalber auf `off` geschaltet. Bei der Fehlersuche kann sie aber ganz nützlich sein. Also probieren wir das doch mal aus. Setzen wir die Option auf on:

```bash
TraceEnable On
```

Wir starten den Server neu und setzen folgenden curl-request ab.

```bash
$> curl -v --request TRACE http://localhost/index.html
```

Wir rufen also die bekannte `URL` mit der `HTTP Methode TRACE` (anstatt `GET`) auf. Als Resultat erwarten wir folgendes:

```bash
* About to connect() to localhost port 80 (#0)
*   Trying ::1... Connection refused
*   Trying 127.0.0.1... connected
* Connected to localhost (127.0.0.1) port 80 (#0)
> TRACE /index.html HTTP/1.1
> User-Agent: curl/7.22.0 (x86_64-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3
> Host: localhost
> Accept: */*
> 
< HTTP/1.1 200 OK
< Date: Tue, 02 Jul 2013 08:34:20 GMT
< Server: Apache
< Transfer-Encoding: chunked
< Content-Type: message/http

TRACE /index.html HTTP/1.1
User-Agent: curl/7.22.0 (x86_64-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3
Host: localhost
Accept: */*

* Connection #0 to host localhost left intact
* Closing connection #0
```

Im `Body` wiederholt der Server wie vorgesehen die Informationen zum gesendeten Request. Tatsächlich sind die Zeilen hier identisch. Wir können also bestätigen, dass unterwegs nichts mit der Anfrage passiert ist. Wenn wir aber über einen oder mehrere Proxy-Server gegangen wären, dann gäbe es hier auf jeden Fall weitere `Header`-Zeilen, die wir so auch als `Client` zu Gesicht bekommen können. Zu einem späteren Zeitpunkt werden wir mächtigere Hilfsmittel für die Fehlersuche kennen lernen. Aber ganz ausser Acht lassen sollten wir die `TRACE`-Methode dennoch nicht.

Vergessen Sie nicht, `TraceEnable` wieder auszuschalten.

###Schritt 7: Server mit "ab" auf den Zahn fühlen

Das wär's erst Mal mit dem simplen Server. Spasseshalber können wir ihm aber noch etwas auf den Zahn fühlen. Wir inszenieren einen kleinen Lasttest mit `ab`; kurz für `Apache Bench`. Dies ist ein sehr einfaches Lasttest-Programm, das immer zur Hand ist und rasche erste Resultate zur Performance liefern kann. So lasse ich ab gerne vor und nach einer Konfigurationsänderung laufen, um eine Idee zu erhalten, ob sich an der Performance etwas verändert hat. `Ab` ist nicht sehr mächtig und der lokale Aufruf bringt auch keine sauberen Resultate. Aber so ein erster Augenscheint lässt sich mit diesem Hilfsmittel gewinnen.

```bash
$> ./bin/ab -c 1 -n 1000 http://localhost/index.html
```

Wir starten ab mit `concurrency 1`. Das heisst, dass wir parallel nur eine einzige Anfrage stellen. Total stellen wir 1000 Anfragen auf die bekannte `URL`. Hier ist die Ausgabe von `ab`:

```bash
This is ApacheBench, Version 2.3 <$Revision: 655654 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
Licensed to The Apache Software Foundation, http://www.apache.org/

Benchmarking localhost (be patient)
Completed 100 requests
Completed 200 requests
Completed 300 requests
Completed 400 requests
Completed 500 requests
Completed 600 requests
Completed 700 requests
Completed 800 requests
Completed 900 requests
Completed 1000 requests
Finished 1000 requests


Server Software:        Apache
Server Hostname:        localhost
Server Port:            80

Document Path:          /index.html
Document Length:        44 bytes

Concurrency Level:      1
Time taken for tests:   0.957 seconds
Complete requests:      1000
Failed requests:        0
Write errors:           0
Total transferred:      327000 bytes
HTML transferred:       44000 bytes
Requests per second:    1045.34 [#/sec] (mean)
Time per request:       0.957 [ms] (mean)
Time per request:       0.957 [ms] (mean, across all concurrent requests)
Transfer rate:          286.86 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    0   0.0      0       0
Processing:     0    1   0.3      1       4
Waiting:        0    0   0.2      0       2
Total:          1    1   0.3      1       4

Percentage of the requests served within a certain time (ms)
  50%      1
  66%      1
  75%      1
  80%      1
  90%      1
  95%      1
  98%      2
  99%      2
 100%      4 (longest request)
```

Interessant ist für uns vor allem die Zahl der Fehler (`Failed Requests`) und die Zahl der Anfragen pro Sekunde (`Request per second`). Ein Wert von über tausend ist ein guter Start. Zumal wir ja immer noch mit einem einzigen Prozess und nicht mit einem parallelisierten Daemon arbeiten (und deshalb auch der `concurrency-level` auf 1 gesetzt ist).

Soweit zu diesem Tutorial. Damit ist bereits ein tauglicher Webserver vorhanden mit dem man gut arbeiten kann. In den nächsten Lektionen arbeiten wir weiter daran.

###Verweise

* Apache: http://httpd.apache.org
* Apache Direktiven: http://httpd.apache.org/docs/current/mod/directives.html
* HTTP Header: http://en.wikipedia.org/wiki/List_of_HTTP_header_fields (Englisch)
* RFC 2616 (HTTP Protokoll): http://www.ietf.org/rfc/rfc2616.txt (Englisch)



