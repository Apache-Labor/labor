## Das Zugriffslog Ausbauen und Auswerten

### Was machen wir?

Wir definieren ein stark erweitertes Logformat, um den Verkehr besser überwachen zu können.


### Warum tun wir das?

In der gebräuchlichen Konfiguration des Apache Webservers wird ein Logformat eingesetzt, das nur die nötigsten Informationen zu den Zugriffen der verschiedenen Clients mitschreibt. In der Praxis werden oft zusätzliche Informationen benötigt, die sich leicht im Zugriffslog (Accesslog) des Servers notieren lassen. 


### Voraussetzungen

* Ein Apache Webserver, idealerweise mit einem File-Layout wie bei [Anleitung 1 (Kompilieren eines Apache Servers)](https://www.netnea.com/cms/apache_tutorial_1_apache_compilieren/) erstellt.
* Verständnis der minimalen Konfiguration in [Anleitung 2 (Apache minimal konfigurieren)](https://www.netnea.com/cms/apache_tutorial_2_apache_minimal_konfigurieren/).
* Ein Apache Webserver mit SSL-/TLS-Unterstützung wie in [Anleitung 4 (Konfigurieren eines SSL Servers)](https://www.netnea.com/cms/apache-tutorial-4-ssl-server-konfigurieren/)


### Schritt 1: Logformat Common verstehen

Das Logformat _Common_ ist ein sehr simples Format, das nurmehr sehr selten eingesetzt wird. Es hat den Vorteil, sehr platzsparend zu sein und kaum überflüssige Informationen zu schreiben.

```bash
LogFormat "%h %l %u %t \"%r\" %>s %b" common
...
CustomLog logs/access.log common
```

Mit der Direktiven _LogFormat_ definieren wir ein Format und geben ihm einen Namen; hier _common_.

Diesen Namen rufen wir in der Definition des Logfiles mit der Direktiven _CustomLog_ ab. Diese beiden Befehle können wir in der Konfiguration mehrmals einsetzen. Es lassen sich also mehrere Logformate mit mehreren Namenskürzeln nebeneinander definieren und mehrere Logfiles in verschiedenen Formaten schreiben. Es bietet sich etwa an, für verschiedene Dienste auf demselben Server separate Logfiles zu schreiben.

Die einzelnen Elemente des Logformats _common_ lauten wie folgt:

_%h_ bezeichnet den _Remote host_, normalerweise die IP-Adresse des Clients, der den Request abgesetzt hat. Falls dieser Client aber hinter einem Proxy-Server steht, dann sehen wir hier die IP-Adresse dieses Proxy-Servers. Wenn sich deshalb mehrere Clients den Proxy Server teilen, dann werden sie hier alle denselben _Remote host_-Eintrag besitzen. Zudem ist es möglich auf unserem Server die IP-Adressen durch einen DNS Reverse Lookup rückzuübersetzen. Falls wir dies konfigurieren (was nicht zu empfehlen ist), dann stünde hier der eruierte Hostname des Clients.

_%l_ stellt den _Remote logname_ dar. Er ist in aller Regel leer und wird durch einen Strich ("-") wiedergegeben. Tatsächlich ginge es dabei um die Identifizierung eines Clients durch einen _ident_-Zugriff auf den Client. Dies wird von den Clients kaum unterstützt und führt zu grossen Performance-Engpässen, weshalb es sich beim _%l_ um ein Artefakt aus den frühen 1990er Jahren handelt.

_%u_ ist gebräuchlicher und bezeichnet den Usernamen eines authentifizierten Users. Der Name wird durch ein Authentifizierungsmodul gesetzt und bleibt leer (also wiederum "-"), solange ein Zugriff ohne Authentifizierung auf dem Server auskommt.

_%t_ meint die Uhrzeit des Zugriffes. Bei grossen, langsamen Requests meint es die Uhrzeit, in dem Moment in dem der Server die sogenannte Request-Zeile empfangen hat. Da Apache einen Request erst nach Abschluss der Antwort in das Logfile schreibt, kann es vorkommen, dass ein langsamer Request mit einer früheren Uhrzeit mehrere Einträge tiefer als ein kurzer Request steht, der später gestartet ist. Beim Lesen des Logfiles führt das bisweilen zu Verwirrung.

Die Uhrzeit wird standardmässig zwischen rechteckigen Klammern ausgegeben. Es wird normalerweise in der lokalen Zeit inklusive der Abweichung von der Standardzeit geschrieben. Zum Beispiel:

```bash
[25/Nov/2014:08:51:22 +0100]
```

Hier meint es also den 25. November 2014, 8 Uhr 51, 1 Stunde vor der Standardzeit. Das Format der Uhrzeit selbst lässt sich gegebenenfalls anpassen. Dies geschieht nach dem Muster _%{format}t_, wobei _format_ der Spezifikation von _strftime(3)_ folgt. Wir haben von dieser Möglichkeit in der 2. Anleitung bereis Gebrauch gemacht. Sehen wir es uns aber in einem Beispiel genauer an:

```bash
%{[%Y-%m-%d %H:%M:%S %z (%s)]}t
```

In diesem Beispiel bringen wir das Datum in die Reihenfolge _Jahr-Monat-Tag_, um eine bessere Sortierbarkeit zu erreichen. Und nach der Abweichung von der Standardzeit fügen wir die Zeit in Sekunden seit dem Start der Unixepoche im Januar 1970 ein. Dies ist ein durch ein Skript leichter les- und interpretierbares Format.

Dieses Beispiel bringt uns Einträgen nach folgendem Muster:

```bash
[2014-11-25 09:34:33 +0100 (1322210073)]
```

Soweit zu _%t_.
Damit kommen wir zu _%r_ und zur Request-Zeile. Hierbei handelt es sich um die erste Zeile des HTTP-Requests, wie er vom Client an den Server gesendet wurde. Streng genommen gehört die Requestzeile nicht in die Gruppe der Request-Header; in aller Regel subsummiert man sie aber zusammen mit letzteren. Wie dem auch sei, auf der Request-Zeile übermittelt der Client dem Server die Identifikation der Ressource, die er verlangt.

Konkret folgt die Zeile diesem Muster:

```bash
Methode URI Protokoll
```

In der Praxis lautet ein einfaches Beispiel also wie folgt:

```bash
GET /index.html HTTP/1.1
```

Es wird also die _GET_-Methode angewendet. Dann folgt ein Leerschlag, dann der absolute Pfad auf die Ressource auf dem Server. Hier die Index-Datei. Optional kann der Client bekanntlich noch einen _Query-String_ an den Pfad anhängen. Dieser _Query-String_ wird in der Regel mit einem Fragezeichen eingeleitet und bringt verschiedene Parameter-Wert-Paare. Der _Query-String_ wird im Logformat auch wiedergegeben. Schliesslich das Protokoll, das in aller Regel HTTP in der Version 1.1 lautet. Zum Teil wird aber gerade von Agents, also automatisierten Skripten, nach wie vor die Version 1.0 verwendet. Das neue Protokoll HTTP/2 wird in der Request-Zeile des ersten Requests noch nicht vorkommen. Vielmehr findet in HTTP/2 während des Requests ein Update von HTTP/1.1 auf HTTP/2 statt. Der Start folgt also obenstehendem Muster.

Das folgende Format-Element folgt einem etwas anderen Muster: _%>s_. Dies meint den Status der Antwort, also etwa _200_ für einen erfolgreich abgeschlossenen Request. Die spitze Klammer weist darauf hin, dass wir uns für den finalen Status interessieren. Es kann vorkommen, dass eine Anfrage innerhalb des Servers weitergereicht wird. In diesem Fall interessiert uns nicht der Status, der das Weiterreichen ausgelöst hat, sondern den Status der Antwort des finalen internen Requests.

Ein typisches Beispiel wäre ein Aufruf, der auf dem Server zu einem Fehler führt (also Status 500). Wenn dann aber die zugehörige Fehlerseite nicht vorhanden ist, dann ergibt die interne Weiterreichung einen Status 404. Mit der spitzen Klammer erreichen wir, dass in diesem Fall das 404 in das Logfile geschrieben wird. Setzen wir die spitze Klammer in umgekehrter Richtung, dann würde der Status 500 geloggt. Um ganz sicher zu gehen, könnte es angebracht sein, beide Werte zu loggen, also folgender - in der Praxis ebenfalls unüblicher - Eintrag:

```bash
%<s %>s
```

_%b_ ist das letzte Element des Logformats _common_. Es gibt die Zahl der im Content-Length Response Headers angekündigten Bytes wieder. Bei einer Anfrage an _http://www.example.com/index.html_ entspricht dieser Wert der Grösse der Datei _index.html_. Die ebenfalls übertragenen _Response-Header_ werden nicht mitgezählt. Dazu kommt, dass diese Zahl nur eine Berechnung der geplanten Übertragung darstellt und keine Garantie darstellt, dass diese Daten auch wirklich übertragen wurden.


### Schritt 2: Logformat Combined verstehen

Das am weitesten verbreitete Logformat _combined_ baut auf dem Logformat _common_ auf und erweitert es um zwei Elemente.

```bash
LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
...
CustomLog logs/access.log combined
```
 
Das Element _"%{Referer}i"_ bezeichnet den Referrer. Er wird in Anführungszeichen wiedergegeben. Der Referrer meint diejenige Ressource, von der aus ursprünglich der jetzt erfolgte Request ausgelöst wurde. Diese komplizierte Umschreibung lässt sich an einem Beispiel besser illustrieren. Wenn man in einer Suchmaschine einen Link anklickt, um auf _www.example.com_ zu gelangen und dort automatisch auf _shop.example.com_ weitergeleitet wird, dann wird der Logeintrag auf dem Server _shop.example.com_ den Referrer auf die Suchmaschine tragen und nicht den Verweis auf _www.example.com_. Wenn dann aber von _shop.example.com_ eine abhängige CSS-Datei geladen wird, dann geht der Referrer normalerweise auf _shop.example.com_. Bei alledem ist aber zu beachten, dass der Referrer ein Teil der Anfrage des Clients ist. Der Client ist angehalten, sich an das Protokoll und die Konventionen zu halten, tatsächlich kann er aber beliebige Informationen senden, weshalb man sich in Sicherheitsfragen nicht auf Header wie diesen verlassen darf.

_"%{User-Agent}i"_ schliesslich meint den sogenannten User-Agent des Clients, der wiederum in Anführungszeichen gesetzt wird. Auch dies ist wieder ein Wert, der durch den Client kontrolliert wird und auf den wir uns nicht zu sehr verlassen sollten. Mit dem User-Agent ist die Browser-Software des Clients gemeint; normalerweise angereichert um die Version, die Rendering Engine, verschiedene Kompatibilitätsangaben mit anderen Browsern und diverse installierte Plugins. Das führt zu sehr langen User-Agent-Einträgen und kann im Einzelfall so viele Informationen enthalten, dass ein individueller Client sich darüber eindeutig identifizieren lässt, weil er eine besondere Kombination von verschiedenen Zusatzmodulen in bestimmten Versionen besitzt.


### Schritt 3: Module Logio und Unique-ID aktivieren

Mit dem _combined_ Format haben wir das am weitesten verbreitete Apache Logformat kennengelernt. Um die alltägliche Arbeit zu erleichtern, reichen die dargestellten Werte aber nicht. Weitere Informationen werden deshalb mit Vorteil im Logfile mitgeschrieben.

Es bietet sich an, auf sämtlichen Servern dasselbe Logformat zu verwenden. Anstatt jetzt also ein, zwei weitere Werte zu propagieren, beschreibt diese Anleitung ein sehr umfassendes Logformat, das sich in der Praxis in verschiedenen Szenarien bewährt hat.

Um das in der Folge beschriebene Logformat konfigurieren zu können, muss aber zunächst das Modul _Logio_ aktiviert werden. Und auch das Unique-ID Modul ist von Anfang an hilfreich.

Wenn der Server wie in der Anleitung 1 beschrieben kompiliert wurde, dann sind die Module bereits vorhanden und müssen nur noch in der Liste der zu ladenden Module in der Konfigurationsdatei des Servers ergänzt werden.

```bash
LoadModule              logio_module            modules/mod_logio.so
LoadModule              unique_id_module        modules/mod_unique_id.so
```

Wir benötigen das erste der beiden Module um zwei Werte mitschreiben zu können. _IO-In_ und _IO-Out_. Also die totale Zahl der Bytes des HTTP-Requests inklusive Header-Zeilen und die totale Zahl der Bytes in der Antwort, wiederum inklusive Header-Zeilen. Das Unique-ID Modul berechnet für jeden Request eine eindeutige Kennzeichnung. Wir kommen später nochmals darauf zurück.


### Schritt 4: Neues Logformat Extended konfigurieren

Damit sind wir bereit für ein neues, sehr umfassendes Logformat. Das Format umfasst auch Werte, die der Server mit den bis hierhin definierten Modulen noch nicht kennt. Er wird sie leer lassen, respektive durch einen Strich _"-"_ darstellen. Nur mit dem eben aktivierten Modul _Logio_ klappt das nicht. Wenn wir dessen Werte ansprechen, ohne dass sie vorhanden wären, stürzt der Server ab.

In den folgenden Anleitungen werden wir diese Werte dann nach und nach füllen. Weil es aber wie oben erklärt sinnvoll ist, überall dasselbe Logformat zu verwenden, greifen wir hier mit der nun folgenden Konfiguration bereits etwas vor.

Wir gehen vom _Combined_-Format aus und erweitern es nach rechts. Dies hat den Vorteil, dass die erweiterten Logfiles in vielen Standard-Tools weiterhin lesbar sind, denn die zusätzlichen Werte werden einfach ignoriert. Ferner ist es sehr leicht, die erweiterten Logfiles in die Basis zurückzuübersetzen um dann eben wieder ein Logformat _combined_ vor sich zu haben.

Wir definieren das Logformat wie folgt:

```bash

LogFormat "%h %{GEOIP_COUNTRY_CODE}e %u [%{%Y-%m-%d %H:%M:%S}t.%{usec_frac}t] \"%r\" %>s %b \
\"%{Referer}i\" \"%{User-Agent}i\" \"%{Content-Type}i\" %{remote}p %v %A %p %R \
%{BALANCER_WORKER_ROUTE}e %X \"%{cookie}n\" %{UNIQUE_ID}e %{SSL_PROTOCOL}x %{SSL_CIPHER}x \
%I %O %{ratio}n%% %D %{ModSecTimeIn}e %{ApplicationTime}e %{ModSecTimeOut}e \
%{ModSecAnomalyScoreInPLs}e %{ModSecAnomalyScoreOutPLs}e \
%{ModSecAnomalyScoreIn}e %{ModSecAnomalyScoreOut}e" extended

...

CustomLog		logs/access.log extended

```


### Schritt 5: Neues Logformat Extended verstehen

Das neue Logformat erweitert die Zugriffsprotokolle um 23 Werte. Das sieht auf den ersten Blick übertrieben aus, tatsächlich hat das aber alles seine Berechtigung und im täglichen Einsatz ist man um jeden dieser Werte froh, gerade wenn man einem Fehler auf der Spur ist.

Schauen wir uns die Werte nacheinander an.

In der Erklärung zum Log-Format _common_ haben wir gesehen, dass der zweite Wert, der Eintrag _logname_ gleich nach der IP-Adresse des Clients ein unbenutztes Artefakt darstellt. Wir ersetzen diese Position im Logfile mit dem Country-Code der IP-Adresse des Clients. Das macht Sinn, weil dieser Country-Code eine IP-Adresse stark charakterisiert. (In vielen Fällen macht es einen grossen Unterschied, ob die Anfrage aus dem Inland oder aus der Südsee stammt). Praktisch ist es nun, sie gleich neben die IP-Adresse zu stellen und der nichtssagenden Nummer ein Mehr an Information zuzugesellen.

Danach das bereits in der Anleitung 2 definierte Zeitformat, das sich am Zeitformat des Error-Logs orientiert und nun mit diesem kongruent ist. Wir bilden die Mikrosekunden auch ab und erhalten so sehr präzise Timing-Informationen. Die nächsten Werte sind bekannt.

_\"%Content-Type}i\"_ beschreibt den Content-Type der Anfrage. Dieser Wert ist normalerweise leer. Anfragen mit der HTTP-Methode POST, die zum Senden von Formularen oder zum Hochladen von Daten verwendet werden, verwenden diesen Header aber. Zu einem späteren Zeitpunkt planen wir, ModSecurity in unseren Service aufzunehmen. Dabei werden Informationen über die Art des Request Bodies sehr wichtig, da sich das Verhalten der ModSecurity-Engine je nach Header stark ändert.

_%{remote}p_ ist der nächste Zusatz. Es steht für die Portnummer des Clients. Wann immer ein Client also eine TCP-Verbindung zu einer Serveradresse und einem Port öffnet, verwendet er einen seiner eigenen Ports. Informationen über diesen Port können uns sagen, wie viele Verbindungen ein Client zu unserem Server öffnet. Und in einer Situation, in der sich mehrere Clients über dieselbe IP-Adresse verbinden (dank Network Address Translation NAT), kann es helfen, die Clients voneinander zu unterscheiden.

_%v_ bezeichnet den kanonischen Servernamen, der den Request bearbeitet hat. Falls wir den Server mittels eines Alias ansprechen, wird hier nicht dieses Alias geschrieben, sondern der eigentliche Name des Servers. In einem Virtual-Host Setup sind die Servernamen der Virtual-Hosts auch kanonisch. Sie werden hier also auftauchen und wir können sie in der Logdatei unterscheiden.

Mit _%A_ folgt die IP-Adresse mit welcher der Server die Anfrage empfangen hat. Dieser Wert hilft uns, die Server auseinander zu halten, wenn mehrere Logfiles zusammengefügt werden oder mehrere Server in dasselbe Logfile schreiben.

Dann beschreibt _%p_ die Portnummer, auf welcher der Request empfangen wurde. Auch dies ist wichtig, um verschiedene Einträge auseinanderhalten zu können, wenn wir verschiedene Logfiles (etwa diejenigen für Port 80 und diejenigen für Port 443) zusammenfügen.

_%R_ gibt den Handler wieder, der die Antwort auf einen Request generiert hat. Dieser Wert kann leer sein (also _"-"_) wenn eine statische Datei ausgeliefert wurde. Oder aber er bezeichnet mit _proxy_, dass der Request an einen anderen Server weitergeleitet worden ist.

*%{BALANCER_WORKER_ROUTE}e* hat auch mit dem Weitergeben von Anfragen zu tun. Wenn wir zwischen mehreren Zielserver abwechseln, belegt dieser Wert, wohin die Anfrage geschickt wurde.

_%X_ gibt den Status der TCP-Verbindung nach Abschluss der Anfrage wieder. Es sind drei Werte möglich: Die Verbindung ist geschlossen (_-_), die Verbindung wird mittels _Keep-Alive_ offen gehalten (_+_) oder aber die Verbindung wurde abgebrochen bevor der Request abgeschlossen werden konnte (_X_).

Mit _"%{cookie}n"_ folgt ein Wert, der dem User-Tracking dient. Damit können wir einen Client mittels eines Cookies identifizieren und ihn zu einem späteren Zeitpunkt wiedererkennen - sofern er das Cookie immer noch trägt. Wenn wir das Cookie domänenweit setzen, also auf example.com und nicht beschränkt auf www.example.com, dann können wir einem Client sogar über mehrere Hosts hinweg folgen. Im Idealfall wäre dies aufgrund der IP-Adresse des Clients ebenfalls möglich, aber sie kann im Laufe einer Session gewechselt werden und es kann auch sein, dass sich mehrere Clients eine IP-Adresse teilen.

Der Wert *%{UNIQUE_ID}e* ist ein sehr hilfreicher Wert. Für jeden Request wird damit auf dem Server eine eindeutige Identifizierung kreiert. Wenn wir den Wert etwa auf einer Fehlerseite ausgeben, dann lässt sich ein Request im Logfile aufgrund eines Screenshots bequem identifizieren - und im Idealfall die gesamte Session aufgrund des User-Tracking-Cookies nachvollziehen.

Nun folgen zwei Werte, die von *mod_ssl* bekannt gegeben werden. Das Verschlüsselungsmodul gibt dem Logmodul Werte in einem eigenen Namensraum bekannt, der mit dem Kürzel _x_ bezeichnet wird. In der Dokumentation von *mod_ssl* werden die verschiedenen Werte einzeln erklärt. Für den Betrieb eines Servers sind vor allem das verwendete Protokoll und die verwendete Verschlüsselung von Interesse. Diese beiden Werte, mittels *%{SSL_PROTOCOL}x* und *%{SSL_CIPHER}x* referenziert, helfen uns dabei, einen Überblick über den Einsatz der Verschlüsselung zu erhalten. Früher oder später sind wir soweit, dass wir das _TLSv1_ Protokoll abschalten werden. Zuerst möchten wir aber sicher sein, dass es in der Praxis keine nennenswerte Rolle mehr spielt. Das Logfile wird uns dabei helfen. Analog der Verschlüsselungsalgorithmus, der uns die tatsächlich verwendeten _Ciphers_ mitteilt und uns hilft eine Aussage zu machen, welche Ciphers nicht mehr länger verwendet werden. Die Informationen sind wichtig. Wenn zum Beispiel Schwächen in einzelnen Protokollversionen oder einzelnen Verschlüsselungsverfahren bekannt werden, dann können wir den Effekt unseres Massnahmen anhand des Logfiles abschätzen. So war etwa die folgende Aussage im Frühjahr 2015 Gold wert: "Das sofortige Abschalten des SSLv3 Protokolls als Reaktion auf die POODLE Schwachstelle wird bei ca. 0.8% der Zugriffe zu einem Fehler führen. Hochgerechnet auf unsere Kundenbasis werden soundsoviele Kunden betroffen sein." Mit diesen Zahlen wurde das Risiko und der Effekt der Massnahme voraussagbar.

Mit _%I_ und _%O_ folgen die beiden Werte, welche durch das Modul _Logio_ definiert werden. Es ist die gesamte Zahl der Bytes im Request und die gesamte Zahl der Bytes in der Response. Wir kennen bereits _%b_ für die Summe der Bytes im Response-Body. _%O_ ist hier etwas genauer und hilft zu erkennen, wenn die Anfrage oder ihre Antwort entsprechende Grössen-Limiten verletzte.

_%{ratio}n%%_ bedeutet die Prozentzahl der Kompression der übermittelten Daten, welche durch die Anwendung des Modules _Deflate_ erreicht werden konnte. Dies ist für den Moment noch ohne Belang, bringt uns in Zukunft aber interessante Performance-Daten.

_%D_ gibt die komplette Dauer des Requests in Mikrosekunden wieder. Gemessen wird vom Erhalt der Request-Zeile bis zum Moment, wenn der letzte Teil der Antwort den Server verlässt.

Wir fahren weiter mit Performance-Daten. Wir werden in Zukunft die Stoppuhr ansetzen und die Anfrage auf dem Weg in den Server hinein, bei der Applikation und während der Verarbeitung der Antwort separat messen. Die entsprechenden Werte werden wir in den Environment Variablen _ModSecTimeIn_, _ApplicationTime_ sowie _ModSecTimeOut_ ablegen.

Und zu guter Letzt noch zwei weitere Werte, die uns die _OWASP ModSecurity Core Rule Set_ in einer späteren Anleitung zur Verfügung stellen werden, nämlich die Anomalie-Punktezahl der Anfrage und der Antwort. Was es damit auf sich hat, ist für den Moment noch unwichtig. Wichtig ist, dass wir mit diesem stark erweiterten Logformat eine Basis gelegt haben, auf die wir zukünftig aufbauen können, ohne das Logformat nochmals anpassen zu müssen.


### Schritt 6: Weitere Request- und Response-Header in zusätzlichem Logfile mitschreiben

Im Arbeitsalltag ist man oft nach bestimmten Requests auf der Suche oder man ist sich nicht sicher, welche Requests einen Fehler verursachen. Da erweist es sich oft als hilfreich, wenn man bestimmte zusätzliche Werte mit ins Logfile schreiben kann. Beliebige Request- und Response-Header sowie Umgebungs-Variabeln lassen sich sehr leicht mitschreiben. Unser Logformat macht davon rege Gebrauch.

Bei den Werten _\"%{Referer}i\"_ sowie _\"%{User-Agent}i\"_ handelt es sich um Request-Header-Felder. Bei der Balancer-Route *%{BALANCER_WORKER_ROUTE}e* haben wir es mit einer Umgebungs-Variablen zu tun. Das Muster wird deutlich: _%{Header/Variable}<Domäne>_. Request-Header sind der Domäne _i_ zugeordnet. Environment-Variabeln der Domäne _e_, die Response-Header der Domäne _o_ und die Variablen des _SSL_-Moduls der Domäne _x_.

Schreiben wir zu Debug-Zwecken also ein zusätzliches Logfile. Wir benützen nicht mehr die _LogFormat_-Direktive, sondern definieren das Format zusammen mit dem File auf einer Zeile. Dies ist ein Shortcut, wenn man ein bestimmtes Format nur ein Mal verwenden möchte.

```bash
CustomLog logs/access-debug.log "[%{%Y-%m-%d %H:%M:%S}t.%{usec_frac}t] %{UNIQUE_ID}e \"%r\" \
%{Accept}i %{Content-Type}o"
```

Mit diesem zusätzlichen Logfile sehen wir, welche Wünsche der Client in Bezug auf die Content-Types äusserte und was unser Server tatsächlich lieferte. Normalerweise klappt dieses Zusammenspiel zwischen Client und Server sehr gut. Aber in der Praxis gibt es da schon mal Unstimmigkeiten; da ist ein zusätzliches Logfile dieser Art hilfreich bei der Fehlersuche.
Das Resultat könnte dann etwa wie folgt aussehen:

```bash
$> cat logs/access-debug.log
2015-09-02 11:58:35.654011 VebITcCoAwcAADRophsAAAAX "GET / HTTP/1.1" */* text/html
2015-09-02 11:58:37.486603 VebIT8CoAwcAADRophwAAAAX "GET /cms/feed/ HTTP/1.1" text/html,application …
2015-09-02 11:58:39.253209 VebIUMCoAwcAADRoph0AAAAX "GET /cms/2014/04/17/ubuntu-14-04/ HTTP/1.1" */* …
2015-09-02 11:58:40.893992 VebIU8CoAwcAADRbdGkAAAAD "GET /cms/2014/05/13/download-softfiles HTTP/1.1" */* …
2015-09-02 11:58:43.558478 VebIVcCoAwcAADRbdGoAAAAD "GET /cms/2014/08/25/netcapture-sshargs HTTP/1.1" */* …
...
```

So lassen sich Logfiles in Apache also sehr frei definieren. Interessanter ist aber die Auswertung der Daten. Dazu benötigen wir erst einige Daten.


### Schritt 7: Ausprobieren und Logdatei füllen

Konfigurieren wir das erweiterte Zugriffslog im Format _extended_ wie oben beschrieben und beschäftigen wir den Server etwas!

Wir könnten dazu _Apache Bench_ wie in der zweiten Anleitung zwei beschrieben verwenden, aber das würde ein sehr einförmiges Logfile ergeben. Mit den folgenden beiden Einzeilern bringen wir etwas Abwechslung hinein (man beachte das _insecure_ Flag, das curl instruiert, Zertifikatsprobleme zu ignorieren):

```bash
$> for N in {1..100}; do curl --silent --insecure https://localhost/index.html?n=${N}a >/dev/null; done
$> for N in {1..100}; do PAYLOAD=$(uuid -n $N | xargs); \
   curl --silent --data "payload=$PAYLOAD" --insecure https://localhost/index.html?n=${N}b >/dev/null; \
   done
```

Auf der ersten Zeile setzen wir einfach hundert Requests ab, wobei wir sie im _Query-String_ nummerieren. Auf der zweiten Zeile dann die interessantere Idee: Wieder setzen wir hundert Anfragen ab. Dieses Mal möchten wir aber Daten mit Hilfe eines POST-Requests im Body-Teil der Anfrage mitschicken. Diesen sogenannen Payload generieren wir dynamisch und zwar so, dass er mit jedem Aufruf grösser wird. Die benötigten Daten generieren wir mittels _uuidgen_. Dabei handelt es sich um einen Befehl, der eine _ascii-ID_ generiert.
Aneinandergehängt erhalten wir eine Menge Daten. (Falls es zu einer Fehlermeldung kommt, könnte es sein, dass der Befehl _uuidgen_ nicht vorhanden ist. In diesem Fall wäre das Paket _uuid_ zu installieren).


Die Bearbeitung dieser Zeile dürfte einen Moment dauern. Als Resultat sehen wir folgendes im Logfile:

```bash
127.0.0.1 - - [2019-01-31 05:59:35.594159] "GET /index.html?n=1a HTTP/1.1" 200 45 "-" "curl/7.58.0" … 
"-" 53252 localhost 127.0.0.1 443 - - + "-" XFKAt7evwRxnTvzP--AjEAAAAAI TLSv1.2 … 
ECDHE-RSA-AES256-GCM-SHA384 422 1463 -% 97 - - - - - - -
127.0.0.1 - - [2019-01-31 05:59:35.612331] "GET /index.html?n=2a HTTP/1.1" 200 45 "-" "curl/7.58.0" …
"-" 53254 localhost 127.0.0.1 443 - - + "-" XFKAt7evwRxnTvzP--AjEQAAAAg TLSv1.2 …
ECDHE-RSA-AES256-GCM-SHA384 422 1463 -% 123 - - - - - - -
127.0.0.1 - - [2019-01-31 05:59:35.634044] "GET /index.html?n=3a HTTP/1.1" 200 45 "-" "curl/7.58.0" …
"-" 53256 localhost 127.0.0.1 443 - - + "-" XFKAt7evwRxnTvzP--AjEgAAAAc TLSv1.2 …
ECDHE-RSA-AES256-GCM-SHA384 422 1463 -% 136 - - - - - - -
127.0.0.1 - - [2019-01-31 05:59:35.652333] "GET /index.html?n=4a HTTP/1.1" 200 45 "-" "curl/7.58.0" …
"-" 53258 localhost 127.0.0.1 443 - - + "-" XFKAt7evwRxnTvzP--AjEwAAAAs TLSv1.2 …
ECDHE-RSA-AES256-GCM-SHA384 422 1463 -% 100 - - - - - - -
127.0.0.1 - - [2019-01-31 05:59:35.669342] "GET /index.html?n=5a HTTP/1.1" 200 45 "-" "curl/7.58.0" …
"-" 53260 localhost 127.0.0.1 443 - - + "-" XFKAt7evwRxnTvzP--AjFAAAAA4 TLSv1.2 …
ECDHE-RSA-AES256-GCM-SHA384 422 1463 -% 101 - - - - - - -
127.0.0.1 - - [2019-01-31 05:59:35.686449] "GET /index.html?n=6a HTTP/1.1" 200 45 "-" "curl/7.58.0" …
"-" 53262 localhost 127.0.0.1 443 - - + "-" XFKAt7evwRxnTvzP--AjFQAAABA TLSv1.2 …
ECDHE-RSA-AES256-GCM-SHA384 422 1463 -% 102 - - - - - - -
127.0.0.1 - - [2019-01-31 05:59:35.703428] "GET /index.html?n=7a HTTP/1.1" 200 45 "-" "curl/7.58.0" …
"-" 53264 localhost 127.0.0.1 443 - - + "-" XFKAt7evwRxnTvzP--AjFgAAABQ TLSv1.2 …
ECDHE-RSA-AES256-GCM-SHA384 422 1463 -% 101 - - - - - - -
...
127.0.0.1 - - [2019-01-31 05:59:48.060573] "POST /index.html?n=1b HTTP/1.1" 200 45 "-" "curl/7.58.0" …
"application/x-www-form-urlencoded" 53452 localhost 127.0.0.1 443 - - + "-" XFKAxLevwRxnTvzP--AjdAAAAAE …
TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 536 1463 -% 97 - - - - - - -
127.0.0.1 - - [2019-01-31 05:59:48.080029] "POST /index.html?n=2b HTTP/1.1" 200 45 "-" "curl/7.58.0" …
"application/x-www-form-urlencoded" 53454 localhost 127.0.0.1 443 - - + "-" XFKAxLevwRxnTvzP--AjdQAAAAU …
TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 573 1463 -% 113 - - - - - - -
127.0.0.1 - - [2019-01-31 05:59:48.100103] "POST /index.html?n=3b HTTP/1.1" 200 45 "-" "curl/7.58.0" …
"application/x-www-form-urlencoded" 53456 localhost 127.0.0.1 443 - - + "-" XFKAxLevwRxnTvzP--AjdgAAAAQ …
TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 611 1463 -% 105 - - - - - - -
127.0.0.1 - - [2019-01-31 05:59:48.119907] "POST /index.html?n=4b HTTP/1.1" 200 45 "-" "curl/7.58.0" …
"application/x-www-form-urlencoded" 53458 localhost 127.0.0.1 443 - - + "-" XFKAxLevwRxnTvzP--AjdwAAAAo …
TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 648 1463 -% 93 - - - - - - -
127.0.0.1 - - [2019-01-31 05:59:48.137620] "POST /index.html?n=5b HTTP/1.1" 200 45 "-" "curl/7.58.0" …
"application/x-www-form-urlencoded" 53460 localhost 127.0.0.1 443 - - + "-" XFKAxLevwRxnTvzP--AjeAAAAA0 …
TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 685 1463 -% 98 - - - - - - -
127.0.0.1 - - [2019-01-31 05:59:48.155453] "POST /index.html?n=6b HTTP/1.1" 200 45 "-" "curl/7.58.0" …
"application/x-www-form-urlencoded" 53462 localhost 127.0.0.1 443 - - + "-" XFKAxLevwRxnTvzP--AjeQAAABE …
TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 722 1463 -% 97 - - - - - - -
127.0.0.1 - - [2019-01-31 05:59:48.174826] "POST /index.html?n=7b HTTP/1.1" 200 45 "-" "curl/7.58.0" …
"application/x-www-form-urlencoded" 53464 localhost 127.0.0.1 443 - - + "-" XFKAxLevwRxnTvzP--AjegAAABM …
TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 759 1463 -% 95 - - - - - - -
...
127.0.0.1 - - [2019-01-31 05:59:50.533651] "POST /index.html?n=99b HTTP/1.1" 200 45 "-" "curl/7.58.0" …
"application/x-www-form-urlencoded" 53648 localhost 127.0.0.1 443 - - + "-" XFKAxrevwRxnTvzP--Aj1gAAABM …
TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 4216 1517 -% 1740 - - - - - - -
127.0.0.1 - - [2019-01-31 05:59:50.555242] "POST /index.html?n=100b HTTP/1.1" 200 45 "-" "curl/7.58.0" …
"application/x-www-form-urlencoded" 53650 localhost 127.0.0.1 443 - - + "-" XFKAxrevwRxnTvzP--Aj1wAAABc …
TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 4254 1517 -% 264 - - - - - - -
```

Wie oben vorhergesagt sind noch sehr viele Werte leer oder durch _-_ gekennzeichnet. Aber wir sehen, dass wir den Server _www.example.com_ auf Port 443 angesprochen haben und dass die Grösse des Requests mit jedem _POST_-Request zunahm, wobei sie zuletzt beinahe 4K, also 4096 Bytes, betrug. Mit diesem einfachen Logfile lassen sich bereits einfache Auswertungen durchführen.


### Schritt 8: Einfache Auswertungen mit dem Logformat Extended durchführen

Wer das Beispiel-Logfile genau ansieht, wird erkennen, dass die Dauer der Requests nicht ganz sauber verteilt ist. Es gibt einen Ausreisser. Wir können ihn wie folgt identifizieren:

```bash
$> egrep -o "\% [0-9]+ " logs/access.log | cut -b3- | tr -d " " | sort -n
```

Mit diesem Einzeiler schneiden wir den Wert, der die Dauer eines Requests angibt, aus dem Logfile heraus. Wir benützen das Prozentzeichen des Deflate-Wertes als Anker für eine einfache Regular Expression und nehmen die darauf folgende Zahl. _egrep_ bietet sich an, weil wir mit RegEx arbeiten wollen, die Option _-o_ führt dazu, dass nicht die gesamte Zeile, sondern nur der Treffer selbst ausgegeben wird. Das ist sehr hilfreich.
Ein Detail, das uns zukünftige Fehler verhindern hilft, ist das Leerzeichen nach dem Pluszeichen. Es nimmt nur diejenigen Werte, die auf die Zahl ein Leerzeichen folgen lassen. Das Problem ist der User-Agent, der in unserem Logformat ja auch vorkommt und der bisweilen auch Prozentzeichen enthält. Wir gehen hier davon aus, dass zwar im User-Agent Prozentzeichen gefolgt von Leerschlag und einer Ganzzahl folgen können. Dass danach aber kein weiterer Leerschlag folgt und diese Kombination nur im hinteren Teil der Logzeile nach dem Prozentzeichen der _Deflate-Platzeinsparungen_ vorkommt. Dann schneiden wir mittels _cut_ so, dass nur das dritte und die folgenden Zeichen ausgegeben werden und schliesslich trennen wir noch mit _tr_ das abschliessende Leerzeichen (siehe Regex) ab. Dann sind wir bereit für das numerische Sortieren. Das liefert folgendes Resultat:

```bash
...
354
355
357
363
363
363
1740
```

In unserem Beispiel wurden fast alle Anfragen sehr schnell bearbeitet. Dennoch gibt es einen einzigen mit einer Dauer von über 1.000 Mikrosekunden oder mehr als einer Millisekunde. Dies ist immer noch in angemessenem Rahmen, aber interessant zu sehen, wie sich diese Anfrage als statistischer Ausreißer von den anderen Werten abhebt.

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

Hier filtern wir die GET und die POST Requests anhand der Methode, die auf ein Anführungszeichen folgt, heraus. Dann schneiden wir das Anführungszeichen ab, sortieren und zählen gruppiert aus:

```bash
    100 GET 
    100 POST 
```

Soweit zu diesen ersten Fingerübungen. Auf der Basis dieses selbst abgefüllten Logfiles ist das leider noch nicht sehr spanned. Nehmen wir uns also ein richtiges Logfile von einem Produktionsserver vor.


### Schritt 9: Tiefer gehende Auswertungen auf einem Beispiel-Logfile

Spannender werden die Auswertungen mit einem richtigen Logfile von einem produktiven Server. Hier ist eines, mit 10'000 Anfragen:

[labor-04-example-access.log](https://www.netnea.com/files/labor-04-example-access.log)

```bash
$> head labor-04-example-access.log
192.31.242.0 US - [2019-01-21 23:51:44.365656] "GET …
/cds/2016/10/16/using-ansible-to-fetch-information-from-ios-devices/ HTTP/1.1" 200 10273 …
"https://www.google.com/" "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, …
like Gecko) Chrome/71.0.3578.98 Safari/537.36" "-" 13258 www.example.com 192.168.3.7 443 …
redirect-handler - + "ReqID--" XEZNAMCoAwcAAAxAiBgAAAAA TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 …
776 14527 -% 360398 2128 0 0 0-0-0-0 0-0-0-0 0 0
192.31.242.0 US - [2019-01-21 23:51:44.943942] "GET …
/cds/snippets/themes/customizr/assets/shared/fonts/fa/css/fontawesome-all.min.css?ver=4.1.12 …
HTTP/1.1" 200 7439 …
"https://www.example.com/cds/2016/10/16/using-ansible-to-fetch-information-from-ios-devices/" …
"Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 …
Safari/537.36" "-" 13258 www.example.com 192.168.3.7 443 - - + "ReqID--" XEZNAMCoAwcAAAxAiBkAAAAA …
TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 507 7950 -% 2509 1039 0 164 0-0-0-0 0-0-0-0 0 0
192.31.242.0 US - [2019-01-21 23:51:44.947470] "GET …
/cds/snippets/themes/customizr/inc/assets/css/tc_common.min.css?ver=4.1.12 HTTP/1.1" 200 28225 …
"https://www.example.com/cds/2016/10/16/using-ansible-to-fetch-information-from-ios-devices/" …
"Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 …
Safari/537.36" "-" 32554 www.example.com 192.168.3.7 443 - - + "ReqID--" XEZNAMCoAwcAAAxDkkUAAAAD …
TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 754 32406 -% 6714 1338 0 168 0-0-0-0 0-0-0-0 0 0
212.147.59.0 CH - [2019-01-21 23:51:44.849966] "GET /cds/ HTTP/1.1" 200 31332 "-" "check_http/v2.1.4 …
(nagios-plugins 2.1.4)" "-" 16291 www.example.com 192.168.3.7 443 application/x-httpd-php - - …
"ReqID--" XEZNAMCoAwcAAAxEZFIAAAAE TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 586 35548 -% 144762 1180 0 …
13771 0-0-0-0 0-0-0-0 0 0
192.31.242.0 US - [2019-01-21 23:51:45.143819] "GET …
/cds/snippets/themes/customizr-child/inc/assets/css/neagreen.min.css?ver=4.1.12 HTTP/1.1" 200 2458 …
"https://www.example.com/cds/2016/10/16/using-ansible-to-fetch-information-from-ios-devices/" …
"Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 …
Safari/537.36" "-" 13258 www.example.com 192.168.3.7 443 - - + "ReqID--" XEZNAcCoAwcAAAxAiBoAAAAA …
TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 494 2969 -% 1946 1070 0 141 0-0-0-0 0-0-0-0 0 0
192.31.242.0 US - [2019-01-21 23:51:45.269615] "GET …
/cds/snippets/themes/customizr-child/style.css?ver=4.1.12 HTTP/1.1" 200 483 …
"https://www.example.com/cds/2016/10/16/using-ansible-to-fetch-information-from-ios-devices/" …
"Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 …
Safari/537.36" "-" 22078 www.example.com 192.168.3.7 443 - - + "ReqID--" XEZNAcCoAwcAAAxBiDkAAAAB …
TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 737 4544 -% 4237 2221 0 241 0-0-0-0 0-0-0-0 0 0
192.31.242.0 US - [2019-01-21 23:51:45.309680] "GET …
/cds/snippets/themes/customizr/assets/front/js/libs/fancybox/jquery.fancybox-1.3.4.min.css?ver=4.9.8 …
HTTP/1.1" 200 981 …
"https://www.example.com/cds/2016/10/16/using-ansible-to-fetch-information-from-ios-devices/" …
"Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 …
Safari/537.36" "-" 32554 www.example.com 192.168.3.7 443 - - + "ReqID--" XEZNAcCoAwcAAAxDkkYAAAAD …
TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 515 1461 -% 2830 1656 0 200 0-0-0-0 0-0-0-0 0 0
192.31.242.0 US - [2019-01-21 23:51:45.467686] "GET …
/cds/includes/js/jquery/jquery-migrate.min.js?ver=1.4.1 HTTP/1.1" 200 4014 …
"https://www.example.com/cds/2016/10/16/using-ansible-to-fetch-information-from-ios-devices/" …
"Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 …
Safari/537.36" "-" 35193 www.example.com 192.168.3.7 443 - - + "ReqID--" XEZNAcCoAwcAAAyCROcAAAAF …
TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 721 8120 -% 3238 1536 0 142 0-0-0-0 0-0-0-0 0 0
192.31.242.0 US - [2019-01-21 23:51:45.469159] "GET …
/cds/snippets/themes/customizr/assets/front/js/libs/fancybox/jquery.fancybox-1.3.4.min.js?ver=4.1.12 …
HTTP/1.1" 200 5209 …
"https://www.example.com/cds/2016/10/16/using-ansible-to-fetch-information-from-ios-devices/" …
"Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 …
Safari/537.36" "-" 46005 www.example.com 192.168.3.7 443 - - + "ReqID--" XEZNAcCoAwcAAAxCwlQAAAAC …
TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 765 9315 -% 2938 1095 0 246 0-0-0-0 0-0-0-0 0 0
192.31.242.0 US - [2019-01-21 23:51:45.469177] "GET …
/cds/snippets/themes/customizr/assets/front/js/libs/modernizr.min.js?ver=4.1.12 HTTP/1.1" 200 5926 …
"https://www.example.com/cds/2016/10/16/using-ansible-to-fetch-information-from-ios-devices/" …
"Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 …
Safari/537.36" "-" 42316 www.example.com 192.168.3.7 443 - - + "ReqID--" XEZNAcCoAwcAAAyDuEIAAAAG …
TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 744 10032 -% 3022 1094 0 245 0-0-0-0 0-0-0-0 0 0
```

Schauen wir uns hier mal die Verteilung der _GET_ und _POST_ Requests an:

```bash
$> cat labor-04-example-access.log  | egrep  -o '"(GET|POST)'  | cut -b2- | sort | uniq -c
   9466 GET
    115 POST
```

Das ist ein eindeutiges Resultat. Sehen wir eigentlich viele Fehler? Also Anfragen, die mit einem HTTP Fehlercode beantwortet wurden?

```bash
$> cat labor-04-example-access.log | cut -d\" -f3 | cut -d\  -f2 | sort | uniq -c
   9397 200
      3 206
    233 301
     67 304
      9 400
     58 403
    233 404
```

Da liegt neben den neun Requests mit der HTTP Antwort "400 Bad Request" ein recht grosser Anteil an 404ern vor ("404 Not Found"). HTTP Status 400 bedeutet ein Protokoll-Fehler. 404 ist bekanntlich eine nicht gefundene Seite. Hier müsste man also mal nach dem Rechten sehen. Aber bevor wir weiter gehen, ein Hinweis auf die Anfrage mittels des Befehls _cut_. Wir haben die Logzeile mit dem Trennzeichen _"_ unterteilt, das dritte Feld mit dieser Unterteilung extrahiert und dann den Inhalt wieder unterteilt, dieses Mal aber mit dem Leerschlag (man beachte das _\_-Zeichen) als Trennzeichen und das zweite Feld extrahiert, was nun dem Status entspricht. Danach wurde sortiert und die _uniq-Funktion_ im Zählmodus angewendet. Wir werden sehen, dass diese Art des Zugriffs auf die Daten ein sich wiederholendes Muster ist.
Schauen wir das Logfile noch etwas genauer an.

Weiter oben war die Rede von Verschlüsselungsprotokollen und wie ihre Auswertung eine Grundlage für einen Entscheid der adäquaten Reaktion auf die _POODLE_-Schwachstelle war. Welche Verschlüsselungsprotokolle kommen seither eigentlich auf dem Server in der Praxis vor:

```bash
$> cat tutorial-5-example-access.log | cut -d\" -f11 | cut -d\  -f3 | sort | uniq -c | sort -n
      4 -
    155 TLSv1
   9841 TLSv1.2
```

Es scheint vorzukommen, dass Apache kein Verschlüsselungsprotokoll notiert. Das ist etwas merkwürdig, da es aber ein sehr seltener Fall ist, gehen wir ihm für den Moment nicht nach. Wichtiger sind die Zahlenverhältnisse zwischen den TLS Protokollen. Hier dominiert nach dem Abschalten von _SSLv3_ das Protokoll _TLSv1.2_ ubd _TLSv1.0_ wird langsam verdrängt.

Zum gewünschten Resultat sind wir wieder über eine Reihe von _cut_-Befehlen gelangt. Eigentlich wäre es doch angebracht, diese Befehle vorzumerken, da wir sie immer wieder brauchen. Das wäre dann eine Alias-Liste wie die folgende:

```bash
alias alip='cut -d\  -f1'
alias alcountry='cut -d\  -f2'
alias aluser='cut -d\  -f3'
alias altimestamp='cut -d\  -f4,5 | tr -d "[]"'
alias alrequestline='cut -d\" -f2'
alias almethod='cut -d\" -f2 | cut -d\  -f1 | sed "s/^-$/**NONE**/"'
alias aluri='cut -d\" -f2 | cut -d\  -f2 | sed "s/^-$/**NONE**/"'
alias alprotocol='cut -d\" -f2 | cut -d\  -f3 | sed "s/^-$/**NONE**/"'
alias alstatus='cut -d\" -f3 | cut -d\  -f2'
alias alresponsebodysize='cut -d\" -f3 | cut -d\  -f3'
alias alreferer='cut -d\" -f4 | sed "s/^-$/**NONE**/"'
alias alreferrer='cut -d\" -f4 | sed "s/^-$/**NONE**/"'
alias aluseragent='cut -d\" -f6 | sed "s/^-$/**NONE**/"'
alias alcontenttype='cut -d\" -f8'
...
```

Die Aliase beginnen alle mit _al_. Dies steht für _ApacheLog_ oder _AccessLog_. Darauf folgt der Feldnahme. Die einzelnen Aliase sind nicht alphabethisch geordnet. Sie folgen vielmehr der Reihenfolge der Felder im Format des Logfiles.

Diese Liste mit Alias-Definitionen befindet sich in der Datei [.apache-modsec.alias](https://www.netnea.com/files/.apache-modsec.alias). Dort liegt sie gemeinsam mit einigen weiteren Aliasen, die wir in späteren Anleitungen definieren werden. Wenn man öfter mit Apache und seinen Logfiles arbeitet, dann bietet es sich an, diese Alias-Definitionen im Heim-Verzeichnis abzulegen und sie beim Einloggen zu laden. Also mittels folgendem Eintrag in der _.bashrc_-Datei oder über einen verwandten Mechanismus. Der Eintrag hat auch eine zweite Funktion: Er fügt den Unterordner `bin` des Home-Verzeichnisses zum Pfad hinzu, wenn er nicht bereits vorhanden ist. Dies ist oft nicht der Fall und wir werden diesen Ordner zukünftig verwenden, um zusätzliche benutzerdefinierte Skripte zu platzieren, die mit den Apache-Modsec-Dateien spielen. Es ist also ein guter Moment, dies sofort vorzubereiten.

```bash
# Load apache / modsecurity aliases if file exists
test -e ~/.apache-modsec.alias && . ~/.apache-modsec.alias

# Add $HOME/bin to PATH
[[ ":$PATH:" != *":$HOME/bin:"* ]] && PATH="$HOME/bin:${PATH}"
```

Wenden wir den neuen Alias das also gleich mal an:

```bash
$> cat labor-04-example-access.log | alsslprotocol | sort | uniq -c | sort -n
      4 -
    155 TLSv1.1
   9841 TLSv1.2
```
Das geht schon etwas leichter. Aber das wiederholte Tippen von _sort_ gefolgt von _uniq -c_ und dann nochmals ein numerisches _sort_ ist mühselig. Da es sich erneut um ein wiederkehrendes Muster handelt, lohnt sich auch hier ein Alias, der sich als _sucs_ abkürzen lässt: ein Zusammenzug der Anfangsbuchstaben und des _c_ von _uniq -c_.

```bash
$> alias sucs='sort | uniq -c | sort -n'
```

Das erlaubt uns dann:


```bash
$> cat labor-04-example-access.log | alsslprotocol | sucs
      4 -
    155 TLSv1.1
   9841 TLSv1.2
```

Das ist nun ein einfacher Aufruf, den man sich gut merken kann und der leicht zu schreiben ist. Wir blicken nun auf ein Zahlenverhältnis von 1764 zu 8150. Total haben wir hier genau 10'000 Anfragen vor uns; die Prozentwerte sind von Auge abzuleiten. In der Praxis dürften die Logfiles aber kaum so schön aufgehen, wir benötigen also Hilfe beim Ausrechnen der Prozentzahlen.


### Schritt 10: Auswertungen mit Prozentzahlen und einfache Statistik

Was uns fehlt ist ein Befehl, der ähnlich wie der Alias _sucs_ funktioniert, aber im selben Durchlauf die Zahlenwerte in Prozentzahlen verwandelt: _sucspercent_. Wichtig ist zu wissen, dass das Skript auf einer erweiterten *awk*-Implementation besteht (ja, es gibt mehrere). In der Regel heisst das entsprechende Paket *gawk* und sorgt dafür, dass der Befehl `awk` die GNU-awk Implementation benützt.

```bash
$> alias sucspercent='sort | uniq -c | sort -n | $HOME/bin/percent.awk'
```

Rasche Rechnungen erledigt man in Linux traditionellerweise mit _awk_. Dafür steht neben der oben gelinkten _Alias_-Datei, die _sucspercent_ ebenfalls enthält, zusätzlich
das _awk_-Skript _percent.awk_ zur Verfügung, das man idealerweise im Unterverzeichnis _bin_ seines Heimverzeichnisses ablegt.
Das obenstehene _sucspercent_ Alias geht denn auch von diesem Setup aus. Das _awk_-Skript befindet sich [hier](https://www.netnea.com/files/percent.awk).

```bash
$> cat labor-04-example-access.log | alsslprotocol | sucspercent 
                         Entry        Count Percent
---------------------------------------------------
                             -            4   0.04%
                         TLSv1          155   1.55%
                       TLSv1.2        9,841  98.41%
---------------------------------------------------
                         Total        10000 100.00%
```

Wunderbar. Nun sind wir in der Lage für beliebige, sich wiederholende Werte die Zahlenverhältnisse auszugeben. Wie sieht es denn zum Beispiel mit den verwendeten Veschlüsselungsverfahren aus?


```bash
$> cat labor-04-example-access.log | alsslcipher | sucspercent 
                         Entry        Count Percent
---------------------------------------------------
                             -            4   0.04%
                    AES256-SHA           23   0.23%
     DHE-RSA-AES256-GCM-SHA384           42   0.42%
       ECDHE-RSA-AES128-SHA256           50   0.50%
          ECDHE-RSA-AES256-SHA          156   1.56%
   ECDHE-RSA-AES128-GCM-SHA256          171   1.71%
       ECDHE-RSA-AES256-SHA384          234   2.34%
   ECDHE-RSA-AES256-GCM-SHA384        9,320  93.20%
---------------------------------------------------
                         Total        10000 100.00%
```

Ein guter Überblick auf die Schnelle. Damit können wir für den Moment zufrieden sein. Gibt es etwas zu den HTTP-Protokollversionen zu sagen?

```bash
$> cat labor-04-example-access.log | alprotocol | sucspercent 
                         Entry        Count Percent
---------------------------------------------------
                      HTTP/1.0           66   0.66%
                      HTTP/1.1        9,934  99.34%
---------------------------------------------------
                         Total        10000 100.00%
```

Das veraltete _HTTP/1.0_ kommt also durchaus noch vor, aber _HTTP/1.1_ ist klar dominant.

Mit den verschiedenen Aliasen für die Extraktion von Werten aus dem Logfile und den beiden Aliasen _sucs_ und _sucspercent_ haben wir uns handliche Werkzeuge zurecht gelegt, um Fragen nach der relativen Häufigkeit von sich wiederholenden Werten einfach und mit demselben Muster von Befehlen beantworten zu können.

Bei den Messwerten, die sich nicht mehr wiederholen, also etwa der Dauer eines Requests, oder der Grösse der Antworten, nützen uns die Prozentzahlen aber wenig. Was wir brauchen ist eine einfache statistische Auswertung. Gefragt sind der Durchschnitt, vielleicht der Median, Informationen zu den Ausreissern und sinnvollerweise die Standardabweichung.

Auch ein solches Skript steht zum Download bereit: [basicstats.awk](https://www.netnea.com/files/basicstats.awk). Es bietet sich an, dieses Skript ähnlich wie percent.awk im privaten _bin_-Verzeichnis abzulegen.

```bash
$> cat labor-04-example-access.log | alioout | basicstats.awk
Num of values:          10,000.00
         Mean:          19,360.91
       Median:           7,942.00
          Max:       3,920,007.00
        Range:       3,920,007.00
Std deviation:          52,480.41
```

Mit diesen Zahlen wird der Service rasch plastisch. Mit einer durchschnittlichen Antwortgrösse von 19 KB und einem Median von 7.9 KB haben wir einen typischen Webservice vor uns. Der Median bedeutet ja konkret, dass die Hälfte der Antworten kleiner als 7.9 KB waren und die andere Hälfte grösser. Die insgesamt grösste Antwort kam bei 3.9 MB zu stehen, die Standard-Abweichung von knapp 52 KB bedeutet, dass die grossen Werte ingesamt selten waren.

Wie sieht es mit der Dauer der Anfragen aus. Haben wir dort ein ähnlich homogenes Bild?

```bash
$> cat labor-04-example-access.log | alduration | basicstats.awk
Num of values:          10,000.00
         Mean:          74,852.49
       Median:           3,684.50
          Min:             641.00
          Max:      31,360,516.00
        Range:      31,359,875.00
Std deviation:         695,283.17
```

Hier ist es zunächst wichtig, sich zu vergegenwärtigen, dass wir es mit Mikrosekunden zu tun haben. Der Median liegt bei 3684 Mikrosekunden, das sind dreieinhalb Millisekunden. Der Durchschnitt ist mit 74 Millisekunden viel grösser, offensichtlich haben wir zahlreiche Ausreisser, welche den Schnitt in die Höhe gezogen haben. Tatsächlich  haben wir einen Maximalwert von 31 Sekunden und wenig überraschend eine Standardabweichung von 0.7 Sekunden. Das Bild ist also weniger homogen und wir haben zumindest einige Requests, die wir untersuchen sollten. Das wird nun aber etwas komplizierter: Das vorgeschlagene Vorgehen ist nur ein mögliches und es steht hier als Vorschlag und als Inspiration für die weitere Arbeit mit dem Logfile:

```bash
$> cat labor-04-example-access.log | grep "\"GET " | aluri | cut -d\/ -f1,2,3 | sort | \
uniq | while read P; do  MEAN=$(grep "GET $P" labor-04-example-access.log | alduration | \
basicstats.awk | grep Mean | sed 's/.*: //'); echo "$MEAN $P"; done  | sort -n
...
        122,309.45 /cds/holiday-planner-download
        124,395.18 /cds/tools-inventory
        137,230.18 /cds/weather-app
        143,830.30 /cds/2016
        146,114.83 /cds/2015
        163,269.89 /cds/category
        216,229.88 /cds/tutorials
        576,129.71 /storage/static
```

Was passiert hier nacheinander? Wir filtern mittels _grep_ nach _GET_-Requests. Wir ziehen die _URI_ heraus und zerschneiden sie mittels _cut_. Uns interessieren nur die ersten Abschnitte des Pfades. Wir beschränken uns hier, um eine vernünftige Gruppierung zu erhalten, denn zu viele verschiedene Pfade bringen hier wenig Mehrwert. Die so erhaltene Pfadliste sortieren wir alphabetisch und reduzieren sie mittels _uniq_. Das ist die Hälfte der Arbeit.

Nun lesen wir die Pfade nacheinander in die Variable _P_ und bauen darüber mit _while_ eine Schleife. Innerhalb der Schleife berechnen wir für den in _P_ abgespeicherten Pfad die Basisstatistiken und filtern die Ausgabe auf den Durschnitt, wobei wir mit _sed_ so filtern, dass die Variable _MEAN_ nur die Zahl und nicht auch noch die Bezeichnung _Mean:_ enthält. Nun geben wir diesen Durchschnittswert und den Pfadnamen aus. Ende der Schleife. Zu guter letzt sortieren wir alles noch numerisch und erhalten damit eine Übersicht, welche Pfade zu Request…s mit längeren Antwortzeiten geführt haben. Offenbar schiesst ein Pfad namens _/storage/static_ obenaus. Das Stichwort _storage_ lässt dies plausibel erscheinen.

Damit kommen wir zum Abschluss dieser Anleitung. Ziel war es ein erweitertes Logformat einzuführen und die Arbeit mit den Logfiles zu demonstrieren. Dabei kommen wiederkehrend eine Reihe von Aliasen und zwei _awk_-Skripts zum Einsatz, die sich sehr flexibel hintereinander reihen lassen. Mit diesen Werkzeugen und der nötigen Erfahrung in deren Handhabung ist man in der Lage, rasch auf die in den Logfiles zur Verfügung stehenden Informationen zuzugreifen.


### Verweise

* [Dokumentation des Apache-Moduls Log-Config](http://httpd.apache.org/docs/current/mod/mod_log_config.html)
* [Dokumentation des Apache-Moduls SSL](http://httpd.apache.org/docs/current/mod/mod_ssl.html)
* [labor-04-example-access.log](https://www.netnea.com/files/labor-04-example-access.log)
* [.apache-modsec.alias](https://www.netnea.com/files/.apache-modsec.alias)
* [percent.awk](https://www.netnea.com/files/percent.awk)
* [basicstats.awk](https://www.netnea.com/files/basicstats.awk)

### Lizenz / Kopieren / Weiterverwenden

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png" /></a><br />Diese Arbeit ist wie folgt lizenziert / This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.

