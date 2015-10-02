<div class="floatbox">
Titel: Das Zugriffslog ausbauen<br/>
Author: FIXME: <a href="mailto:christian.folini@netnea.com">Christian Folini</a><br/>
Tutorial Nr: 5<br/>
Erscheinungsdatum: 2. Februar 2012<br/>
Schwierigkeit: Einfach<br/>
Dauer: 1/2h<br/>
</div>
###Was machen wir?
Wir definieren ein stark erweitertes Logformat, um den Verkehr besser überwachen zu können.

###Warum tun wir das?

In der gebräuchlichen Konfiguration des Apache Webservers wird ein
Logformat eingesetzt, das nur die nötigsten Informationen zu den
Zugriffen der verschiedenen Clients mitschreibt. In der Praxis werden
oft zusätzliche Informationen benötigt, die sich leicht im Zugriffslog
(Accesslog) des Servers notieren lassen. 


###Voraussetzungen

* Ein Apache Webserver, idealerweise mit einem File-Layout wie bei FIXME: <a href="?q=apache_tutorial_1_apache_compilieren">Lektion 1 (Compilieren eines Apache Servers)</a>, erstellt.
* Verständnis der minimalen Konfiguration in FIXME: <a href="?q=apache_tutorial_2_apache_minimal_konfigurieren">Lektion 2 (Apache minimal Konfigurieren)</a>.


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
[25/Nov/2011:08:51:22 +0100]
```

Hier meint es also den 25. November 2011, 8 Uhr 51, 1 Stunde vor der
Standardzeit. Das Format der Uhrzeit selbst lässt sich gegebenenfalls
anpassen. Dies geschieht nach dem Muster _%{format}t_, wobei
_format_ der Spezifikation von _strftime(3)_ folgt. Sehen
wir uns auch dazu ein Beispiel an:

```bash
%{[%Y%m%d-%H:%M:%S %z (%s)]}t
```

In diesem Beispiel drehen bringen wir das Datum in die Reihenfolge
_Jahr-Monat-Tag_, um eine bessere Sortierbarkeit zu erreichen. Und
nach der Abweichung von der Standardzeit fügen wir die Zeit in Sekunden
seit dem Start der Unixepoche im Januar 1970 ein. Dies ist ein durch 
ein Skript leichter les- und interpretierbares Format.

Dieses Beispiel bringt uns Einträgen nach folgendem Muster:

```bash
[20111125-09:34:33 +0100 (1322210073)]
```

Soweit zu _%t_. In der Praxis ist es nicht unüblich, mit dem
Zeitformat herumzuspielen. Im Einzelfall kann es aber sehr hilfreich
sein.

Damit kommen wir zu _%r_ und damit zur Request-Zeile. Hierbei
handelt es sich um die erste Zeile des HTTP-Requests, wie er vom Client 
an den Server gesendet wurde. Auf der Request-Zeile übermittelt der
Client dem Server die Identifikation der Resource, die er verlangt.

Konkret folgt die Zeile diesem Muster:

```bash
Methode URI Protokoll
```

In der Praxis lautet ein einfaches Beispiel wie folgt:

```bash
GET /index.html HTTP/1.1
```

Es wird also die _GET_-Methode angewendet. Dann folgt ein
Leerschlag, dann der absolute Pfad auf die Resource auf dem Server. Hier
die Index-Datei. Optional kann der Client bekanntlich noch einen
_Query-String_ an dem Pfad anhängen. Dieser _Query-String_
wird im Logformat auch wiedergegeben. Schliesslich das Protokoll, das
in aller Regel HTTP in der Version 1.1 lautet. Zum Teil wird aber
gerade von Agents, also automatisierten Skripten, die Version 1.0
verwendet.

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
gibt die Zahl der im Content-Length Response Headers angekündigten Bytes.  Bei einer Anfrage
an _http://www.example.com/index.html_ entspricht dieser Wert der Grösse
der Datei _index.html_. Die ebenfalls übertragenen _Response-Header_ werden
nicht angegeben. Dazu kommt, dass diese Zahl nur eine Ankündigung wiedergibt und keine
Garantie darstellt, dass diese Daten auch wirklich übertragen wurden.


###Schritt 2: Logformat Combined verstehen

Das Logformat _combined_ baut auf dem Logformat _common_ auf und
erweitert es um zwei Elemente.

```bash
LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"" combined
...
CustomLog logs/access.log combined
```
 
Das Element _\"%{Referer}i\"_ bezeichnet den Referrer. Er wird in
Anführungszeichen wiedergegeben. Der Referrer bezeichnet diejenige
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
tatsächlich kann er aber beliebige Informationen senden.

_\"%{User-agent}i\"_ schliesslich meint den sogenannten User-Agent des Clients,
der wiederum in Anführungszeichen gesetzt wird.
Auch dies ist wieder ein Wert, der durch den Client kontrolliert wird,
und auf den wir uns nicht zu sehr verlassen sollten. Mit dem User-Agent
ist die Browser-Software des Clients gemeint; normalerweise angereichert
um die Version und diverse installierte Plugins. Das führt zu sehr
langen User-Agent-Einträgen und kann im Einzelfall so viele
Informationen enhalten, dass ein individueller Client sich darüber
eindeutig identifizieren lässt, weil er eine besondere Kombination
von verschiedenen Zusatzmodulen in bestimmten Versionen besitzt.

###Schritt 3: Modul Logio aktivieren

Mit dem _combined_ Format haben wir das wichtigste Apache
Logformat kennengelernt. Um die alltägliche Arbeit zu erleichtern
reichen die dargestellten Werte aber nicht. Weitere Informationen werden
deshalb mit Vorteil im Logfile mitgeschrieben.

Es bietet sich an, auf sämtlichen Servern dasselbe Logformat zu
verwenden. Anstatt jetzt also ein, zwei weitere Werte zu propagieren,
beschreibt diese Anleitung ein sehr umfassendes Logformat, das
sich in der Praxis in verschiedenen Szenarien bewährt hat.

Um das in der Folge beschriebene Logformat konfigurieren zu können,
muss aber zunächst das Modul _Logio_ aktiviert werden.

Wenn der Server wie in FIXME: <a href="?q=apache_tutorial_1_apache_compilieren">Tutorial 1</a> beschrieben
compiliert wurde, dann ist das Modul bereits vorhanden und muss nur noch in der Liste
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
darstellen. Mit dem eben aktivierten Modul _Logio_ klappt das nicht.
Wenn wir dessen Werte ansprechen, ohne dass sie vorhanden wären, stürzt
der Server ab.

In den folgenden Anleitungen werden wir diese Werte dann nach und nach
füllen. Weil es aber wie oben erklärt sinnvoll ist, überall dasselbe Logformat zu
verwenden, greifen wir hier mit der nun folgenden Konfiguration bereits etwas vor.

Wir gehen vom _Combined_-Format aus und erweitern es nach rechts. Dies hat
den Vorteil, dass die erweiterten Logfiles in vielen Standard-Tools weiterhin
lesbar sind, denn die zusätzlichen Werte werden einfach ignoriert. Ferner ist
es sehr leicht, die erweiterten Logfiles in die Basis zurückzuübersetzen.

Wir definieren das Logformat wie folgt:

```bash
LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %v %A %p %R %{BALANCER_WORKER_ROUTE}e %X \"%{cookie}n\" %{UNIQUE_ID}e %I %O %{ratio}n%% %D" extended

...

CustomLog		logs/access.log extended

```

###Schritt 5: Neues Logformat Extended verstehen

Das neue Logformat erweitert die Zugriffsprotokolle um zwölf Werte. Schauen wir sie uns
nacheinander an.

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

_%{BALANCER_WORKER_ROUTE}e_ hat auch mit dem Weitergeben von Anfragen zu tun.
Wenn wir zwischen mehreren Zielserver abwechseln belegt dieser Wert, wohin die
Anfrage geschickt wurde.

_%X_ gibt den Status der TCP-Verbindung nach Abschluss der Anfrage wieder. Es sind drei Werte möglich:
Die Verbindung ist geschlossen (_-_), die Verbindung wird mittels _Keep-Alive_ offen gehalten (_+_)
oder aber die Verbindung wurde abgebrochen bevor der Request abgeschlossen werden konnte (_X_).

Mit _\"%{cookie}n\"_ folgt ein Wert, der dem User-Tracking dient. Damit können wir einen Client mittels
eines Cookies identifizieren und ihn zu einem späteren Zeitpunkt wiedererkennen - sofern er das Cookie
immer noch trägt.

Der Wert _%{UNIQUE_ID}e_ ist ein sehr hilfreicher Wert. Für jeden Request wird damit auf dem Server
eine eindeutige Identifizierung kreiert. Wenn wir den Wert etwa auf einer Fehlerseite ausgeben, dann lässt
sich ein Request im Logfile aufgrund eines Screenshots bequem identifizieren - und im Idealfall die gesamte Session 
aufgrund des User-Tracking-Cookies nachvollziehen.

Mit _%I_ und _%O_ folgen die beiden Werte, welche durch das Modul _Logio_ definiert werden.
Es ist die gesamte Zahl der Bytes im Request und die gesamte Zahl der Bytes in der Response.
Wir kennen bereits _%b_ für die Summer der Bytes im Response-Body. _%O_ ist hier etwas genauer
und hilft zu erkennen, wenn die Anfrage oder ihre Antwort entsprechende Grössen-Limiten verletzte.

_%{ratio}n%%_ bedeutet die Prozentzahl der Kompression der übermittelten Daten, welche durch die Anwendung des
Modules _Deflate_ erreicht werden konnte. Dies ist für den Moment noch ohne Belang.

_%D_ gibt die komplette Dauer des Requests in Microsekunden wieder. Gemessen wird vom Erhalt
der Request-Zeile bis zum Moment, wenn der letzte Teil der Antwort den Server verlässt.

###Schritt 6: Ausprobieren und Logdatei füllen

Konfigurieren wir das Zugriffslog wie oben beschrieben und beschäftigen wir den Server etwas!

Wir könnten dazu _Apache Bench_ wie in FIXME: <a href="?q=apache_tutorial_2_apache_minimal_konfigurieren">Tutorial 2</a> beschrieben
verwenden, aber das würde ein sehr einförmiges Logfile ergeben. Mit den folgenden Einzeilern bringen
wir etwas Abwechslung hinein.

```bash
$> for N in {1..100}; do curl --silent http://localhost/index.html?n=${N}a >/dev/null; done
$> for N in {1..100}; do PAYLOAD=$(for K in $(seq $N); do uuidgen; done | xargs); curl --silent --data "payload=$PAYLOAD" http://localhost/index.html?n=${N}b >/dev/null; done
```

Die Bearbeitung dieser Zeile dürfte ein, zwei Minuten dauern. Als Resultat sehen wir folgendes im Logfile:

```bash
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=1a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 163 261 -% 1126
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=2a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 163 261 -% 1108
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=3a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 163 261 -% 1208
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=4a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 163 261 -% 568
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=5a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 163 261 -% 578
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=6a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 163 261 -% 615
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=7a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 163 261 -% 616
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=8a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 163 261 -% 510
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=9a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 163 261 -% 534
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=10a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 540
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=11a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 633
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=12a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 595
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=13a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 526
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=14a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 528
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=15a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 433
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=16a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 652
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=17a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 495
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=18a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 529
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=19a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 444
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=20a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 519
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=21a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 529
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=22a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 537
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=23a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 580
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=24a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 536
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=25a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 516
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=26a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 530
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=27a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 572
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=28a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 520
127.0.0.1 - - [07/Dec/2011:16:34:19 +0100] "GET /index.html?n=29a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 456
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=30a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 845
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=31a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 584
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=32a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 531
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=33a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 554
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=34a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 527
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=35a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 538
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=36a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 528
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=37a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 584
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=38a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 609
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=39a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 516
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=40a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 519
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=41a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 512
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=42a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 516
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=43a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 522
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=44a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 523
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=45a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 558
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=46a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 516
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=47a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 516
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=48a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 518
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=49a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 595
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=50a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 523
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=51a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 519
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=52a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 517
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=53a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 549
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=54a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 558
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=55a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 514
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=56a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 587
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=57a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 514
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=58a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 519
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=59a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 524
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=60a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 520
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=61a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 514
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=62a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 581
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=63a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 532
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=64a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 519
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=65a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 530
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=66a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 516
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=67a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 442
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=68a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 516
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=69a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 588
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=70a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 527
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=71a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 522
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=72a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 515
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=73a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 517
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=74a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 513
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=75a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 627
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=76a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 552
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=77a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 532
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=78a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 500
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=79a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 471
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=80a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 527
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=81a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 499
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=82a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 506
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=83a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 441
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=84a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 529
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=85a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 495
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=86a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 568
127.0.0.1 - - [07/Dec/2011:16:34:20 +0100] "GET /index.html?n=87a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 621
127.0.0.1 - - [07/Dec/2011:16:34:21 +0100] "GET /index.html?n=88a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 656
127.0.0.1 - - [07/Dec/2011:16:34:21 +0100] "GET /index.html?n=89a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 516
127.0.0.1 - - [07/Dec/2011:16:34:21 +0100] "GET /index.html?n=90a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 510
127.0.0.1 - - [07/Dec/2011:16:34:21 +0100] "GET /index.html?n=91a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 824
127.0.0.1 - - [07/Dec/2011:16:34:21 +0100] "GET /index.html?n=92a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 501
127.0.0.1 - - [07/Dec/2011:16:34:21 +0100] "GET /index.html?n=93a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 490
127.0.0.1 - - [07/Dec/2011:16:34:21 +0100] "GET /index.html?n=94a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 601
127.0.0.1 - - [07/Dec/2011:16:34:21 +0100] "GET /index.html?n=95a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 518
127.0.0.1 - - [07/Dec/2011:16:34:21 +0100] "GET /index.html?n=96a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 669
127.0.0.1 - - [07/Dec/2011:16:34:21 +0100] "GET /index.html?n=97a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 515
127.0.0.1 - - [07/Dec/2011:16:34:21 +0100] "GET /index.html?n=98a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 494
127.0.0.1 - - [07/Dec/2011:16:34:21 +0100] "GET /index.html?n=99a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 164 261 -% 492
127.0.0.1 - - [07/Dec/2011:16:34:21 +0100] "GET /index.html?n=100a HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 165 261 -% 528
127.0.0.1 - - [07/Dec/2011:16:34:36 +0100] "POST /index.html?n=1b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 277 261 -% 607
127.0.0.1 - - [07/Dec/2011:16:34:36 +0100] "POST /index.html?n=2b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 314 261 -% 556
127.0.0.1 - - [07/Dec/2011:16:34:36 +0100] "POST /index.html?n=3b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 352 261 -% 702
127.0.0.1 - - [07/Dec/2011:16:34:36 +0100] "POST /index.html?n=4b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 389 261 -% 511
127.0.0.1 - - [07/Dec/2011:16:34:36 +0100] "POST /index.html?n=5b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 426 261 -% 537
127.0.0.1 - - [07/Dec/2011:16:34:36 +0100] "POST /index.html?n=6b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 463 261 -% 722
127.0.0.1 - - [07/Dec/2011:16:34:36 +0100] "POST /index.html?n=7b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 500 261 -% 503
127.0.0.1 - - [07/Dec/2011:16:34:36 +0100] "POST /index.html?n=8b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 537 261 -% 499
127.0.0.1 - - [07/Dec/2011:16:34:37 +0100] "POST /index.html?n=9b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 574 261 -% 519
127.0.0.1 - - [07/Dec/2011:16:34:37 +0100] "POST /index.html?n=10b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 612 261 -% 605
127.0.0.1 - - [07/Dec/2011:16:34:37 +0100] "POST /index.html?n=11b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 649 261 -% 531
127.0.0.1 - - [07/Dec/2011:16:34:37 +0100] "POST /index.html?n=12b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 686 261 -% 506
127.0.0.1 - - [07/Dec/2011:16:34:37 +0100] "POST /index.html?n=13b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 723 261 -% 499
127.0.0.1 - - [07/Dec/2011:16:34:37 +0100] "POST /index.html?n=14b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 760 261 -% 446
127.0.0.1 - - [07/Dec/2011:16:34:37 +0100] "POST /index.html?n=15b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 797 261 -% 625
127.0.0.1 - - [07/Dec/2011:16:34:37 +0100] "POST /index.html?n=16b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 834 261 -% 502
127.0.0.1 - - [07/Dec/2011:16:34:38 +0100] "POST /index.html?n=17b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 871 261 -% 520
127.0.0.1 - - [07/Dec/2011:16:34:38 +0100] "POST /index.html?n=18b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 908 261 -% 520
127.0.0.1 - - [07/Dec/2011:16:34:38 +0100] "POST /index.html?n=19b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 945 261 -% 523
127.0.0.1 - - [07/Dec/2011:16:34:38 +0100] "POST /index.html?n=20b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 982 261 -% 508
127.0.0.1 - - [07/Dec/2011:16:34:38 +0100] "POST /index.html?n=21b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1019 261 -% 625
127.0.0.1 - - [07/Dec/2011:16:34:39 +0100] "POST /index.html?n=22b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1056 261 -% 525
127.0.0.1 - - [07/Dec/2011:16:34:39 +0100] "POST /index.html?n=23b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1093 261 -% 552
127.0.0.1 - - [07/Dec/2011:16:34:39 +0100] "POST /index.html?n=24b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1130 261 -% 635
127.0.0.1 - - [07/Dec/2011:16:34:39 +0100] "POST /index.html?n=25b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1167 261 -% 531
127.0.0.1 - - [07/Dec/2011:16:34:39 +0100] "POST /index.html?n=26b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1204 261 -% 529
127.0.0.1 - - [07/Dec/2011:16:34:40 +0100] "POST /index.html?n=27b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1242 261 -% 523
127.0.0.1 - - [07/Dec/2011:16:34:40 +0100] "POST /index.html?n=28b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1301 286 -% 745
127.0.0.1 - - [07/Dec/2011:16:34:40 +0100] "POST /index.html?n=29b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1338 286 -% 969
127.0.0.1 - - [07/Dec/2011:16:34:40 +0100] "POST /index.html?n=30b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1375 286 -% 1035
127.0.0.1 - - [07/Dec/2011:16:34:41 +0100] "POST /index.html?n=31b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1412 286 -% 736
127.0.0.1 - - [07/Dec/2011:16:34:41 +0100] "POST /index.html?n=32b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1449 286 -% 738
127.0.0.1 - - [07/Dec/2011:16:34:41 +0100] "POST /index.html?n=33b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1486 286 -% 944
127.0.0.1 - - [07/Dec/2011:16:34:42 +0100] "POST /index.html?n=34b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1523 286 -% 741
127.0.0.1 - - [07/Dec/2011:16:34:42 +0100] "POST /index.html?n=35b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1560 286 -% 775
127.0.0.1 - - [07/Dec/2011:16:34:42 +0100] "POST /index.html?n=36b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1597 286 -% 888
127.0.0.1 - - [07/Dec/2011:16:34:42 +0100] "POST /index.html?n=37b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1634 286 -% 881
127.0.0.1 - - [07/Dec/2011:16:34:43 +0100] "POST /index.html?n=38b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1671 286 -% 750
127.0.0.1 - - [07/Dec/2011:16:34:43 +0100] "POST /index.html?n=39b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1708 286 -% 922
127.0.0.1 - - [07/Dec/2011:16:34:43 +0100] "POST /index.html?n=40b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1745 286 -% 823
127.0.0.1 - - [07/Dec/2011:16:34:44 +0100] "POST /index.html?n=41b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1782 286 -% 782
127.0.0.1 - - [07/Dec/2011:16:34:44 +0100] "POST /index.html?n=42b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1819 286 -% 861
127.0.0.1 - - [07/Dec/2011:16:34:44 +0100] "POST /index.html?n=43b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1856 286 -% 748
127.0.0.1 - - [07/Dec/2011:16:34:45 +0100] "POST /index.html?n=44b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1893 286 -% 815
127.0.0.1 - - [07/Dec/2011:16:34:45 +0100] "POST /index.html?n=45b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1930 286 -% 996
127.0.0.1 - - [07/Dec/2011:16:34:46 +0100] "POST /index.html?n=46b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 1967 286 -% 783
127.0.0.1 - - [07/Dec/2011:16:34:46 +0100] "POST /index.html?n=47b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2004 286 -% 737
127.0.0.1 - - [07/Dec/2011:16:34:46 +0100] "POST /index.html?n=48b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2041 286 -% 743
127.0.0.1 - - [07/Dec/2011:16:34:47 +0100] "POST /index.html?n=49b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2078 286 -% 789
127.0.0.1 - - [07/Dec/2011:16:34:47 +0100] "POST /index.html?n=50b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2115 286 -% 795
127.0.0.1 - - [07/Dec/2011:16:34:48 +0100] "POST /index.html?n=51b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2152 286 -% 776
127.0.0.1 - - [07/Dec/2011:16:34:48 +0100] "POST /index.html?n=52b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2189 286 -% 1406
127.0.0.1 - - [07/Dec/2011:16:34:48 +0100] "POST /index.html?n=53b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2226 286 -% 805
127.0.0.1 - - [07/Dec/2011:16:34:49 +0100] "POST /index.html?n=54b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2263 286 -% 959
127.0.0.1 - - [07/Dec/2011:16:34:49 +0100] "POST /index.html?n=55b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2300 286 -% 801
127.0.0.1 - - [07/Dec/2011:16:34:50 +0100] "POST /index.html?n=56b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2337 286 -% 753
127.0.0.1 - - [07/Dec/2011:16:34:50 +0100] "POST /index.html?n=57b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2374 286 -% 791
127.0.0.1 - - [07/Dec/2011:16:34:51 +0100] "POST /index.html?n=58b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2411 286 -% 919
127.0.0.1 - - [07/Dec/2011:16:34:51 +0100] "POST /index.html?n=59b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2448 286 -% 1171
127.0.0.1 - - [07/Dec/2011:16:34:52 +0100] "POST /index.html?n=60b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2485 286 -% 1061
127.0.0.1 - - [07/Dec/2011:16:34:52 +0100] "POST /index.html?n=61b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2522 286 -% 867
127.0.0.1 - - [07/Dec/2011:16:34:53 +0100] "POST /index.html?n=62b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2559 286 -% 937
127.0.0.1 - - [07/Dec/2011:16:34:53 +0100] "POST /index.html?n=63b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2596 286 -% 754
127.0.0.1 - - [07/Dec/2011:16:34:54 +0100] "POST /index.html?n=64b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2633 286 -% 767
127.0.0.1 - - [07/Dec/2011:16:34:54 +0100] "POST /index.html?n=65b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2670 286 -% 958
127.0.0.1 - - [07/Dec/2011:16:34:55 +0100] "POST /index.html?n=66b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2707 286 -% 773
127.0.0.1 - - [07/Dec/2011:16:34:55 +0100] "POST /index.html?n=67b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2744 286 -% 748
127.0.0.1 - - [07/Dec/2011:16:34:56 +0100] "POST /index.html?n=68b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2781 286 -% 758
127.0.0.1 - - [07/Dec/2011:16:34:56 +0100] "POST /index.html?n=69b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2818 286 -% 786
127.0.0.1 - - [07/Dec/2011:16:34:57 +0100] "POST /index.html?n=70b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2855 286 -% 865
127.0.0.1 - - [07/Dec/2011:16:34:57 +0100] "POST /index.html?n=71b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2892 286 -% 859
127.0.0.1 - - [07/Dec/2011:16:34:58 +0100] "POST /index.html?n=72b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2929 286 -% 960
127.0.0.1 - - [07/Dec/2011:16:34:58 +0100] "POST /index.html?n=73b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 2966 286 -% 847
127.0.0.1 - - [07/Dec/2011:16:34:59 +0100] "POST /index.html?n=74b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3003 286 -% 1127
127.0.0.1 - - [07/Dec/2011:16:35:00 +0100] "POST /index.html?n=75b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3040 286 -% 788
127.0.0.1 - - [07/Dec/2011:16:35:00 +0100] "POST /index.html?n=76b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3077 286 -% 895
127.0.0.1 - - [07/Dec/2011:16:35:01 +0100] "POST /index.html?n=77b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3114 286 -% 859
127.0.0.1 - - [07/Dec/2011:16:35:01 +0100] "POST /index.html?n=78b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3151 286 -% 874
127.0.0.1 - - [07/Dec/2011:16:35:02 +0100] "POST /index.html?n=79b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3188 286 -% 1439
127.0.0.1 - - [07/Dec/2011:16:35:03 +0100] "POST /index.html?n=80b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3225 286 -% 742
127.0.0.1 - - [07/Dec/2011:16:35:03 +0100] "POST /index.html?n=81b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3262 286 -% 768
127.0.0.1 - - [07/Dec/2011:16:35:04 +0100] "POST /index.html?n=82b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3299 286 -% 747
127.0.0.1 - - [07/Dec/2011:16:35:05 +0100] "POST /index.html?n=83b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3336 286 -% 756
127.0.0.1 - - [07/Dec/2011:16:35:05 +0100] "POST /index.html?n=84b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3373 286 -% 1061
127.0.0.1 - - [07/Dec/2011:16:35:06 +0100] "POST /index.html?n=85b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3410 286 -% 746
127.0.0.1 - - [07/Dec/2011:16:35:07 +0100] "POST /index.html?n=86b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3447 286 -% 1152
127.0.0.1 - - [07/Dec/2011:16:35:07 +0100] "POST /index.html?n=87b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3484 286 -% 784
127.0.0.1 - - [07/Dec/2011:16:35:08 +0100] "POST /index.html?n=88b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3521 286 -% 739
127.0.0.1 - - [07/Dec/2011:16:35:09 +0100] "POST /index.html?n=89b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3558 286 -% 767
127.0.0.1 - - [07/Dec/2011:16:35:09 +0100] "POST /index.html?n=90b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3595 286 -% 799
127.0.0.1 - - [07/Dec/2011:16:35:10 +0100] "POST /index.html?n=91b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3632 286 -% 900
127.0.0.1 - - [07/Dec/2011:16:35:11 +0100] "POST /index.html?n=92b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3669 286 -% 779
127.0.0.1 - - [07/Dec/2011:16:35:12 +0100] "POST /index.html?n=93b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3706 286 -% 984
127.0.0.1 - - [07/Dec/2011:16:35:12 +0100] "POST /index.html?n=94b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3743 286 -% 777
127.0.0.1 - - [07/Dec/2011:16:35:13 +0100] "POST /index.html?n=95b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3780 286 -% 787
127.0.0.1 - - [07/Dec/2011:16:35:14 +0100] "POST /index.html?n=96b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3817 286 -% 757
127.0.0.1 - - [07/Dec/2011:16:35:15 +0100] "POST /index.html?n=97b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3854 286 -% 798
127.0.0.1 - - [07/Dec/2011:16:35:15 +0100] "POST /index.html?n=98b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3891 286 -% 927
127.0.0.1 - - [07/Dec/2011:16:35:16 +0100] "POST /index.html?n=99b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3928 286 -% 782
127.0.0.1 - - [07/Dec/2011:16:35:17 +0100] "POST /index.html?n=100b HTTP/1.1" 200 44 "-" "curl/7.22.0 (i486-pc-linux-gnu) libcurl/7.22.0 OpenSSL/1.0.1 zlib/1.2.3.4 libidn/1.23 librtmp/2.3" localhost 127.0.0.1 80 - - + "-" - 3966 286 -% 747
```

Wie oben vorhergesagt sind noch sehr viele Werte leer, oder durch _-_ gekennzeichnet. Aber wir sehen, dass wir den Server localhost auf Port 80 angesprochen haben und dass die Grösse des Requests mit jedem Request zunahm und zuletzt beinahe 4K, also 4096 Bytes, betrug. Mit diesem einfachen Logfile lassen sich bereits einfache Auswertungen durchführen.

###Schritt 7: Einfache Auswertungen mit dem Logformat Extended durchführen

Wer das Beispiel-Logfile genau ansieht, wird erkennen, dass die Dauer der Requests nicht ganz sauber verteilt ist. Es gibt zwei Ausreisser. Wir können das wie folgt identifizieren:

```bash
$> egrep -o "\% [0-9]+" logs/access.log | cut -b3- | sort -n
```

Mit diesem Einzeiler schneiden wir den Wert für die Dauer eines Requests aus dem Logfile heraus. Wir benützen das Prozentzeichen des Deflate-Wertes als Anker für eine einfache Regular Expression und nehmen die darauf folgende Zahl. Mit _cut_ schneiden wir die ersten zwei Bytes ab (wir geben nur Byte 3 bis zum Ende der Zeile zurück) und sortieren dann numerisch. Das liefert folgendes Resultat:

```bash
...
1035
1061
1061
1108
1126
1127
1152
1171
1184
1208
1406
1439
2112
3838
```

In unserem Beispiel stechen die beiden Werte bei rund 2000 und fast 4000 Microsekunden heraus. Sie stehen gegenüber den übrigen 198 Werten abseits.

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
$> egrep  -o "\"(GET|POST) " logs/access.log | cut -b2- | sort | uniq -c
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

	* FIXME: <a href="http://httpd.apache.org/docs/current/mod/mod_log_config.html">Dokumentation des Apache-Moduls Log-Config</a>


###Changelog


* 9. Juli 2013: Umbenennen des Logfile Formats auf extended (vs. extended2011); Anpassen der Logfile-Namen; Aktualisieren des User-Agent Eintrages im Logfile.
* 2. Juli 2013: Entfernung der Environment Variable _ModSecAnonScore_. Sie ist inkompatibel mit dem Tutorial Nummer 6.
* 9. April 2013: Präzisierung zum Logfile Wert _%b_
* 2. Februar 2012: Überarbeitet und publiziert
* 7. Dezember 2011: Erweitert
* 25. November 2011: Erstellt


</div>


