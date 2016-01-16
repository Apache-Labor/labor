##Konfigurieren eines minimalen Apache Servers

###Was machen wir?

Wir konfigurieren einen minimalen Apache Webserver und sprechen ihn mit curl, der TRACE-Methode und ab an.

###Warum tun wir das?

Ein sicherer Server ist ein Server, der nur soviel zulässt, wie wirklich benötigt wird. Idealerweise baut man einen Server also auf Basis eines minimalen Systems auf, indem man weitere Features nacheinander einzeln zuschaltet. Dies ist auch aus Verständnisgründen vorzuziehen, denn nur in diesem Fall versteht man, was wirklich konfiguriert ist.
Ferner ist es bei der Fehlersuche hilfreich, von einem minimalen System auszugehen. Ist der Fehler im minimalen System noch nicht vorhanden, werden die Features einzeln zugeschaltet und neu nach dem Fehler gesucht. Sobald er auftaucht, ist er bei der zuletzt zugeschalteten Konfigurationsdirektive isoliert.

###Voraussetzungen

* Ein Apache Webserver, idealerweise mit einem File-Layout wie bei [Anleitung 1 (Kompilieren eines Apache Servers)](http://www.netnea.com/cms/apache_tutorial_1_apache_compilieren/) erstellt.

###Schritt 1: Minimale Konfiguration erstellen

Unser Webserver ist auf dem Dateisystem unter `/apache` abgelegt. Unter `/apache/conf/httpd.conf` liegt seine Standard-Konfiguration. Diese ist sehr umfangreich und nur schwer zu verstehen. Ein Problem, das auch die Standard-Konfigurationen in den gängigen Linux-Distrubutionen im nochmals verstärkten Mass mit sich bringen.
Wir ersetzen diese Konfigurationsdatei mit der folgenden stark vereinfachten Konfiguration.

```bash
ServerName              localhost
ServerAdmin             root@localhost
ServerRoot              /apache
User                    www-data
Group                   www-data
PidFile                 logs/httpd.pid

ServerTokens            Prod
UseCanonicalName        On
TraceEnable             Off

Timeout                 10
MaxRequestWorkers       100

Listen                  127.0.0.1:80

LoadModule              mpm_event_module        modules/mod_mpm_event.so
LoadModule              unixd_module            modules/mod_unixd.so

LoadModule              log_config_module       modules/mod_log_config.so

LoadModule              authn_core_module       modules/mod_authn_core.so
LoadModule              authz_core_module       modules/mod_authz_core.so

ErrorLogFormat          "[%{cu}t] [%-m:%-l] %-a %-L %M"
LogFormat               "%h %l %u [%{%Y-%m-%d %H:%M:%S}t.%{usec_frac}t] \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined

LogLevel                debug
ErrorLog                logs/error.log
CustomLog               logs/access.log combined

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
```

###Schritt 2: Konfiguration verstehen

Gehen wir diese Konfiguration Schritt für Schritt durch.

Wir setzen den _ServerName_ auf _Localhost_, weil wir immer noch an einem Laborsetup arbeiten. Für die Produktion ist hier der voll qualifizierte Hostname des Services einzutragen. Kurz: Umgangssprachlich die URL.

Der Server benötigt vor allem für die Darstellung der Fehlerseiten eine Emailadresse des Administrators. Sie wird mit dem _ServerAdmin_ gesetzt.

Das _ServerRoot_ Verzeichnis bezeichnet das Haupt- oder Wurzelverzeichnis des Servers. Es ist der in Anleitung 1 als Kniff gesetzte Symlink. Dies kommt uns nun zugute, denn durch Umlegen dieses Symlinks können wir nebeneinander verschieden kompilierte Apache-Versionen ausprobieren, ohne an der Konfigurationsdatei etwas verändern zu müssen.

Dann weisen wir dem Server mit _User_ und _Group_ den Benutzer und dessen Gruppe zu. Dies ist sinnvoll, denn wir möchten vermeiden, dass der Server als Root-Prozess läuft. Vielmehr wird der Master- bzw. Parent-Prozess als Root laufen, aber die eigentlichen Server- bzw. Child-Prozesse und deren Threads laufen unter dem hier gesetzten Namen. Der User _www-data_ ist der unter einem Debian-/Ubuntu-System übliche Name. Andere Distributionen verwenden andere Namen. Bitte stellen Sie sicher, dass der von Ihnen gewählte Username und die zugehörige Gruppe auf dem System auch tatsächlich vorhanden ist.

Das _PidFile_ gibt an, in welches File Apache seine Prozess-ID Nummer schreiben soll. Der gewählte Pfad entspricht dem Defaultwert. Er wird hier angeführt, damit man später nicht in der Dokumentation nach diesem Pfad zu suchen braucht.

_ServerTokens_ definiert die Selbstbezeichnung des Servers. Produktive Tokens werden mit _Prod_ festgelegt. Dies bedeutet, dass sich der Server nur als _Apache_ und nicht auch noch mit Versionsnummer und geladenen Modulen ausweist und sich damit etwas diskreter gibt. Machen wir uns keine Illusionen: Die Serverversion lässt sich über das Internet mit wenig Aufwand feststellen, aber wir brauchen es ja trotzdem nicht gerade bei jeder Kommunikation als Teil des Absenders mitzuschicken.

_UseCanonicalName_ teilt dem Server mit, welchen _Hostnamen_ und welchen _Port_ er verwenden soll, wenn er einen Link auf sich selbst zu schreiben hat. Mit dem Wert _On_ bestimmen wir, dass der _ServerName_ zu verwenden ist. Eine Alternative wäre es, den vom Client gesendeten Host-Header zu verwenden, was wir aber in unserem Setup nicht möchten.

Die _TraceEnable_-Direktive verhindert gewisse Spionageattacken auf unseren Setup. Die HTTP Methode _TRACE_ instruiert den Webserver, die von ihm erhaltene Anfrage 1:1 zu retournieren. Dies erlaubt es festzustellen, ob ein Proxy-Server zwischengeschaltet ist und ob dieser den Request verändert hat. In unserem simplen Setup ist damit noch nichts verloren, aber in einem Unternehmensnetz möchte man diese Informationen lieber geheim halten. Schalten wir _TraceEnable_ also sicherheitshalber per Default aus.

_Timeout_ bezeichnet grob gesagt die Zeit in Sekunden, welche für die Verarbeitung eines Requests maximal verwendet werden darf. Tatsächlich verhält es sich damit etwas komplizierter, aber die Details brauchen uns für den Moment nicht zu interessieren. Der Standard-Wert ist mit 60 Sekunden sehr hoch. Wir reduzieren ihn auf 10 Sekunden.

_MaxRequestWorkers_ ist die maximale Anzahl Threads, welche parallel an der Beantwortung von Anfragen arbeiten. Der Standard-Wert ist wieder etwas hoch. Setzen wir ihn auf 100. Sollten wir diesen Wert in der Produktion erreichen, haben wir schon recht viel Verkehr.

Standardmässig hört der Apache Server auf jeder verfügbaren Adresse ins Netz. Für unsere Tests lassen wir ihn aber erst mal nur auf der _IPv4 Localhost_ Adresse und auf dem Standard-HTTP-Port 80 lauschen. Mehrere _Listen_-Direktiven nacheinander sind problemlos möglich; für uns reicht im Moment eine einzige.

Nun laden wir fünf Module:

* mpm_event_module : Prozessmodell "event"
* unixd_module : Zugriff auf Unix Usernamen und Gruppen
* log_config_module : Freie Definition des Zugriffs- / Access-Logs
* authn_core_module : Basismodul für die Authentifizierung
* authz_core_module : Basismodul für die Autorisierung



Wir hatten in der Lektion 1 ja alle mitgelieferten Module vorkompiliert. Hier nehmen wir nur die wichtigsten in unsere Konfiguration auf. _mpm_event_module_ und _unixd_module_ sind nötig für den Betrieb des Servers. Bei der Kompilierung im ersten Tutorial hatten wir uns für das Prozessmodell _event_ entschieden, das wir hier nun durch das Laden des Moduls aktivieren. Interessant: Bei Apache 2.4 lässt sich auch eine so grundlegende Einstellung wie das Prozessmodell des Servers mittels der Konfiguration auswählen. Das Modul _unixd_ benötigen wir, um den Server, wie oben beschrieben, unter dem von uns definierten Usernamen laufen zu lassen.

Das Log-Modul _log_config_module_ erlaubt uns eine freie Definition des Access-Logs, wovon wir im Folgenden gleich Gebrauch machen werden. Schliesslich die beiden Module _authn_core_module_ und _authz_core_module_. Der erste Teil des Namens verweist auf Authentisierung (_Authn_) und Autorisierung (_Authz_). Core bedeutet dann, dass es sich bei diesen Modulen um die Basis für diese Funktionen handelt.

Beim Zugriffsschutz spricht man oft von _AAA_, also _Authentisierung_, _Autorisierung_ und _Access Control_. Authentisieren bedeutet dabei das Überprüfen der Identität eines Benutzers. Unter Autorisierung versteht man das Feststellen der Zugriffsrechte eines vorher authentisierten Benutzers. Access Control schliesslich bedeutet die Entscheidung, ob ein authentisierter Benutzer mit den eben festgestellten Zugriffsrechten zugelassen wird. Die Basis für diesen Mechanismus legen wir durch das Laden dieser beiden Module. Alle weiteren Module mit den beiden Kürzeln _authn_ und _authz_, von denen es eine grosse Menge gibt, setzen diese Module voraus. Für den Moment benötigen wir eigentlich nur das Autorisierungsmodul, aber mit dem Laden des Authentisierungsmoduls bereiten wir uns auf spätere Erweiterungen vor.

Mit _ErrorLogFormat_ greifen wir in das Format des Fehler-Logfiles ein. Wir erweitern das gängige Logformat etwas, indem wir namentlich den Zeitstempel sehr genau definieren. `[%{cu}t]` entspricht damit einem Eintrag wie `[2015-09-24 06:34:29.199635]`. Das heisst das Datum rückwärts notiert, dann die Uhrzeit mit einer Genauigkeit von Mikrosekunden. Die Umkehrung des Datums hat den Vorteil, dass sich die Zeiten im Logfile sauber ordnen lassen; die Mikrosekunden geben uns genaue Auskunft über den Zeitpunkt eines Eintrages und lassen gewisse Rückschlüsse über die Zeitdauer der Verarbeitung in verschiedenen Modulen zu. Dem dient auch der nächste Konfigurationsteil `[%-m:%-l]` , der das loggende Modul und den _Loglevel_, also die Schwere des Fehlers nennt. Danach folgen die IP-Adresse des Clients (` %-a`); eine eindeutige Identifikation des Requests (`%-L`); eine sogenannte Unique-ID, welche in späteren Anleitungen zur Korrelation von Requests dienen kann) und schliesslich die eigentliche Meldung, die wir mittels `%M` referenzieren.

Mit _LogFormat_ definieren wir ein Format für das Zugriffs-Logfile. Wir nennen es _combined_. Dieses gängige Format schliesst Client-IP-Adresse, Zeitstempel, Methode, Pfad, HTTP-Version, HTTP-Status-Code, Antwort-Grösse, Referer und die Bezeichnung des Browsers (User-Agent) mit ein. Beim Zeitstempel wählen wir eine recht komplizierte Konstruktion. Der Grund ist der Wille, beim Error-Log und im Access-Log die Timestamps in demselben Format anzeigen zu können. Während wir dazu im Error-Log aber eine einfache Identifikation haben, müssen wir den Zeitstempel im Falle des Access-Log-Formats mühsam konstruieren.

Den _LogLevel_ für das Fehler-Logfile stellen wir mit _Debug_ auf die höchste Stufe. Das ist für die Produktion zu gesprächig, im Labor macht das aber durchaus Sinn. Apache ist gemeinhin nicht sehr gesprächig, so dass man mit der Datenmenge meist gut zurecht kommt.

Dem Fehler-Logfile weisen wir mit _ErrorLog_ den Pfad _logs/error.log_ zu. Dieser Pfad ist relativ zum _ServerRoot_-Verzeichnis.

Das definierte _LogFormat combined_ benützen wir nun für unser Zugriffs-Logfile namens _logs/access.log_.

Der Webserver liefert Dateien aus. Diese sucht er auf einer Diskpartition, oder er generiert sie mithilfe einer installierten Applikation. Wir sind noch beim einfachen Fall und geben dem Server mittels _DocumentRoot bekannt_, wo er die Dateien findet. _/apache/htdocs_ ist ein absoluter Pfad unter dem _ServerRoot_. Hier könnte auch wieder ein relativer Pfad stehen, aber arbeiten wir hier besser mit klaren Verhältnissen! Konkret bedeutet _DocumentRoot_, dass der URL-Pfad _/_ auf den Betriebssystempfad _/apache/htdocs_ gemappt wird.

Nun folgt ein _Directory_-Block. Mit diesem Block verhindern wir, dass Dateien ausserhalb des von uns bezeichneten _DocumentRoot_ ausgeliefert werden. Für den Pfad / verbieten wir jeglichen Zugriff mittels der Direktiven _Require all denied_. Dieser Eintrag referenziert die Authentifizierung (_all_), macht eine Aussage zur Autorisierung (_Require_) und definiert den Zugriff: _denied_, also gar keinen Zugriff und zwar für niemanden; jedenfalls nicht für das Verzeichnis _/_.

Die Direktive _Options_ setzen wir auf _SymLinksIfOwnerMatch_. Mit _Options_ können wir festlegen welche Spezialfeatures beim Ausliefern des Verzeichnisses / beachtet werden sollen. Eigentlich gar keine und in der Produktion würden wir deshalb Options _None_ schreiben. In unserem Fall haben wir aber das _DocumentRoot_ auf einen symbolischen Link gelegt und der wird nur dann gesucht und auch gefunden, wenn wir den Server mit _SymLinksIfOwnerMatch_ anweisen, unterhalb von / auch Symlinks zuzulassen. Zumindest wenn die Besitzverhältnisse sauber sind. Auf produktiven Systemen ist aus Sicherheitsgründen beim Servieren von Files besser auf Symlinks zu verzichten. Aber bei unserem Testsystem geht der Komfort noch vor.

_AllowOverride_ teilt dem Server mit, dass er nicht auf sogenannte _.htaccess_-Dateien zu achten braucht, denn wir planen nicht, damit zu arbeiten. Diese Dateien sind vor allem für Webhoster und Shared-Hosting von Interesse. Dies trifft auf uns eher nicht zu.

Nun eröffnen wir einen _VirtualHost_. Er korrespondiert mit der oben definierten _Listen_-Direktive. Zusammen mit dem eben definierten _Directory_-Block legt er fest, dass unser Webserver per Default gar keinen Zugriff zulässt. Auf der IP-Adresse _127.0.0.1, Port 80_ wollen wir aber Zugriffe zulassen und die werden innerhalb dieses Blocks definiert.

Konkret lassen wir Zugriffe auf unser _DocumentRoot_ zu. Schlüsselanweisung ist hier das _Require all granted_, womit wir im Gegensatz zum Verzeichnis _/_ kompletten Zugriff zulassen. Anders als oben sind ab diesem Pfad nun keine Symlinks mehr vorgesehen und auch sonst keine Spezialfähigkeiten: _Options None_, _AllowOverride None_.

###Schritt 3: Server starten

Damit ist unser minimaler Server beschrieben. Es wäre möglich, einen noch knapperen Server zu definieren. Aber damit liesse sich nicht mehr so komfortabel arbeiten wie mit unserem und er wäre auch nicht mehr sicher. Eine gewisse Grundsicherung ist aber angebracht. Denn wenn wir nun im Labor einen Service aufbauen, dann sollte der sich auch mit punktuellen Anpassungen in eine produktive Umgebung verschieben lassen. Einen Service kurz vor der Produktivschaltung noch von Grund auf sichern zu wollen ist illusorisch.

Starten wir den Server wieder wie in Lektion 1 im Vordergrund und nicht als Daemon:

```bash
$> cd /apache
$> sudo ./bin/httpd -X
```

###Schritt 4: Server mit curl ansprechen

Wir können den Server nun wieder mit dem Browser ansprechen. Aber aus der Shell heraus lässt es sich erst mal sauberer arbeiten und besser verstehen, was passiert:

```bash
$> curl http://localhost/index.html
```

Dies liefert folgendes Resultat.

```bash
<html><body><h1>It works!</h1></body></html>
```

Wir haben also einen HTTP-Aufruf abgesetzt und von unserem minimal konfigurierten Server eine Antwort erhalten, die unseren Erwartungen entspricht.

###Schritt 5: Anfrage und Antwort untersuchen

Das passiert also bei einer HTTP-Anfrage. Aber was antwortet der Server uns eigentlich genau? Dazu rufen wir _curl_ nochmals auf. Dieses Mal mit der Option _verbose_.

```bash
$> curl --verbose http://localhost/index.html
* Hostname was NOT found in DNS cache
*   Trying 127.0.0.1...
* Connected to localhost (127.0.0.1) port 80 (#0)
> GET /index.html HTTP/1.1
> User-Agent: curl/7.35.0
> Host: localhost
> Accept: */*
> 
< HTTP/1.1 200 OK
< Date: Thu, 24 Sep 2015 09:27:02 GMT
* Server Apache is not blacklisted
< Server: Apache
< Last-Modified: Mon, 11 Jun 2007 18:53:14 GMT
< ETag: "2d-432a5e4a73a80"
< Accept-Ranges: bytes
< Content-Length: 45
< 
<html><body><h1>It works!</h1></body></html>
* Connection #0 to host localhost left intact
```

Die mit einem * bezeichneten Zeilen beschreiben Meldungen zum Aufbau und Abbau der Verbindung. Sie geben keinen Netzwerkverkehr wieder. Dann folgt mit > die Anfrage und mit < die Antwort.

Konrekt besteht eine HTTP-Anfrage aus 4 Teilen:

* Request-Zeile und Request-Header
* Request-Body (optional und hier bei einem GET-Request fehlend)
* Response-Header
* Response-Body

Die ersten Teile brauchen hier noch nicht zu interessieren. Interessant sind die _Response-Header_. Das ist der Teil, mit dem der Webserver die Antwort beschreibt. Die eigentliche Antwort, der _Response-Body_, folgt dann nach einer Leerzeile.

Was sagen die Header nacheinander?

Zunächst folgt die _Status_-Zeile mit dem _Protokoll_ inklusive der Version, dann folgt der _Status-Code_. _200 OK_ ist die normale Antwort eines Webservers. Auf der nächsten Zeile sehen wir das Datum und die Uhrzeit des Servers. Die anschliessende Zeile beginnt mit einem Stern, _*_, und bezeichnet damit eine zu _curl_ gehörige Zeile. Die Nachricht hat mit _curls_ Behandlung von HTTP Pipelining zu tun, was uns nicht weiter zu interessieren braucht. Dann folgt die _Server_-Zeile, auf der sich unser Webserver als Apache identifiziert. Dies ist die knappste mögliche Identifikation. Wir haben sie mit _ServerTokens_ Prod definiert. 

Dann teilt der Server mit, wann das der Antwort zu Grunde liegende File zum letzten Mal verändert wurde; also die _Unix Modified-Timestamp_. _ETag_ und _Accept_-Ranges brauchen für den Moment nicht zu interessieren. Interessanter ist die _Content-Length_. Diese gibt an, wieviele Bytes im _Response-Body_ erwartet werden dürfen. In unserem Fall sind das 45 Bytes.

Übrigens ist die Reihenfolge dieser Header charakteristisch für einen Webserver. _NginX_ verwendet eine andere Reihenfolge und bringt den _Server-Header_ beispielsweise vor dem Datum. Apache lässt sich deshalb auch identifizieren, wenn die Server-Zeile uns in die Irre führen sollte.

###Schritt 6: Die Antwort noch etwas genauer untersuchen

Es ist möglich, bei der Kommunikation noch etwas tiefer in _curl_ hineinzublicken. Das geschieht über den Kommandozeilen-Parameter _--trace-ascii_:

```bash
$> curl   http://localhost/index.html --trace-ascii -
== Info: Hostname was NOT found in DNS cache
== Info:   Trying 127.0.0.1...
== Info: Connected to localhost (127.0.0.1) port 80 (#0)
=> Send header, 83 bytes (0x53)
0000: GET /index.html HTTP/1.1
001a: User-Agent: curl/7.35.0
0033: Host: localhost
0044: Accept: */*
0051: 
<= Recv header, 17 bytes (0x11)
0000: HTTP/1.1 200 OK
<= Recv header, 37 bytes (0x25)
0000: Date: Thu, 24 Sep 2015 11:46:17 GMT
== Info: Server Apache is not blacklisted
<= Recv header, 16 bytes (0x10)
0000: Server: Apache
<= Recv header, 46 bytes (0x2e)
0000: Last-Modified: Mon, 11 Jun 2007 18:53:14 GMT
<= Recv header, 26 bytes (0x1a)
0000: ETag: "2d-432a5e4a73a80"
<= Recv header, 22 bytes (0x16)
0000: Accept-Ranges: bytes
<= Recv header, 20 bytes (0x14)
0000: Content-Length: 45
<= Recv header, 2 bytes (0x2)
0000: 
<= Recv data, 45 bytes (0x2d)
0000: <html><body><h1>It works!</h1></body></html>.
<html><body><h1>It works!</h1></body></html>
== Info: Connection #0 to host localhost left intact
```

Der Parameter _--trace-ascii_ benötigt ein File als Parameter, um darin einen _Ascii Dump_ der Kommunikation abzulegen. "-" funktioniert als Shortcut zu _STDOUT_, so dass wir uns die Mitschrift einfach anzeigen lassen können.

Gegenüber _verbose_ bringt _trace-ascii_ mehr Details zur Länge der übertragenen Bytes in der _Request_- und _Response_-Phase. Die Request-Header umfassten in obigem Beispiel also 83 Bytes. Bei der Antwort werden die Bytes dann pro Header-Zeile gelistet und pauschal für den Body der Antwort: 45 Bytes. Das mag jetzt alles nach Haarspalterei klingen. Tatsächlich ist es aber bisweilen spielentscheidend, wenn man ein Stückchen vermisst und sich nicht ganz sicher ist, was wo in welcher Reihenfolge angeliefert wurde. So ist es etwa auffällig, dass bei den Headerzeilen jeweils 2 Bytes hinzukommen. Das sind der CR (Carriage Return) und NL (New Line), den das HTTP-Protokoll in den Header-Zeilen vorsieht. Anders im Response-Body, wo nur das retourniert wird, was tatsächlich in der Datei steht. Das ist hier offensichtlich nur ein NL ohne CR. Auf der drittuntersten Zeile (_000: <html ..._) folgt auf das grösser-als-Zeichen ein Punkt. Dies ist eine Umschreibung des NL-Charakters der Antwort, der wie andere Escape-Sequenzen auch in der Form eines Punktes wiedergegeben wird.


###Schritt 7: Mit Trace Methode arbeiten

Oben habe ich die Direktive _TraceEnable_ beschrieben. Wir haben sie sicherheitshalber auf _off_ geschaltet. Bei der Fehlersuche kann sie aber ganz nützlich sein. Also probieren wir das doch mal aus. Setzen wir die Option auf on:

```bash
TraceEnable On
```

Wir starten den Server neu und setzen folgenden curl-request ab.

```bash
$> curl -v --request TRACE http://localhost/index.html
```

Wir rufen also die bekannte _URL_ mit der _HTTP Methode TRACE_ (anstatt _GET_) auf. Als Resultat erwarten wir folgendes:

```bash
* Hostname was NOT found in DNS cache
*   Trying 127.0.0.1...
* Connected to localhost (127.0.0.1) port 80 (#0)
> TRACE /index.html HTTP/1.1
> User-Agent: curl/7.35.0
> Host: localhost
> Accept: */*
> 
< HTTP/1.1 200 OK
< Date: Thu, 24 Sep 2015 09:38:01 GMT
* Server Apache is not blacklisted
< Server: Apache
< Transfer-Encoding: chunked
< Content-Type: message/http
< 
TRACE /index.html HTTP/1.1
User-Agent: curl/7.35.0
Host: localhost
Accept: */*

* Connection #0 to host localhost left intact
```

Im _Body_ wiederholt der Server wie vorgesehen die Informationen zum gesendeten Request. Tatsächlich sind die Zeilen hier identisch. Wir können also bestätigen, dass unterwegs nichts mit der Anfrage passiert ist. Wenn wir aber über einen oder mehrere Proxy-Server gegangen wären, dann gäbe es hier auf jeden Fall weitere _Header_-Zeilen, die wir so auch als _Client_ zu Gesicht bekommen können. Zu einem späteren Zeitpunkt werden wir mächtigere Hilfsmittel für die Fehlersuche kennen lernen. Aber ganz ausser Acht lassen sollten wir die _TRACE_-Methode dennoch nicht.

Vergessen Sie nicht, _TraceEnable_ wieder auszuschalten.

###Schritt 8: Server mit "ab" auf den Zahn fühlen

Das wär's erst Mal mit dem simplen Server. Spasseshalber können wir ihm aber noch etwas auf den Zahn fühlen. Wir inszenieren einen kleinen Lasttest mit _ab_; kurz für _Apache Bench_. Dies ist ein sehr einfaches Lasttest-Programm, das immer zur Hand ist und rasche erste Resultate zur Performance liefern kann. So lasse ich ab gerne vor und nach einer Konfigurationsänderung laufen, um eine Idee zu erhalten, ob sich an der Performance etwas verändert hat. _Ab_ ist nicht sehr mächtig und der lokale Aufruf bringt auch keine sauberen Resultate. Aber so ein erster Augenschein lässt sich mit diesem Hilfsmittel gewinnen.

```bash
$> ./bin/ab -c 1 -n 1000 http://localhost/index.html
```

Wir starten ab mit _concurrency 1_. Das heisst, dass wir parallel nur eine einzige Anfrage stellen. Total stellen wir 1000 Anfragen auf die bekannte _URL_. Hier ist die Ausgabe von _ab_:

```bash
$> ./bin/ab -c 1 -n 1000 http://localhost/index.html
This is ApacheBench, Version 2.3 <$Revision: 1663405 $>
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
Document Length:        45 bytes

Concurrency Level:      1
Time taken for tests:   0.676 seconds
Complete requests:      1000
Failed requests:        0
Total transferred:      250000 bytes
HTML transferred:       45000 bytes
Requests per second:    1480.14 [#/sec] (mean)
Time per request:       0.676 [ms] (mean)
Time per request:       0.676 [ms] (mean, across all concurrent requests)
Transfer rate:          361.36 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    0   0.0      0       0
Processing:     0    1   0.2      1       3
Waiting:        0    0   0.1      0       2
Total:          0    1   0.2      1       3

Percentage of the requests served within a certain time (ms)
  50%      1
  66%      1
  75%      1
  80%      1
  90%      1
  95%      1
  98%      1
  99%      1
 100%      3 (longest request)

```

Interessant ist für uns vor allem die Zahl der Fehler (_Failed Requests_) und die Zahl der Anfragen pro Sekunde (_Request per second_). Ein Wert von über Tausend ist ein guter Start. Zumal wir ja immer noch mit einem einzigen Prozess und nicht mit einem parallelisierten Daemon arbeiten (und deshalb auch der _concurrency-level_ auf 1 gesetzt ist).

###Schritt 9: Direktiven und Module ansehen

Zum Schluss dieses Tutorials schauen wir uns die verschiedenen Direktiven an, welche ein mit unserem Konfigurationsfile zu startender Apache kennt. Die verschiedenen geladenen Module erweitern den Befehlssatz des Servers. Die damit zur Verfügung stehenden Konfigurationsparameter sind auf der Webseite des Projektes gut dokumentiert. Tatsächlich kann es aber in besonderen Fällen hilfreich sein, den durch die geladenen Module zur Verfügung stehenden Direktiven zu überblicken. Die Direktiven erhält man mit dem Kommando-Zeilen-Flag _-L_.

```bash
$> ./bin/httpd -L
<Directory (core.c)
	Container for directives affecting resources located in the specified directories
	Allowed in *.conf only outside <Directory>, <Files>, <Location>, or <If>
<Location (core.c)
	Container for directives affecting resources accessed through the specified URL paths
	Allowed in *.conf only outside <Directory>, <Files>, <Location>, or <If>
<VirtualHost (core.c)
	Container to map directives to a particular virtual host, takes one or more host addresses
	Allowed in *.conf only outside <Directory>, <Files>, <Location>, or <If>
<Files (core.c)
...
```
Die Direktiven folgen hierbei der Reihenfolge wie sie geladen werden. Zu jeder Direktive folgt darauf eine kurze Beschreibung der Funktionalität.

Mit dieser Liste ist es nun möglich herauszufinden, ob man sämtliche geladenen Module in der Konfiguration auch wirklich benötigt, respektive referenziert. In komplizierteren Konfigurationen mit zahlreichen geladenen Modulen kann es schliesslich schon mal vorkommen, dass man unsicher ist, ob man alle Module wirklich verwendet.

Man kann die Module also aus dem Konfigurationsfile herauslesen, den Output von _httpd -L_ pro Modul zusammenfassen und dann wiederum im Konfigurationsfile nachsehen, ob eine der gelisteten Direktiven benützt wird. Diese verschachtelte Abfrage ist eine schöne Fingerübung, die ich nur empfehlen kann. Für mich habe ich sie wie folgt gelöst:

```bash
$> grep LoadModule conf/httpd.conf | awk '{print $2}' | sed -e "s/_module//" | while read M; do echo "Module $M"; R=$(./bin/httpd -L | grep $M | cut -d\  -f1 | tr -d "<" | xargs | tr " " "|");  egrep -q "$R" ./conf/httpd.conf; if [ $? -eq 0 ]; then echo "OK"; else echo "Not used"; fi; echo; done
Module mpm_event
OK

Module unixd
OK

Module log_config
OK

Module authn_core
Not used

Module authz_core
OK

```

Das Modul _authn_core_ wird also nicht verwendet. Das ist korrekt; das hatten wir oben auch so beschrieben, denn es ist für eine zukünftige Verwendung geladen. Die übrigen Module scheinen nötig.


Soweit zu diesem Tutorial. Damit ist bereits ein tauglicher Webserver vorhanden, mit dem man gut arbeiten kann. In den nächsten Lektionen bauen wir ihn weiter aus.


###Verweise

* Apache: http://httpd.apache.org
* Apache Direktiven: http://httpd.apache.org/docs/current/mod/directives.html
* HTTP Header: http://en.wikipedia.org/wiki/List_of_HTTP_header_fields (Englisch)
* RFC 2616 (HTTP Protokoll): http://www.ietf.org/rfc/rfc2616.txt (Englisch)


### Lizenz / Kopieren / Weiterverwenden

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png" /></a><br />Diese Arbeit ist wie folgt lizenziert / This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.

