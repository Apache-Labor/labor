##Das Zugriffslog Ausbauen

###Was machen wir?

Wir definieren ein stark erweitertes Logformat, um den Verkehr besser überwachen zu können.

###Warum tun wir das?

In der gebräuchlichen Konfiguration des Apache Webservers wird ein
Logformat eingesetzt, das nur die nötigsten Informationen zu den
Zugriffen der verschiedenen Clients mitschreibt. In der Praxis werden
oft zusätzliche Informationen benötigt, die sich leicht im Zugriffslog
(Accesslog) des Servers notieren lassen. 


###Voraussetzungen


* Ein Apache Webserver, idealerweise mit einem File-Layout wie bei [Anleitung 1 (Kompilieren eines Apache Servers)](http://www.netnea.com/cms/apache_tutorial_1_apache_compilieren/) erstellt.
* Verständnis der minimalen Konfiguration in [Anleitung 2 (Apache minimal konfigurieren)](http://www.netnea.com/cms/apache_tutorial_2_apache_minimal_konfigurieren/).
* Ein Apache Webserver mit SSL-/TLS-Unterstützung wie in [Anleitung 4 (Konfigurieren eines SSL Servers)](http://www.netnea.com/cms/apache_tutorial_4_konfigurieren_eines_ssl_servers)

###Schritt 1: Logformat Common verstehen

Das Logformat _Common_ ist ein sehr simples Format, das nurmehr sehr
selten eingesetzt wird. Es hat den Vorteil, sehr platzsparend zu sein und kaum
überflüssige Informationen zu schreiben.

```bash
LogFormat "%h %l %u %t \"%r\" %>s %b" common
...
CustomLog logs/access.log common
```

Mit der Direktive _LogFormat_ definieren wir ein Format und geben
ihm einen Namen; hier _common_.

Diesen Namen rufen wir in der Definition des Logfiles mit der Direktive _CustomLog_ ab. Diese beiden Befehle können wir in der Konfiguration mehrmals einsetzen. Es lassen sich also mehrere Logformate mit mehreren Namenskürzeln nebeneinander definieren und mehrere Logfiles in verschiedenen Formaten schreiben. Es bietet sich etwa an, für verschiedene Dienste auf demselben Server separate Logfiles zu schreiben.

Die einzelnen Elemente des Logformats _common_ lauten wie folgt:

_%h_ bezeichnet den _Remote host_, normalerweise die IP
Adresse des Clients, der den Request abgesetzt hat. Falls dieser Client
aber hinter einem Proxy-Server steht, dann sehen wir hier die IP Adresse
dieses Proxy-Servers. Wenn sich deshalb mehrere Clients den Proxy Server
teilen, dann werden sie hier alle denselben _Remote host_-Eintrag
besitzen. Zudem ist es möglich auf unserem Server die IP Adressen durch
einen DNS Reverse Lookup rückzuübersetzen. Falls wir dies konfigurieren
(was nicht zu empfehlen ist), dann stünde hier der eruierte Hostname
des Clients.

_%l_ stellt den _Remote logname_ dar. Er ist in aller Regel leer 
und wird durch einen Strich ("-") wiedergegeben. Tatsächlich ginge es dabei um 
die Identifizierung eines
Clients durch einen _ident_-Zugriff auf den Client. Dies wird von
den Clients kaum unterstützt und führt zu grossen Performance-Engpässen,
weshalb es sich beim _%l_ um ein Artefakt aus den frühen 1990er
Jahren handelt. 

_%u_ ist gebräuchlicher und bezeichnet den Usernamen eines
authentifizierten Users. Der Name wird durch ein
Authentifizierungsmodul gesetzt und bleibt leer (also wiederum "-"),
solange ein Zugriff ohne Authentifizierung auf dem Server auskommt.

_%t_ meint die Uhrzeit des Zugriffes. Bei grossen, langsamen
Requests meint es die Uhrzeit, in dem Moment in dem der Server die
sogenannte Request-Zeile empfangen hat. Da Apache einen Request erst
nach Abschluss der Antwort in das Logfile schreibt, kann es vorkommen,
dass ein langsamer Request mit einer früheren Uhrzeit mehrere Einträge
tiefer als ein kurzer Request steht, der später gestartet ist.
Beim Lesen des Logfiles führt das bisweilen zu Verwirrung.

Die Uhrzeit wird standardmässig zwischen rechteckigen Klammern ausgegeben.
Es wird normalerweise in der lokalen Zeit inklusive der Abweichung von
der Standardzeit geschrieben. Zum Beispiel:

```bash
[25/Nov/2014:08:51:22 +0100]
```

Hier meint es also den 25. November 2014, 8 Uhr 51, 1 Stunde vor der
Standardzeit. Das Format der Uhrzeit selbst lässt sich gegebenenfalls
anpassen. Dies geschieht nach dem Muster _%{format}t_, wobei
_format_ der Spezifikation von _strftime(3)_ folgt. Wir haben von
dieser Möglichkeit in der 2. Anleitung bereis Gebrauch gemacht.
Sehen wir es uns aber in einem Beispiel genauer an:

```bash
%{[%Y-%m-%d %H:%M:%S %z (%s)]}t
```

In diesem Beispiel bringen wir das Datum in die Reihenfolge
_Jahr-Monat-Tag_, um eine bessere Sortierbarkeit zu erreichen. Und
nach der Abweichung von der Standardzeit fügen wir die Zeit in Sekunden
seit dem Start der Unixepoche im Januar 1970 ein. Dies ist ein durch 
ein Skript leichter les- und interpretierbares Format.

Dieses Beispiel bringt uns Einträgen nach folgendem Muster:

```bash
[2014-11-25 09:34:33 +0100 (1322210073)]
```

Soweit zu _%t_.
Damit kommen wir zu _%r_ und damit zur Request-Zeile. Hierbei
handelt es sich um die erste Zeile des HTTP-Requests, wie er vom Client 
an den Server gesendet wurde. Stren genommen gehört die Requestzeile
nicht in die Gruppe der Request-Header; in aller Regel subsummiert
man sie aber zusammen mit letzteren. Wie dem auch sei, auf der Request-Zeile übermittelt der
Client dem Server die Identifikation der Resource, die er verlangt.

Konkret folgt die Zeile diesem Muster:

```bash
Methode URI Protokoll
```

In der Praxis lautet ein einfaches Beispiel also wie folgt:

```bash
GET /index.html HTTP/1.1
```

Es wird also die _GET_-Methode angewendet. Dann folgt ein
Leerschlag, dann der absolute Pfad auf die Resource auf dem Server. Hier
die Index-Datei. Optional kann der Client bekanntlich noch einen
_Query-String_ an dem Pfad anhängen. Dieser _Query-String_ in
der Regel mit einem Fragezeichen eingeleitet und bringt verschiedene
Parameter-Wert-Paare. Der _Query-String_
wird im Logformat auch wiedergegeben. Schliesslich das Protokoll, das
in aller Regel HTTP in der Version 1.1 lautet. Zum Teil wird aber
gerade von Agents, also automatisierten Skripten, nach wie vor
die Version 1.0 verwendet. Das neue Protokoll HTTP/2 wird in der
Request-Zeile des ersten Requests noch nicht vorkommen. Vielmehr
findet in HTTP/2 während des Requests ein Update von HTTP/1.1 auf HTTP/2
statt. Der Start folgt also obenstehendem Muster.

Das folgende Format-Element folgt einem etwas anderen Muster: _%>s_.
Dies meint den Status der Antwort, also etwa _200_ für
einen erfolgreich abgeschlossenen Request. Die spitze Klammer weist
darauf hin, dass wir uns für den finalen Status interessieren. Es
kann vorkommen, dass eine Anfrage innerhalb des Servers weitergereicht
wird. In diesem Fall interessiert uns nicht der Status, der das
Weiterreichen ausgelöst hat, sondern den Status der Antwort des
finalen internen Requests.

Ein typisches Beispiel wäre ein Aufruf, der auf dem Server zu einem
Fehler führt (also Status 500). Wenn dann aber die zugehörige Fehlerseite
nicht vorhanden ist, dann ergibt die interne Weiterreichung einen
Status 404. Mit der spitzen Klammer erreichen wir, dass in diesem
Fall das 404 in das Logfile geschrieben wird. Setzen wir die spitze
Klammer in umgekehrter Richtung, dann würde der Status 500 geloggt.
Um ganz sicher zu gehen, könnte es angebracht sein, beide Werte zu
loggen, also folgender - in der Praxis ebenfalls unüblicher - Eintrag:

```bash
%<s %>s
```

_%b_ ist das letzte Element des Logformats _common_. Es
gibt die Zahl der im Content-Length Response Headers angekündigten Bytes wieder.  Bei einer Anfrage
an _http://www.example.com/index.html_ entspricht dieser Wert der Grösse
der Datei _index.html_. Die ebenfalls übertragenen _Response-Header_ werden
nicht mitgezählt. Dazu kommt, dass diese Zahl nur eine Ankündigung wiedergibt und keine
Garantie darstellt, dass diese Daten auch wirklich übertragen wurden.


###Schritt 2: Logformat Combined verstehen

Das am weitesten verbreitete Logformat _combined_ baut auf dem Logformat _common_ auf und
erweitert es um zwei Elemente.

```bash
LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"" combined
...
CustomLog logs/access.log combined
```
 
Das Element _"%{Referer}i"_ bezeichnet den Referrer. Er wird in
Anführungszeichen wiedergegeben. Der Referrer meint diejenige
Resource, von der aus ursprünglich der jetzt erfolgte Request ausgelöst
wurde. Diese komplizierte Umschreibung lässt sich an einem Beispiel
besser Umschreiben. Wenn man in einer Suchmaschine einen Link anklickt,
um auf _www.example.com_ zu gelangen und dort automatisch auf
_shop.example.com_ weitergeleitet wird, dann wird der
Logeintrag auf dem Server _shop.example.com_ den Referrer auf die
Suchmaschine tragen und nicht den Verweis auf _www.example.com_.
Wenn dann aber von _shop.example.com_ eine abhängige CSS-Datei
geladen wird, dann geht der Referrer normalerweise auf
_shop.example.com_. Bei alledem ist aber zu beachten, dass der
Referrer ein Teil der Anfrage des Clients ist. Der Client ist
angehalten, sich an das Protokoll und die Konventionen zu halten,
tatsächlich kann er aber beliebige Informationen senden, weshalb man
sich in Sicherheitsfragen nicht auf Header wie diesen verlassen darf.

_"%{User-agent}i"_ schliesslich meint den sogenannten User-Agent des Clients,
der wiederum in Anführungszeichen gesetzt wird.
Auch dies ist wieder ein Wert, der durch den Client kontrolliert wird,
und auf den wir uns nicht zu sehr verlassen sollten. Mit dem User-Agent
ist die Browser-Software des Clients gemeint; normalerweise angereichert
um die Version, die Rendering Engine, verschiedene Kompatibilitätsangaben
mit anderen Browsern und diverse installierte Plugins. Das führt zu sehr
langen User-Agent-Einträgen und kann im Einzelfall so viele
Informationen enhalten, dass ein individueller Client sich darüber
eindeutig identifizieren lässt, weil er eine besondere Kombination
von verschiedenen Zusatzmodulen in bestimmten Versionen besitzt.

###Schritt 3: Modul Logio aktivieren

Mit dem _combined_ Format haben wir das am weitesten verbreitete Apache
Logformat kennengelernt. Um die alltägliche Arbeit zu erleichtern
reichen die dargestellten Werte aber nicht. Weitere Informationen werden
deshalb mit Vorteil im Logfile mitgeschrieben.

Es bietet sich an, auf sämtlichen Servern dasselbe Logformat zu
verwenden. Anstatt jetzt also ein, zwei weitere Werte zu propagieren,
beschreibt diese Anleitung ein sehr umfassendes Logformat, das
sich in der Praxis in verschiedenen Szenarien bewährt hat.

Um das in der Folge beschriebene Logformat konfigurieren zu können,
muss aber zunächst das Modul _Logio_ aktiviert werden.

Wenn der Server wie in der Anleitung 1 beschrieben
kompiliert wurde, dann ist das Modul bereits vorhanden und muss nur noch in der Liste
der zu ladenden Module in der Konfigurationsdatei des Servers ergänzt werden.

```bash
LoadModule		logio_module		modules/mod_logio.so
```

Wir benötigen dieses Modul um zwei Werte mitschreiben zu können.
<i>IO-In</i> und <i>IO-Out</i>. Also die total Zahl der Bytes des
HTTP-Requests inklusive Header-Zeilen und die totale Zahl der
Bytes in der Antwort, wiederum inklusive Header-Zeilen.

###Schritt 4: Neues Logformat Extended konfigurieren

Damit sind wir bereit für ein neues, sehr umfassendes Logformat. Das Format
umfasst auch Werte, die der Server mit den bis hierhin definierten Modulen
noch nicht kennt. Er wird sie leer lassen, respektive durch einen Strich _"-"_
darstellen. Nur mit dem eben aktivierten Modul _Logio_ klappt das nicht.
Wenn wir dessen Werte ansprechen, ohne dass sie vorhanden wären, stürzt
der Server ab.

In den folgenden Anleitungen werden wir diese Werte dann nach und nach
füllen. Weil es aber wie oben erklärt sinnvoll ist, überall dasselbe Logformat zu
verwenden, greifen wir hier mit der nun folgenden Konfiguration bereits etwas vor.

Wir gehen vom _Combined_-Format aus und erweitern es nach rechts. Dies hat
den Vorteil, dass die erweiterten Logfiles in vielen Standard-Tools weiterhin
lesbar sind, denn die zusätzlichen Werte werden einfach ignoriert. Ferner ist
es sehr leicht, die erweiterten Logfiles in die Basis zurückzuübersetzen um
dann eben wieder ein Logformat _combined_ vor sich zu haben.

Wir definieren das Logformat wie folgt:

```bash

LogFormat "%h %{GEOIP_COUNTRY_CODE}e %u [%{%Y-%m-%d %H:%M:%S}t.%{usec_frac}t] \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %v %A %p %R %{BALANCER_WORKER_ROUTE}e \"%{cookie}n\" %{UNIQUE_ID}e %{SSL_PROTOCOL}x %{SSL_CIPHER}x %I %O %{ratio}n%% %D %{ModSecTimeIn}e %{ApplicationTime}e %{ModSecTimeOut}e %{ModSecAnomalyScoreIn}e %{ModSecAnomalyScore}e" extended

...

CustomLog		logs/access.log extended

```

###Schritt 5: Neues Logformat Extended verstehen

Das neue Logformat erweitert die Zugriffsprotokolle um 19 Werte. Das sieht auf den ersten
Blick übertrieben aus, tatsächlich hat das aber alles seine Berechtigung und im
täglichen Einsatz ist man um jeden dieser Werte froh, gerade wenn man einem Fehler
auf der Spur ist.

Schauen wir uns die Werte nacheinander an.

In der Erklärung zum Log-Format _common_ haben wir gesehen, dass der zweite Wert, der Eintrag _logname_
gleich nach der IP Adresse des Clients ein unbenutztes Artefakt darstellt. Wir ersetzen diese Position
im Logfile mit dem Country-Code der IP Adresse des Clients. Das macht Sinn, weil dieser Country-Code 
eine IP Adresse stark charakterisiert (In vielen Fällen macht es einen grossen Unterschied,
ob die Anfrage aus dem Inland oder aus der Südsee stammt). Praktisch ist es nun, sie gleich neben
die IP-Adresse zu stellen und der nichtssagenden Nummer ein Mehr an Information zuzugesellen.

Danach das bereits in der Anleitung 2 definierte Zeitformat, das sich am Zeitformat des Error-Logs
orientiert und nun mit diesem Kongruent ist. Wir bilden die Microsekunden auch ab und erhalten
so sehr präzise Timing-Informationen. Die nächsten Werte sind bekannt.

_%v_ bezeichnet den kanonischen Servernamen, der den Request bearbeitet hat. Falls wir
den Server mittels eines Alias ansprechend, wird hier nicht dieses Alias geschrieben, sondern
der eigentliche Name des Servers. In einem Virtual-Host Setup sind die Servernamen der
Virtual-Hosts auch kanonisch. Sie werden hier also auftauchen und wir
können sie in der Logdatei unterscheiden.

Mit _%A_ folgt die IP-Adresse mit welcher der Server die Anfrage empfangen hat.
Dieser Wert hilft uns, die Server auseinander zu halten, wenn mehrere Logfiles zusammengefügt werden 
oder mehrere Server in dasselbe Logfile schreiben.

Dann beschreibt _%p_ die Portnummer auf welcher der Request empfangen wurde. Auch dies
ist wichtig, um verschiedene Einträge auseinanderhalten zu können, wenn wir verschiedene Logfiles 
(etwa diejenigen für Port 80 und diejenigen für Port 443) zusammenfügen. 

_%R_ gibt den Handler wieder, der die Antwort auf einen Request generiert hat.
Dieser Wert kann leer sein (also _"-"_) wenn eine statische Datei ausgeliefert
wurde. Oder aber er bezeichnet mit _proxy_, dass der Request an einen anderen
Server weitergeleitet worden ist.

*%{BALANCER_WORKER_ROUTE}e* hat auch mit dem Weitergeben von Anfragen zu tun.
Wenn wir zwischen mehreren Zielserver abwechseln belegt dieser Wert, wohin die
Anfrage geschickt wurde.

_%X_ gibt den Status der TCP-Verbindung nach Abschluss der Anfrage wieder. Es sind drei Werte möglich:
Die Verbindung ist geschlossen (_-_), die Verbindung wird mittels _Keep-Alive_ offen gehalten (_+_)
oder aber die Verbindung wurde abgebrochen bevor der Request abgeschlossen werden konnte (_X_).

Mit _"%{cookie}n"_ folgt ein Wert, der dem User-Tracking dient. Damit können wir einen Client mittels
eines Cookies identifizieren und ihn zu einem späteren Zeitpunkt wiedererkennen - sofern er das Cookie
immer noch trägt. Wenn wir das Cookie domänenweit setzen, also auf example.com und nicht beschränkt auf www.example.com,
dann können wir einem Client sogar über mehrere Hosts hinweg folgen.
Im Idealfall wäre dies aufgrund der IP Adresse des Clients ebenfalls möglich, aber sie kann im Laufe einer Session
gewechselt werden und es kann auch sein, dass sich mehrere Clients eine IP Adresse teilen.

Der Wert *%{UNIQUE_ID}e* ist ein sehr hilfreicher Wert. Für jeden Request wird damit auf dem Server
eine eindeutige Identifizierung kreiert. Wenn wir den Wert etwa auf einer Fehlerseite ausgeben, dann lässt
sich ein Request im Logfile aufgrund eines Screenshots bequem identifizieren - und im Idealfall die gesamte Session 
aufgrund des User-Tracking-Cookies nachvollziehen.

Nun folgen zwei Werte, die von *mod_ssl* bekannt gegeben werden. Das Verschlüsselungsmodul
gibt dem Logmodul Werte in einem eigenen Namensraum bekannt, der mit dem Kürzel _x_ bezeichnet
wird. In der Dokumentation von *mod_ssl* werden die verschiedenen Werte einzeln erklärt.
Für den Betrieb eines Servers sind vor allem das verwendete Protokoll und die verwendete
Verschlüsselung von Interesse. Diese beiden Werte, mittels *%{SSL_PROTOCOL}x* und *%{SSL_CIPHER}x*
referenziert, helfen uns dabei einen Überblick über den Einsatz der Verschlüsselung zu
erhalten. Früher oder später sind wir soweit, dass wir das _TLSv1_ Protokoll abschalten
werden. Zuerst möchten wir aber sicher sein, dass es in der Praxis keine nennenswerte
Rolle mehr spielt. Das Logfile wird uns dabei helfen. Analog der Verschlüsselungsalgorithmus,
der uns die tatsächlich verwendeten _Ciphers_ mitteilt und uns hilft eine Aussage zu machen,
welche Ciphers nicht mehr länger verwendet werden. Die Informationen sind wichtig. Wenn
zum Beispiel Schwächen in einzelnen Protokollversionen oder einzelnen Verschlüsselungsverfahren 
bekannt werden, dann können den Effekt unseres Massnahmen anhand des Logfiles abschätzen.
So war etwa die folgende Aussage im Frühjahr 2015 Gold wert: "Das sofortige Abschalten des SSLv3 
Protokolls als Reaktion auf die POODLE Schwachstelle wird bei ca. 0.8% der Zugriffe zu 
einem Fehler führen. Hochgerechnet auf unsere Kundenbasis werden soundsoviele Kunden 
betroffen sein."

Mit _%I_ und _%O_ folgen die beiden Werte, welche durch das Modul _Logio_ definiert werden.
Es ist die gesamte Zahl der Bytes im Request und die gesamte Zahl der Bytes in der Response.
Wir kennen bereits _%b_ für die Summer der Bytes im Response-Body. _%O_ ist hier etwas genauer
und hilft zu erkennen, wenn die Anfrage oder ihre Antwort entsprechende Grössen-Limiten verletzte.

_%{ratio}n%%_ bedeutet die Prozentzahl der Kompression der übermittelten Daten, welche durch die Anwendung des
Modules _Deflate_ erreicht werden konnte. Dies ist für den Moment noch ohne Belang, bringt uns
in Zukunft aber interessante Performance-Daten.

_%D_ gibt die komplette Dauer des Requests in Microsekunden wieder. Gemessen wird vom Erhalt
der Request-Zeile bis zum Moment, wenn der letzte Teil der Antwort den Server verlässt.

Wir fahren weiter mit Performance-Daten. Wir werden in Zukunft die Stoppuhr ansetzen und 
die Anfrage auf dem Weg in den Server hiein, bei der Applikation und während der Verarbeitung
der Antwort separat messen. Die entsprechenden Werte werden wir in den Environment
Variablen _ModSecTimeIn_, _ApplicationTime_ sowie _ModSecTimeOut_ ablegen.

Und zu guter Letzt noch zwei weitere Werte, die uns _ModSecurity_ in einer späteren Anleitung
zur Verfügung stellen wird, nämlich die Anomalie-Punktezahl der Anfrage und der Antwort.
Was es damit auf sich hat, ist für den Moment noch unwichtig. Wichtig ist, dass wir mit
diesem startk erweiterten Logformat eine Basis gelegt haben auf die wir zukünftig aufbauen
können, ohne das Logformat nochmals anpassen zu müssen.

###Schritt 6: Ausprobieren und Logdatei füllen

Konfigurieren wir das Zugriffslog wie oben beschrieben und beschäftigen wir den Server etwas!

Wir könnten dazu _Apache Bench_ wie in der zweiten Anleitung zwei beschrieben
verwenden, aber das würde ein sehr einförmiges Logfile ergeben. Mit den folgenden beiden Einzeilern bringen
wir etwas Abwechslung hinein.

```bash
$> for N in {1..100}; do curl --silent http://localhost/index.html?n=${N}a >/dev/null; done
$> for N in {1..100}; do PAYLOAD=$(uuid -n $N | xargs); curl --silent --data "payload=$PAYLOAD" http://localhost/index.html?n=${N}b >/dev/null; done
```

Auf der ersten Zeile setzen wir einfach hundert Requests ab, wobei wir sie im _Query-String_ nummerieren.
Auf der zweiten Zeile dann die interessantere Idee: Wieder setzen wir hundert Anfragen ab. Dieses Mal
möchten wir aber Daten mit Hilfe eines POST-Requests im Body-Teil der Anfrage mitschicken. Diesen
sogenannen Payload generieren wir dynamisch und zwar so, dass er mit jedem Aufruf grösser wird. Die benötigten
Daten generieren wir mittels _uuidgen_. Dabei handelt es sich um einen Befehl, der eine _ascii-ID_ generiert.
Aneinandergehängt erhalten wir eine Menge Daten. (Falls es zu einer Fehlermeldung kommt, könnte es sein, dass
der Befehl _uuidgen_ nicht vorhanden ist. In diesem Fall wäre das Paket _uuid_ zu installieren.


Die Bearbeitung dieser Zeile dürfte ein, zwei Minuten dauern. Als Resultat sehen wir folgendes im Logfile:

```bash
127.0.0.1 - - [2015-10-03 05:54:09.090117] "GET /index.html?n=1a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 534 1485 -% 446 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.133625] "GET /index.html?n=2a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 534 1485 -% 436 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.179561] "GET /index.html?n=3a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 534 1485 -% 411 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.223015] "GET /index.html?n=4a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 534 1485 -% 413 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.266520] "GET /index.html?n=5a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 534 1485 -% 413 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.310221] "GET /index.html?n=6a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 534 1485 -% 413 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.353847] "GET /index.html?n=7a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 534 1485 -% 421 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.397234] "GET /index.html?n=8a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 534 1485 -% 408 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.440755] "GET /index.html?n=9a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 534 1485 -% 406 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.484324] "GET /index.html?n=10a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 413 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.527460] "GET /index.html?n=11a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 411 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.570871] "GET /index.html?n=12a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 412 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.614222] "GET /index.html?n=13a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 413 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.657637] "GET /index.html?n=14a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 445 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.701005] "GET /index.html?n=15a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 412 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.744447] "GET /index.html?n=16a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 422 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.787739] "GET /index.html?n=17a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 416 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.831136] "GET /index.html?n=18a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 420 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.874456] "GET /index.html?n=19a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 419 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.917730] "GET /index.html?n=20a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 422 - - - - -
127.0.0.1 - - [2015-10-03 05:54:09.960881] "GET /index.html?n=21a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 417 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.004104] "GET /index.html?n=22a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 408 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.047408] "GET /index.html?n=23a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 423 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.090742] "GET /index.html?n=24a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 413 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.133714] "GET /index.html?n=25a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 430 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.176825] "GET /index.html?n=26a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 415 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.219999] "GET /index.html?n=27a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 446 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.263645] "GET /index.html?n=28a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 412 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.306908] "GET /index.html?n=29a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 408 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.351172] "GET /index.html?n=30a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 449 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.397145] "GET /index.html?n=31a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 415 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.440458] "GET /index.html?n=32a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 419 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.483683] "GET /index.html?n=33a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 420 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.529464] "GET /index.html?n=34a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 515 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.583115] "GET /index.html?n=35a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 628 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.638475] "GET /index.html?n=36a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 410 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.683748] "GET /index.html?n=37a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 451 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.727064] "GET /index.html?n=38a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 418 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.770306] "GET /index.html?n=39a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 421 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.813481] "GET /index.html?n=40a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 471 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.866573] "GET /index.html?n=41a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 448 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.924152] "GET /index.html?n=42a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 568 - - - - -
127.0.0.1 - - [2015-10-03 05:54:10.970115] "GET /index.html?n=43a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 413 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.013452] "GET /index.html?n=44a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 445 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.057181] "GET /index.html?n=45a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 523 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.108020] "GET /index.html?n=46a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 416 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.157339] "GET /index.html?n=47a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 465 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.210087] "GET /index.html?n=48a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 476 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.255414] "GET /index.html?n=49a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 458 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.298710] "GET /index.html?n=50a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 410 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.342002] "GET /index.html?n=51a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 412 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.385796] "GET /index.html?n=52a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 474 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.437934] "GET /index.html?n=53a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 452 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.484871] "GET /index.html?n=54a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 416 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.532164] "GET /index.html?n=55a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 421 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.576373] "GET /index.html?n=56a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 424 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.625497] "GET /index.html?n=57a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 3937 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.676021] "GET /index.html?n=58a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 422 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.721580] "GET /index.html?n=59a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 506 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.771195] "GET /index.html?n=60a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 411 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.814475] "GET /index.html?n=61a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 443 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.857877] "GET /index.html?n=62a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 423 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.901023] "GET /index.html?n=63a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 413 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.949860] "GET /index.html?n=64a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 416 - - - - -
127.0.0.1 - - [2015-10-03 05:54:11.996345] "GET /index.html?n=65a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 446 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.043010] "GET /index.html?n=66a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 444 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.094492] "GET /index.html?n=67a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 549 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.139945] "GET /index.html?n=68a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 413 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.190450] "GET /index.html?n=69a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 556 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.239383] "GET /index.html?n=70a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 459 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.282753] "GET /index.html?n=71a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 410 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.327762] "GET /index.html?n=72a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 471 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.375769] "GET /index.html?n=73a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 412 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.419382] "GET /index.html?n=74a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 417 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.463196] "GET /index.html?n=75a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 410 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.507089] "GET /index.html?n=76a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 411 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.553814] "GET /index.html?n=77a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 460 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.597165] "GET /index.html?n=78a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 408 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.640322] "GET /index.html?n=79a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 422 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.683549] "GET /index.html?n=80a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 412 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.726859] "GET /index.html?n=81a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 427 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.770189] "GET /index.html?n=82a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 415 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.813490] "GET /index.html?n=83a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 472 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.856534] "GET /index.html?n=84a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 422 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.899494] "GET /index.html?n=85a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 410 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.946169] "GET /index.html?n=86a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 532 - - - - -
127.0.0.1 - - [2015-10-03 05:54:12.991259] "GET /index.html?n=87a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 417 - - - - -
127.0.0.1 - - [2015-10-03 05:54:13.036759] "GET /index.html?n=88a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 405 - - - - -
127.0.0.1 - - [2015-10-03 05:54:13.081440] "GET /index.html?n=89a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 477 - - - - -
127.0.0.1 - - [2015-10-03 05:54:13.129467] "GET /index.html?n=90a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 503 - - - - -
127.0.0.1 - - [2015-10-03 05:54:13.183269] "GET /index.html?n=91a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 421 - - - - -
127.0.0.1 - - [2015-10-03 05:54:13.233710] "GET /index.html?n=92a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 458 - - - - -
127.0.0.1 - - [2015-10-03 05:54:13.278141] "GET /index.html?n=93a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 470 - - - - -
127.0.0.1 - - [2015-10-03 05:54:13.325932] "GET /index.html?n=94a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 419 - - - - -
127.0.0.1 - - [2015-10-03 05:54:13.371602] "GET /index.html?n=95a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 401 - - - - -
127.0.0.1 - - [2015-10-03 05:54:13.416067] "GET /index.html?n=96a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 406 - - - - -
127.0.0.1 - - [2015-10-03 05:54:13.467033] "GET /index.html?n=97a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 539 - - - - -
127.0.0.1 - - [2015-10-03 05:54:13.520931] "GET /index.html?n=98a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 431 - - - - -
127.0.0.1 - - [2015-10-03 05:54:13.568819] "GET /index.html?n=99a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 535 1485 -% 453 - - - - -
127.0.0.1 - - [2015-10-03 05:54:13.613138] "GET /index.html?n=100a HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 536 1485 -% 470 - - - - -
127.0.0.1 - - [2015-10-03 05:55:08.192381] "POST /index.html?n=1b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 648 1485 -% 431 - - - - -
127.0.0.1 - - [2015-10-03 05:55:08.244061] "POST /index.html?n=2b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 685 1485 -% 418 - - - - -
127.0.0.1 - - [2015-10-03 05:55:08.294934] "POST /index.html?n=3b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 723 1485 -% 428 - - - - -
127.0.0.1 - - [2015-10-03 05:55:08.345959] "POST /index.html?n=4b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 760 1485 -% 466 - - - - -
127.0.0.1 - - [2015-10-03 05:55:08.396783] "POST /index.html?n=5b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 797 1485 -% 418 - - - - -
127.0.0.1 - - [2015-10-03 05:55:08.447396] "POST /index.html?n=6b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 834 1485 -% 423 - - - - -
127.0.0.1 - - [2015-10-03 05:55:08.498101] "POST /index.html?n=7b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 871 1485 -% 429 - - - - -
127.0.0.1 - - [2015-10-03 05:55:08.548684] "POST /index.html?n=8b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 908 1485 -% 417 - - - - -
127.0.0.1 - - [2015-10-03 05:55:08.600923] "POST /index.html?n=9b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 945 1485 -% 424 - - - - -
127.0.0.1 - - [2015-10-03 05:55:08.651712] "POST /index.html?n=10b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 983 1485 -% 436 - - - - -
127.0.0.1 - - [2015-10-03 05:55:08.702620] "POST /index.html?n=11b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1020 1485 -% 428 - - - - -
127.0.0.1 - - [2015-10-03 05:55:08.753260] "POST /index.html?n=12b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1057 1485 -% 439 - - - - -
127.0.0.1 - - [2015-10-03 05:55:08.803847] "POST /index.html?n=13b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1094 1485 -% 424 - - - - -
127.0.0.1 - - [2015-10-03 05:55:08.854720] "POST /index.html?n=14b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1131 1485 -% 417 - - - - -
127.0.0.1 - - [2015-10-03 05:55:08.905325] "POST /index.html?n=15b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1168 1485 -% 450 - - - - -
127.0.0.1 - - [2015-10-03 05:55:08.956204] "POST /index.html?n=16b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1205 1485 -% 414 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.007565] "POST /index.html?n=17b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1242 1485 -% 417 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.058787] "POST /index.html?n=18b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1279 1485 -% 418 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.109967] "POST /index.html?n=19b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1316 1485 -% 422 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.160955] "POST /index.html?n=20b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1353 1485 -% 416 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.211941] "POST /index.html?n=21b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1390 1485 -% 415 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.263858] "POST /index.html?n=22b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1427 1485 -% 416 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.315355] "POST /index.html?n=23b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1464 1485 -% 419 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.368451] "POST /index.html?n=24b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1501 1485 -% 427 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.422182] "POST /index.html?n=25b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1538 1485 -% 424 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.476593] "POST /index.html?n=26b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1575 1485 -% 466 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.534756] "POST /index.html?n=27b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1613 1485 -% 410 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.588418] "POST /index.html?n=28b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1701 1539 -% 771 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.641792] "POST /index.html?n=29b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1738 1539 -% 768 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.695003] "POST /index.html?n=30b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1775 1539 -% 755 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.747278] "POST /index.html?n=31b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1812 1539 -% 766 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.800173] "POST /index.html?n=32b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1849 1539 -% 763 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.851537] "POST /index.html?n=33b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1886 1539 -% 783 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.903471] "POST /index.html?n=34b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1923 1539 -% 772 - - - - -
127.0.0.1 - - [2015-10-03 05:55:09.955182] "POST /index.html?n=35b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1960 1539 -% 776 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.011663] "POST /index.html?n=36b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 1997 1539 -% 780 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.063837] "POST /index.html?n=37b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2034 1539 -% 770 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.124744] "POST /index.html?n=38b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2071 1539 -% 1393 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.182238] "POST /index.html?n=39b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2108 1539 -% 801 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.233935] "POST /index.html?n=40b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2145 1539 -% 791 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.286021] "POST /index.html?n=41b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2182 1539 -% 784 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.338986] "POST /index.html?n=42b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2219 1539 -% 785 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.392424] "POST /index.html?n=43b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2256 1539 -% 793 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.445391] "POST /index.html?n=44b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2293 1539 -% 813 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.498816] "POST /index.html?n=45b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2330 1539 -% 797 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.555547] "POST /index.html?n=46b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2367 1539 -% 832 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.607887] "POST /index.html?n=47b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2404 1539 -% 835 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.659831] "POST /index.html?n=48b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2441 1539 -% 834 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.712089] "POST /index.html?n=49b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2478 1539 -% 799 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.764404] "POST /index.html?n=50b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2515 1539 -% 804 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.818158] "POST /index.html?n=51b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2552 1539 -% 855 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.873327] "POST /index.html?n=52b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2589 1539 -% 849 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.927217] "POST /index.html?n=53b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2626 1539 -% 804 - - - - -
127.0.0.1 - - [2015-10-03 05:55:10.980241] "POST /index.html?n=54b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2663 1539 -% 1093 - - - - -
127.0.0.1 - - [2015-10-03 05:55:11.034181] "POST /index.html?n=55b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2700 1539 -% 857 - - - - -
127.0.0.1 - - [2015-10-03 05:55:11.089734] "POST /index.html?n=56b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2737 1539 -% 836 - - - - -
127.0.0.1 - - [2015-10-03 05:55:11.143863] "POST /index.html?n=57b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2774 1539 -% 823 - - - - -
127.0.0.1 - - [2015-10-03 05:55:11.196211] "POST /index.html?n=58b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2811 1539 -% 817 - - - - -
127.0.0.1 - - [2015-10-03 05:55:11.249333] "POST /index.html?n=59b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2848 1539 -% 900 - - - - -
127.0.0.1 - - [2015-10-03 05:55:11.304195] "POST /index.html?n=60b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2885 1539 -% 836 - - - - -
127.0.0.1 - - [2015-10-03 05:55:11.358419] "POST /index.html?n=61b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2922 1539 -% 827 - - - - -
127.0.0.1 - - [2015-10-03 05:55:11.413544] "POST /index.html?n=62b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2959 1539 -% 872 - - - - -
127.0.0.1 - - [2015-10-03 05:55:11.465599] "POST /index.html?n=63b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 2996 1539 -% 895 - - - - -
127.0.0.1 - - [2015-10-03 05:55:11.517771] "POST /index.html?n=64b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3033 1539 -% 862 - - - - -
127.0.0.1 - - [2015-10-03 05:55:11.569863] "POST /index.html?n=65b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3070 1539 -% 831 - - - - -
127.0.0.1 - - [2015-10-03 05:55:11.629315] "POST /index.html?n=66b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3107 1539 -% 1048 - - - - -
127.0.0.1 - - [2015-10-03 05:55:11.692200] "POST /index.html?n=67b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3144 1539 -% 869 - - - - -
127.0.0.1 - - [2015-10-03 05:55:11.744763] "POST /index.html?n=68b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3181 1539 -% 827 - - - - -
127.0.0.1 - - [2015-10-03 05:55:11.800476] "POST /index.html?n=69b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3218 1539 -% 828 - - - - -
127.0.0.1 - - [2015-10-03 05:55:11.852595] "POST /index.html?n=70b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3255 1539 -% 844 - - - - -
127.0.0.1 - - [2015-10-03 05:55:11.904921] "POST /index.html?n=71b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3292 1539 -% 935 - - - - -
127.0.0.1 - - [2015-10-03 05:55:11.957216] "POST /index.html?n=72b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3329 1539 -% 881 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.010008] "POST /index.html?n=73b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3366 1539 -% 843 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.062213] "POST /index.html?n=74b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3403 1539 -% 844 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.114455] "POST /index.html?n=75b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3440 1539 -% 877 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.168195] "POST /index.html?n=76b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3477 1539 -% 852 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.220147] "POST /index.html?n=77b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3514 1539 -% 851 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.272479] "POST /index.html?n=78b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3551 1539 -% 845 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.327103] "POST /index.html?n=79b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3588 1539 -% 883 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.386224] "POST /index.html?n=80b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3625 1539 -% 900 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.442225] "POST /index.html?n=81b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3662 1539 -% 890 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.496991] "POST /index.html?n=82b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3699 1539 -% 958 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.551043] "POST /index.html?n=83b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3736 1539 -% 861 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.606645] "POST /index.html?n=84b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3773 1539 -% 849 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.659519] "POST /index.html?n=85b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3810 1539 -% 877 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.712401] "POST /index.html?n=86b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3847 1539 -% 876 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.765312] "POST /index.html?n=87b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3884 1539 -% 939 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.817843] "POST /index.html?n=88b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3921 1539 -% 861 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.870316] "POST /index.html?n=89b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3958 1539 -% 862 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.923036] "POST /index.html?n=90b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 3995 1539 -% 861 - - - - -
127.0.0.1 - - [2015-10-03 05:55:12.975815] "POST /index.html?n=91b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 4032 1539 -% 871 - - - - -
127.0.0.1 - - [2015-10-03 05:55:13.028428] "POST /index.html?n=92b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 4069 1539 -% 872 - - - - -
127.0.0.1 - - [2015-10-03 05:55:13.081251] "POST /index.html?n=93b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 4106 1539 -% 932 - - - - -
127.0.0.1 - - [2015-10-03 05:55:13.134076] "POST /index.html?n=94b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 4143 1539 -% 883 - - - - -
127.0.0.1 - - [2015-10-03 05:55:13.189013] "POST /index.html?n=95b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 4180 1539 -% 925 - - - - -
127.0.0.1 - - [2015-10-03 05:55:13.241741] "POST /index.html?n=96b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 4217 1539 -% 883 - - - - -
127.0.0.1 - - [2015-10-03 05:55:13.294453] "POST /index.html?n=97b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 4254 1539 -% 882 - - - - -
127.0.0.1 - - [2015-10-03 05:55:13.347215] "POST /index.html?n=98b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 4291 1539 -% 866 - - - - -
127.0.0.1 - - [2015-10-03 05:55:13.400345] "POST /index.html?n=99b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 4328 1539 -% 878 - - - - -
127.0.0.1 - - [2015-10-03 05:55:13.453047] "POST /index.html?n=100b HTTP/1.1" 200 45 "-" "curl/7.35.0" www.example.com 127.0.0.1 443 - - "-" - TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 4366 1539 -% 910 - - - - -
```

Wie oben vorhergesagt sind noch sehr viele Werte leer, oder durch _-_ gekennzeichnet. Aber wir sehen, dass wir den Server localhost auf Port 80 angesprochen haben und dass die Grösse des Requests mit jedem Request zunahm und zuletzt beinahe 4K, also 4096 Bytes, betrug. Mit diesem einfachen Logfile lassen sich bereits einfache Auswertungen durchführen.

###Schritt 7: Einfache Auswertungen mit dem Logformat Extended durchführen

Wer das Beispiel-Logfile genau ansieht, wird erkennen, dass die Dauer der Requests nicht ganz sauber verteilt ist. Es gibt zwei Ausreisser. Wir können das wie folgt identifizieren:

```bash
$> egrep -o "\% [0-9]+ " logs/access.log | cut -b3- | tr -d " " | sort -n
```

Mit diesem Einzeiler schneiden wir den Wert, der die Dauer eines Requests angibt, aus dem Logfile heraus. Wir benützen das Prozentzeichen des Deflate-Wertes als Anker für eine einfache Regular Expression und nehmen die darauf folgende Zahl. _egrep_ bietet sich an, weil wir mit RegEx arbeiten wollen, die Option _-o_ führt dazu, dass nicht die gesamte Zeile, sondern nur der Treffer selbst ausgegeben wird. Das ist sehr hilfreich.
Ein Detail, das uns zukünftige Fehler verhindern hilft ist das Leerzeichen nach dem Pluszeichen. Es nimmt nur diejenigen Werte, die auf die Zahl ein Leerzeichen folgen lassen. Das Problem ist der User-Agent, der in unserem Logformat ja auch vorkommt und der bisweilen auch Prozentzeichen enthält. Wir gehen hier davon aus, dass zwar im User-Agent Prozentzeichen gefolgt von Leerschlag und einer Ganzzahl folgen können. Dass danach aber kein weitere Leerschlag folgt und diese Kombination nur im hinteren Teil der Logzeile nach dem Prozentzeichen der _Deflate-Platzeinsparungen_ vorkommt. Dann schneiden wir mittels _cut_ so, dass nur das dritte und die folgenden Zeichen ausgegeben werden und schliesslich trennen wir noch mit _tr_ das abschliessende Leerzeichen (siehe Regex) ab. Dann sind wir bereit für das numerische Sortieren. Das liefert folgendes Resultat:

```bash
...
925
932
935
939
958
1048
1093
1393
3937
```

In unserem Beispiel stechen vier Werte mit einer Dauer von über 1000 Microsekunden, also mehr als einer Millisekunde heraus, drei davon sind noch im Rahmen, aber einer ist mit 4 Millisekunden klar ein statistischer Ausreisser und steht den anderen Werten gegenüber klar im Abseits.

Wir wissen, dass wir je 100 GET und 100 POST Requests gestellt haben. Aber zählen wir sie übungshalber dennoch einmal aus:

```bash
$> egrep -c "\"GET " logs/access.log 
```

Dies sollte 100 GET Requests ergeben:

```bash
100
```

Wir können GET und POST auch einander gegenüber stellen. Wir tun dies folgendermassen:

```bash
$> egrep  -o '"(GET|POST)' logs/access.log | cut -b2- | sort | uniq -c
```

Hier filtern wir die GET und die POST Requests anhand der Methode, die auf ein Anführungszeichen folgt heraus. Dann schneiden wir das Anführungszeichen ab, sortieren und zählen gruppiert aus:

```bash
    100 GET 
    100 POST 
```

Soweit zu diesen ersten Fingerübungen. In einem späteren Tutorial werden wir komplexere und interessantere Auswertungen vornehmen. Dabei werden wir auch auf ein Skript zurückgreifen, welches das Filtern nach einzelnen Feldern erheblich erleichtert. Dafür müssen wir das Logfile aber erst einmal mit interessanteren Werten füllen.

###Schritt 8 (Bonus): Weitere Request- und Response-Header in zusätzlichem Logfile mitschreiben

Im Arbeitsalltag ist man oft nach bestimmten Requests auf der Suche oder man ist sich nicht sicher, welche Requests einen Fehler verursachen. Da erweist es sich oft als hilfreich, wenn man bestimmte zusätzliche Werte mit ins Logfile schreiben kann. Beliebige Request- und Response-Header sowie Umgebungs-Variabeln lassen sich sehr leicht mitschreiben. Unser Logformat macht davon rege Gebrauch.

Bei den Werten _\"%{Referer}i\"_ sowie _\"%{User-Agent}i\"_ handelt es sich um Request-Header-Felder. Bei der Balancer-Route _%{BALANCER_WORKER_ROUTE}e_ haben wir es mit einer Umgebungs-Variablen zu tun. Das Muster wird deutlich: _%{Header/Variable}<Domäne>_. Request-Header sind der Domäne _i_ zugeordnet. Environment-Variabeln der Domäne _e_ und die Response-Header der Domäne _o_.

Schreiben wir zu Debug-Zwecken also ein zusätzliches Logfile. Wir benützen nicht mehr die _LogFormat_-Direktive, sondern definieren das Format zusammen mit dem File. Dies ist ein Shortcut, wenn man ein bestimmtes Format nur ein Mal verwenden möchte.

```bash
CustomLog logs/access-debug.log "%t \"%r\" %{Accept}i %{Content-Type}o"
```

Mit diesem zusätzlichen Logfile sehen wir, welche Wünsche in Bezug auf die Content-Types der Client äusserte, und was unser Server tatsächlich lieferte. Normalerweise klappt dieses Zusammenspiel zwischen Client und Server sehr gut. Aber in der Praxis gibt es da schon mal Unstimmigkeiten; da ist ein zusätzliches Logfile dieser Art sehr hilfreich bei der Fehlersuche.

Der Output könnte dann etwa wie folgt aussehen:

```bash
[07/Dec/2011:16:55:40 +0100] "GET /index.html HTTP/1.1" */* text/html
[07/Dec/2011:16:56:04 +0100] "GET /index.html HTTP/1.1" text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8 text/html
[07/Dec/2011:16:56:06 +0100] "GET /index.html HTTP/1.1" text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8 text/html
[07/Dec/2011:16:56:07 +0100] "GET /index.html HTTP/1.1" text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8 text/html
```


###Verweise

* [Dokumentation des Apache-Moduls Log-Config](http://httpd.apache.org/docs/current/mod/mod_log_config.html)
* [Dokumentation des Apache-Moduls SSL](http://httpd.apache.org/docs/current/mod/mod_ssl.html)

