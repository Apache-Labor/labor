##Title: Einen Reverse Proxy Server aufsetzen

###Was machen wir?

Wir konfigurieren einen Reverse Proxy oder Gateway Server, der den Zugriff zur Applikation schützt und den Applikationsserver vom Internet abschirmt.

###Warum tun wir das?

Eine moderne Applikationsarchitektur weist mehrere Schichten auf. Gegenüber dem Internet wird nur der Reverse Proxy exponiert. Er führt eine Sicherheitsprüfung auf der Applikationsebene durch und leitet die von ihm für gut befundenen Requests an den Applikationsserver in der zweiten Schicht weiter. Dieser wiederum ist an einen Datenbankserver angebunden, der in einer weiteren Schicht steht. Man spricht von einem Drei-Schichtenmodell (engl. *Three-Tier-Model*). In einer gestaffelten Verteidigung über die drei Schichten hinweg bietet der Reverse Proxy oder technisch korrekt der Gateway Server einen ersten Einblick in die verschlüsselten Anfragen. Auf dem Rückweg ist er wiederum die letzte Instanz, welche die Antworten noch ein letztes Mal überprüfen kann.

Es gibt verschiedene Arten, Apache zu einem Reverse Proxy umzubauen. Vor allem gibt es mehrere Methoden mit den Applikationsservern zu kommunizieren. Wir beschränken und in dieser Anleitung auf das normale, auf *HTTP* basierende *mod_proxy_http*. Weitere Kommunikationsarten wie *FastCGI-Proxy* oder *AJP* behandeln wir hier nicht. Auch auf Apache gibt es mehrere Arten, wie der Proxy-Vorgang angestossen werden kann. Wir betrachten zunächst die normale Konstruktion via *ProxyPass*, besprechen, danach aber auch mehrere Varianten mit Hilfe von *mod_rewrite*.

###Voraussetzungen

* Ein Apache Webserver, idealerweise mit einem File-Layout wie bei [Anleitung 1 (Kompilieren eines Apache Servers)](https://www.netnea.com/cms/apache_tutorial_1_apache_compilieren/) erstellt.
* Verständnis der minimalen Konfiguration in [Anleitung 2 (Apache minimal konfigurieren)](https://www.netnea.com/cms/apache_tutorial_2_apache_minimal_konfigurieren/).
* Ein Apache Webserver mit SSL-/TLS-Unterstützung wie in [Anleitung 4 (Konfigurieren eines SSL Servers)](https://www.netnea.com/cms/apache-tutorial-4-ssl-server-konfigurieren)
* Ein Apache Webserver mit erweitertem Zugriffslog wie in [Anleitung 5 (Das Zugriffslog Ausbauen und Auswerten)](https://www.netnea.com/cms/apache-tutorial-5-zugriffslog-ausbauen/)
* Ein Apache Webserver mit ModSecurity wie in [Anleitung 6 (ModSecurity einbinden)](https://www.netnea.com/cms/apache-tutorial-6-modsecurity-einbinden/)
* Ein Apache Webserver mit einer Core Rules Installation wie in [Anleitung 7 (Core Rules einbinden)](http://www.netnea.com/cms/modsecurity-core-rules-einbinden/)

###Schritt 1: Backend bereitstellen

Der Zweck eines Reverse Proxies ist es, einen Applikationsserver vor direkten Zugriffen aus dem Internet abzuschirmen. Quasi als Voraussetzung für eine diesbezügliche Anleitung benötigen wir also einen solchen Backend-Server.
Prinzipiell bietet sich eine beliebige HTTP Applikation für so eine Installation an und wir könnten gut den Applikationserver aus der dritten Anleitung anwenden. Allerdings scheint es mir gelegen, einen ganz simplen Ansatz zu demonstrieren. Dabei benützen wir das Hilfsmittel *socat*: kurz für *SOcket CAt*. 

```bash
$> sudo socat TCP-LISTEN:8000,bind=127.0.0.1,fork,reuseaddr,crlf EXEC:"/tmp/sender.sh",pty,stderr
``` 

Mit diesem Befehl instruieren wir *socat*, einen *Listener* auf Port 8000 zu installieren und bei einer Verbindung das Skript `/tmp/simpleserver.sh` zu forken. Die weiteren Parameter sorgen dafür, dass der Listener dauerhaft erhalten bleibt, die Errorausgabe funktioniert. Was noch fehlt ist das auszuführende Skript `/tmp/simpleserver.sh`:

```bash
#!/bin/sh
#
# Simple script which prints a http response to stdout.
#

echo "HTTP/1.0 200"
echo "Content-Type: text/txt"
echo "Content-Length: 13"
echo
echo "Hello world!"
```

Vergessen Sie nicht, das die *Permissions* auf *Execute* zu stellen. Probieren wir das mal aus:


```bash
$> ./tmp/simpleserver.sh
HTTP/1.0 200
Content-Type: text/txt
Content-Length: 13

Hello world!
$> curl http://localhost:8000
* Rebuilt URL to: http://localhost:8000/
* Hostname was NOT found in DNS cache
*   Trying 127.0.0.1...
* Connected to localhost (127.0.0.1) port 8000 (#0)
> GET / HTTP/1.1
> User-Agent: curl/7.35.0
> Host: localhost:8000
> Accept: */*
> 
GET / HTTP/1.1
User-Agent: curl/7.35.0
Host: localhost:8000
Accept: */*

HTTP/1.0 200
Content-Type: text/txt
Content-Length: 13

Hello world!
* Connection #0 to host localhost left intact
```

FIXME: Das funktioniert noch nicht so ganz.

Damit haben wir ein Backend-System mit einfachsten Mitteln aufgesetzt. So einfach, dass wir zukünftig vielleicht einmal froh sein werden, diese Technik zu kennen.

###Schritt 2: Das Proxy-Modul laden

Um Apache als *Proxy Server* einsetzen zu können sind mehrere Module nötig. Wir haben sie in der ersten Anleitung mitcompiliert und können Sie nun einfach dazuladen.

```bash
FIXME
```

Die *Proxying* Funktionalität wird also über ein Basis-Modul ein Proxy-HTTP Modul bereit gestellt. Proxying bedeutet ja eigentlich, einen Request entgegenzunehmen und ihn an einen weiteren Server weiterzuleiten. In unserem Fall legen wir das Backendsystem zum Vorneherein fest und nehmen dann Anfragen von verschiedenen Clients für dieses Backend-Service entgegen. Ein anderer Fall ist es dann, wenn man einen Proxy Server aufstellt, der Anfragen von einer Gruppe von Client entgegennimmt und sie an beliebige Server im Internet weitergibt. In diesem Fall spricht von von einem Forward Proxy (FIXME?). Das ist dann sinnvoll, wenn man etwa Clients aus einem Firmennetz nicht direkt im Internet exponieren möchte, denn so tritt der Proxy Server gegenüber den Servern im Internet als Client auf. 

Dieser Modus ist auch bei Apache möglich, wenn auch eher historisch. Es haben sich alternative Software-Pakete etabliert, welche diese Funktionalität anbieten; etwas Squid. Der Fall ist insofern relevant als eine Fehlkonfiguration fatale Folgen haben kann, wenn nämlich der Forward Proxy Anfragen von beliebigen Clients entgegenimmt und sie dann quasi anonym an das Internet weiterleitet. Man spricht in diesem Fall von einem offenen Proxy. Dies gilt es zu verhindern, denn wir möchten Apache nicht in diesem Fall Modus betreiben. Dazu ist eine Direktive nötig, die früher den falschen Defaultwert aufwies, inzwischen aber korrekt auf `off` lautet:

```bash
ProxyRequests Off
```

Diese Direktive meint tatsächlich nur das weiterleiten von Requests an Server im Internet, auch wenn der Name auf eine generellere Einstellung hindeutet. Wie erwähnt ist die Direktive auf Apache 2.4 aber korrekt voreingestellt und sie wird hier nur deshalb erwähnt, damit keine Fragen aufkommen oder um zukünftigen Fehleinstellungen vorzubeugen.

### Schritt 3: ProxyPass

Wir kommen damit zu den eigentlichen *Proxying* Einstellungen. Es gibt mehrere Arten, wie wir Apache instruieren können, einen Request an eine Backend-Applikation weiterzureichen. Wir schauen die Varianten nacheinander an. Die gängige Variante um Anfragen zu proxen basiert auf der Direktive *ProxyPass*. Sie wird wie folgt verwendet.

```bash
ProxyPass		/service1	http://localhost:8000/service1
ProxyPassReverse	/service1	http://localhost:8000/service1

<Proxy http://localhost:8000/service1>

	Require all granted

	AllowOverride none
	Options none

</Proxy>
```

Der wichtigste Befehl ist hier *ProxyPass*. Es definiert einen Pfad `/service1` und gibt an, wie er auf das Backend gemappt wird: Auf den oben definierten Service, der auf unserem eigenen Host, localhost, Port 8000, läuft. Der Pfad auf dem Applikationsserver lautet wieder auf `service1`. Wir proxen also symmetrisch, die Pfade verändern sich nicht. Allerdings ist dieses Mapping nicht zwingend. Es wäre technisch gut möglich von `service1` auf `/` zu proxen, allerdings führt dies zu administrativen Schwierigkeiten und Missverständnissen, wenn ein Pfad im Logfile auf dem Backend nicht mehr dem Pfad auf dem *Reverse Proxy* mappt und man die Anfragen nicht mehr korrelieren kann. 

Auf der nächsten Zeile kommt eine verwandte Direktive, die trotz ähnlichem Namen nur eine kleine Hilfsfunktion übernimmt. *Redirect-Responses* vom Backend sind in *HTTP-konformer* ausprägung voll-qualifiziert. Also etwa `https://backend.example.com/service1`. Für den Client ist diese Adresse aber nicht erreichbar, aus diesem Grund muss der *Reverse Proxy* den sogenannten *Location-Header* des Backends umschreiben, `backend.example.com` durch seinen eigenen Namen ersetzen und damit in seinen eigenen *Namespace* zurückmappen. *ProxyPassReverse*, das so einen vollmundigen Namen besitzt, hat in Wahrheit also nur eine einfache Suchen-Ersetzen Funktion, die auf *Location-Header* greift. Wie schon bei der *Proxy-Pass* Direktive zeigt sich das symmetrische *Proxying*: Die Pfade werden 1:1 übersetzt. Wir sind frei, uns nicht an diese Regel zu halten, aber ich rate dringend dazu diese Regel einzuhalten. Jenseits davon lauern Missverständnisse und Verwirrung.

### Schritt 4: Proxy Stanza

Weiter in der Konfiguration: Nun folgt der *Proxy-Block*, wo die Verbindung zum Backend genauer definiert wird. Namentlich die Authentisierung und Authorisierung eines Requests findet hier statt. Weiter unten in der Anleitung werden wir aber auch einen *Load-Balancer* in diesem Block unterbringen.

Der *Proxy-Block* entspricht dem *Location-* und dem *Directory-Block*, die wir in unserer Konfiguration bereits früher kennengelernt haben. Es handelt sich dabei um sogenannte *Container*. *Container* geben dem Webserver an, wie er die Arbeit strukturieren soll. Sobald er in der Konfiguration einen *Container* antrifft, bereitet er dafür eine Verarbeitungsstruktur vor. Im Fall von *mod_proxy* kann das Backend auf ohne *Proxy-Container* erreicht werden, aber der Verkehr bleibt am verarbeitenden Thread hängen, der sich selbst um die Verbindung zum Backend kümmern muss. Dies ist ineffizient und mittels *ab* auch gut messbar. FIXME: really?

Neben der Performance ist es aber auch im Hinblick auf die Authentisierung sinnvoll, für jedes *Proxy-Backend* einen *Proxy-Block* zu eröffnen. Nur so sind wir ganz sicher, welche Authentisierung genau greift und welche Eigenschaften die Verbindung zum Backend hat. Mittels der Direktive *ProxyOptions* können wir hier noch weiter eingreifen, das Verbindungsverhalten vorgeben FIXME: weitere Beispiele. Weitere Informationen dazu finden sich in der Dokumentation des Apache Projektes.

Eine wesentliche Direktive, die in den *Proxy-Block* gehört betrifft den Timeout. Wir haben für unseren Server einen eigenen Timeout definiert (FIXME: really?). Dieser *Timeout* wird vom Server auch für die Verbindung zum Backend herangezogen. Das ist aber nicht immer sinnvoll, denn während wir vom Client erwarten dürfen, dass er seine Anfragen rasch übermittelt und nicht herumtrödelt, kann es je nach Backend-Applikation dauern, bis eine Anfrage verarbeitet ist. Bei einem kurzen generellen *Timeout*, das aus Verteidigungsgründen gegenüber dem Client sinnvoll ist, würde der Reverse Proxy den Zugriff auf das Backend zu rasch unterbrechen. Aus diesem Grund gibt es die Direktive *ProxyTimeout*, welche einzig die Verbindung zum Backend betrifft. Die Zeitmessung meint dabei übrigens nicht die totale Verarbeitungsdauer auf dem Backend, sondern die Zeitdauer zwischen den IP Paketen: Sobald das Backend einen Teil der Antwort zurückschickt, wird die Uhr wieder zurückgestellt.

### Schritt 5: Proxy Request verstehen

### Schritt 6: ModRewrite [proxy]

### Schritt 7: RewriteMap [proxy]

### Schritt 8: Balancer [proxy]

### Schritt 9: Blabla

### Schritt Bonus: Balancer mit 2 Proxy Stanzas

mod_sed

ProxyPassReverse

Unique-ID forwarden


