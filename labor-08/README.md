##Title: Einen Reverse Proxy Server aufsetzen

###Was machen wir?

Wir konfigurieren einen *Reverse Proxy* oder *Gateway Server*, der den Zugriff zur Applikation schützt und den Applikationsserver vom Internet abschirmt. Dabei lernen wir mehrere Arten der Konfiguration kennen und arbeiten auch erstmals mit *ModRewrite*.

###Warum tun wir das?

Eine moderne Applikationsarchitektur weist mehrere Schichten auf. Gegenüber dem Internet wird nur der *Reverse Proxy* exponiert. Er führt eine Sicherheitsprüfung auf der Applikationsebene durch und leitet die von ihm für gut befundenen Anfragen an den Applikationsserver in der zweiten Schicht weiter. Dieser wiederum ist an einen Datenbankserver angebunden, der in einer weiteren Schicht steht. Man spricht von einem Drei-Schichtenmodell (engl. *Three-Tier-Model*). In einer gestaffelten Verteidigung über die drei Schichten hinweg bietet der *Reverse Proxy* oder technisch korrekt der *Gateway Server* einen ersten Einblick in die verschlüsselten Anfragen. Auf dem Rückweg ist er wiederum die letzte Instanz, welche die Antworten noch ein letztes Mal überprüfen kann.

Es gibt verschiedene Arten, Apache zu einem *Reverse Proxy* umzubauen. Vor allem gibt es mehrere Methoden mit den Applikationsservern zu kommunizieren. Wir beschränken uns in dieser Anleitung auf das normale, auf *HTTP* basierende *mod_proxy_http*. Weitere Kommunikationsarten wie *FastCGI-Proxy* oder *AJP* behandeln wir hier nicht. Auch auf Apache gibt es mehrere Arten, wie der Proxy-Vorgang angestossen werden kann. Wir betrachten zunächst die normale Konstruktion via *ProxyPass*, besprechen, danach aber auch mehrere Varianten mit Hilfe von *mod_rewrite*.

###Voraussetzungen

* Ein Apache Webserver, idealerweise mit einem File-Layout wie bei [Anleitung 1 (Kompilieren eines Apache Servers)](https://www.netnea.com/cms/apache_tutorial_1_apache_compilieren/)
* Verständnis der minimalen Konfiguration in [Anleitung 2 (Apache minimal konfigurieren)](https://www.netnea.com/cms/apache_tutorial_2_apache_minimal_konfigurieren/)
* Ein Apache Webserver mit SSL-/TLS-Unterstützung wie in [Anleitung 4 (Konfigurieren eines SSL Servers)](https://www.netnea.com/cms/apache-tutorial-4-ssl-server-konfigurieren)
* Ein Apache Webserver mit erweitertem Zugriffslog wie in [Anleitung 5 (Das Zugriffslog Ausbauen und Auswerten)](https://www.netnea.com/cms/apache-tutorial-5-zugriffslog-ausbauen/)
* Ein Apache Webserver mit ModSecurity wie in [Anleitung 6 (ModSecurity einbinden)](https://www.netnea.com/cms/apache-tutorial-6-modsecurity-einbinden/)
* Ein Apache Webserver mit einer Core Rules Installation wie in [Anleitung 7 (Core Rules einbinden)](http://www.netnea.com/cms/modsecurity-core-rules-einbinden/)

###Schritt 1: Backend bereitstellen

Der Zweck eines Reverse Proxies ist es, einen Applikationsserver vor direkten Zugriffen aus dem Internet abzuschirmen. Quasi als Voraussetzung für eine diesbezügliche Anleitung benötigen wir also einen solchen Backend-Server.
Prinzipiell bietet sich eine beliebige HTTP Applikation für so eine Installation an und wir könnten gut den Applikationserver aus der dritten Anleitung anwenden. Allerdings scheint es mir gelegen, einen ganz simplen Ansatz zu demonstrieren. Dabei benützen wir das Hilfsmittel *socat*; kurz für *SOcket CAt*. 

```bash
$> socat -vv TCP-LISTEN:8000,bind=127.0.0.1,crlf,reuseaddr,fork SYSTEM:"echo HTTP/1.0 200; echo Content-Type\: text/plain; echo; echo 'Server response, port 8000.'"
``` 

Mit diesem komplexen Befehl instruieren wir *socat*, einen *Listener* auf dem lokalen Port 8000 zu installieren und bei einer Verbindung mittels mehrerer *echos* eine HTTP Antwort zu retournieren. Die weiteren Parameter sorgen dafür, dass der Listener dauerhaft erhalten bleibt und die Errorausgabe funktioniert.

```bash
$> curl -v http://localhost:8000/
* Hostname was NOT found in DNS cache
*   Trying 127.0.0.1...
* Connected to localhost (127.0.0.1) port 8000 (#0)
> GET / HTTP/1.1
> User-Agent: curl/7.35.0
> Host: localhost:8000
> Accept: */*
> 
* HTTP 1.0, assume close after body
< HTTP/1.0 200
< Content-Type: text/plain
< 
Server response, port 8000
* Closing connection 0
```

Damit haben wir ein Backend-System mit einfachsten Mitteln aufgesetzt. So einfach, dass wir zukünftig vielleicht einmal froh sein werden, diese Technik zu kennen, wenn rasch das Funktionieren eines Proxy Servers belegen möchten, bevor das richtige Backend bereits läuft.

###Schritt 2: Das Proxy-Modul laden

Um Apache als *Proxy Server* einsetzen zu können, sind mehrere Module nötig. Wir haben sie in der ersten Anleitung mitkompiliert und können sie nun einfach dazuladen.

```bash
LoadModule              proxy_module            modules/mod_proxy.so
LoadModule              proxy_http_module       modules/mod_proxy_http.so
```

Die *Proxying* Funktionalität wird also über ein Proxy-Basis-Modul sowie ein Proxy-HTTP-Modul bereit gestellt. *Proxying* bedeutet ja eigentlich, einen Request entgegenzunehmen und ihn an einen weiteren Server weiterzuleiten. In unserem Fall legen wir das Backend-System zum vorneherein fest und nehmen dann Anfragen von verschiedenen Clients für diesen Backend-Service entgegen. Ein anderer Fall ist es dann, wenn man einen Proxy Server aufstellt, der Anfragen von einer Gruppe von Clients entgegen nimmt und sie an beliebige Server im Internet weitergibt. In diesem Fall spricht man von einem *Forward Proxy*. Das ist dann sinnvoll, wenn man etwa Clients aus einem Firmennetz nicht direkt im Internet exponieren möchte, denn so tritt der Proxy Server gegenüber den Servern im Internet als Client auf.

Dieser Modus ist auch bei Apache möglich, wenn auch eher historisch. Es haben sich alternative Software-Pakete etabliert, welche diese Funktionalität anbieten; etwa *Squid*. Der Fall ist insofern relevant als eine Fehlkonfiguration fatale Folgen haben kann, wenn nämlich der *Forward Proxy* Anfragen von beliebigen Clients entgegenimmt und sie dann quasi anonym an das Internet weiterleitet. Man spricht in diesem Fall von einem offenen Proxy. Dies gilt es zu verhindern, denn wir möchten Apache nicht in diesem Modus betreiben. Dazu ist eine Direktive nötig, die früher den gefährlichen Defaultwert `on` aufwies, inzwischen aber korrekt auf `off` voreingestellt ist:

```bash
ProxyRequests Off
```

Diese Direktive meint tatsächlich nur das Weiterleiten von Requests an Server im Internet, auch wenn der Name auf eine generellere Einstellung hindeutet. Wie erwähnt ist die Direktive auf Apache 2.4 aber korrekt voreingestellt und sie wird hier nur deshalb erwähnt, um Fragen oder zukünftigen Fehleinstellungen vorzubeugen.

### Schritt 3: ProxyPass

Wir kommen damit zu den eigentlichen *Proxying* Einstellungen: Es gibt mehrere Arten, wie wir Apache instruieren können, einen Request an eine Backend-Applikation weiterzureichen. Wir schauen die Varianten nacheinander an. Die gängige Variante um Anfragen zu proxen basiert auf der Direktive *ProxyPass*. Sie wird wie folgt verwendet:

```bash
ProxyPass		/service1	http://localhost:8000/service1
ProxyPassReverse	/service1	http://localhost:8000/service1

<Proxy http://localhost:8000/service1>

	Require all granted

	AllowOverride none
	Options none

</Proxy>
```

Der wichtigste Befehl ist hier *ProxyPass*. Er definiert einen Pfad `/service1` und gibt an, wie er auf das Backend gemappt wird: Auf den oben definierten Service, der auf unserem eigenen Host, localhost, Port 8000, läuft. Der Pfad auf dem Applikationsserver lautet wieder auf `/service1`. Wir proxen also symmetrisch, die Pfade verändern sich nicht. Allerdings ist dieses Mapping nicht zwingend. Es wäre technisch gut möglich von `service1` auf `/` zu proxen, allerdings führt dies zu administrativen Schwierigkeiten und Missverständnissen, wenn ein Pfad im Logfile auf dem Backend nicht mehr dem Pfad auf dem *Reverse Proxy* mappt und man die Anfragen nicht mehr korrelieren kann.

Auf der nächsten Zeile kommt eine verwandte Direktive, die trotz ähnlichem Namen nur eine kleine Hilfsfunktion übernimmt. *Redirect-Responses* vom Backend sind in *http-konformer* Ausprägung voll-qualifiziert. Also etwa `https://backend.example.com/service1`. Für den Client ist diese Adresse aber nicht erreichbar. Aus diesem Grund muss der *Reverse Proxy* den sogenannten *Location-Header* des Backends umschreiben, `backend.example.com` durch seinen eigenen Namen ersetzen und damit in seinen eigenen *Namespace* zurückmappen. *ProxyPassReverse*, das so einen vollmundigen Namen besitzt, hat in Wahrheit also nur eine einfache Suchen-Ersetzen Funktion, die auf *Location-Header* greift. Wie schon bei der *Proxy-Pass* Direktive zeigt sich das symmetrische *Proxying*: Die Pfade werden 1:1 übersetzt. Wir sind frei, uns nicht an diese Regel zu halten, aber ich rate dringend dazu diese Regel einzuhalten, denn jenseits davon lauern Missverständnisse und Verwirrung. Neben dem Zugriff auf den *Location-Header* gibt es eine Reihe von weiteren *Reverse-Direktiven*, die sich etwa um Cookies etc. kümmern. Dies kann fallweise hilfreich sein.

### Schritt 4: Proxy Stanza

Weiter in der Konfiguration: Nun folgt der *Proxy-Block*, wo die Verbindung zum Backend genauer definiert wird. Namentlich Authentisierung und Autorisierung eines Requests finden hier statt. Weiter unten in der Anleitung werden wir aber auch einen *Load-Balancer* in diesem Block unterbringen.

Der *Proxy-Block* entspricht dem *Location-* und dem *Directory-Block*, die wir in unserer Konfiguration bereits früher kennengelernt haben. Es handelt sich dabei um sogenannte *Container*. *Container* geben dem Webserver an, wie er die Arbeit strukturieren soll. Sobald er in der Konfiguration einen *Container* antrifft, bereitet er dafür eine Verarbeitungsstruktur vor. Im Fall von *mod_proxy* kann das Backend auch ohne *Proxy-Container* erreicht werden. Der Zugriffsschutz bleibt dabei aber unberücksichtigt und auch weitere Direktiven besitzen damit keinen Ort mehr in den sie eingebracht werden können. Ohne *Proxy-Block* bleibt die Verarbeitung bei komplexeren Servern immer etwas zufällig und wir tun gut daran, diesen Teil mitzukonfigurieren. Mittels der Direktive *ProxySet* können wir dann hier noch weiter eingreifen und etwa das Verbindungsverhalten vorgeben. Mit *min*, *max* und *smax* können die Anzahl Threads, die dem Proxy Connection Pool zugewiesen werden, spezifiziert werden. Dies kann fallweise die Performance beeinflussen. Das *Keepalive Verhalten* der Proxy-Verbindung lässt sich beeinflussen und auch verschiedene *Timeout*-Werte sind so zu definieren. Weitere Informationen dazu finden sich in der Dokumentation des Apache Projektes.

### Schritt 5: Ausnahmen beim Proxying definieren und weitere Einstellungen vornehmen

Die von uns verwendete _ProxyPass_ Direktive hat die Gesamtheit der Requests für `/service1` an das Backend weitergegeben. In der Praxis kommt es aber oft vor, dass man nicht ganz alles weitergeben möchte. Stellen wir uns vor, dass es den Pfad `/service1/admin` gibt, den wir nicht im Internet exponieren möchten. Dies lässt sich ebenfalls mit Hilfe der richtigen _ProxyPass_ Einstellung verhindern, wobei die Ausnahme mittels des Ausrufezeichens initiiert wird. Wichtig ist es, die Ausnahme zu definieren, bevor der eigentliche Proxy-Befehl konfiguriert wird:

```bash
ProxyPass 		/service1/admin !
ProxyPass		/service1	http://localhost:8000/service1
ProxyPassReverse	/service1	http://localhost:8000/service1
```

Oft sieht man Konfigurationen, die den gesamten Namespace unter `/` an das Backend weitergeben. Dazu werden dann oft eine Vielzahl von Ausnahmen nach obenstehendem Muster definiert. Ich halte das für den falschen Ansatz und ziehe es vor, nur das weiterzureichen, was auch tatsächlich verarbeitet werden wird. Der Vorteil liegt auf der Hand: Scanner und automatisierte Angriffe, die sich aus dem Pool der IP-Adressen des Internets ihre Opfer suchen, stellen Requests mit einer Vielzahl nicht-existierender Pfade an unseren Server. Wir können die nun auf das Backend weiterreichen und je nachdem das Backend belasten oder sogar gefährden. Oder aber wir blockieren diese Anfragen bereits auf dem Reverse Proxy Server. Letzteres ist aus Gründen der Sicherheit klar vorzuziehen.

Eine wesentliche Direktive, die optional zum Proxygehört betrifft den Timeout. Wir haben für unseren Server einen eigenen *Timeout*-Wert definiert. Dieser *Timeout* wird vom Server auch für die Verbindung zum Backend herangezogen. Das ist aber nicht immer sinnvoll, denn während wir vom Client erwarten dürfen, dass er seine Anfragen rasch übermittelt und nicht herumtrödelt, kann es je nach Backend-Applikation dauern, bis eine Anfrage verarbeitet ist. Bei einem kurzen generellen *Timeout*, das aus Verteidigungsgründen gegenüber dem Client sinnvoll ist, würde der *Reverse Proxy* den Zugriff auf das Backend zu rasch unterbrechen. Aus diesem Grund gibt es die Direktive *ProxyTimeout*, welche einzig die Verbindung zum Backend betrifft. Die Zeitmessung meint dabei übrigens nicht die totale Verarbeitungsdauer auf dem Backend, sondern die Zeitdauer zwischen den IP Paketen: Sobald das Backend einen Teil der Antwort zurückschickt, wird die Uhr wieder zurückgestellt.

```bash
ProxyTimeout	60
```

Daneben bietet es sich an, auch den *Host Header* zu fixieren. Mittels des HTTP Request Host Headers gibt der Client bekannt, welchen *VirtualHost* eines Servers die Anfrage bedienen soll. Wenn mehrere *VirtualHosts* unter derselben IP-Adresse betrieben werden, ist dieser Wert entscheidend. Beim Weiterleiten setzt der *Reverse Proxy* aber normalerweise einen neuen Host Header; nämlich denjenigen des Backend-Systems. Dies ist aber oft nicht gewünscht, denn das Backend-System wird in vielen Fällen basierend auf diesem Host Header seine Links setzen. Voll qualifizierte Links sind zwar für Backend-Applikationen eine schlechte Praxis, aber wir vermeiden Konflikte, wenn wir von Beginn weg klarstellen, dass der Host Header erhalten bleiben und 1:1 an das Backend weitergegeben werden soll.

```bash
ProxyPreserveHost	On
```

Backend-Systeme achten oft weniger auf die Sicherheit als ein Reverse Proxy. Ein Bereich, wo das sichtbar wird, sind Fehlermeldungen. Oft sind detaillierte Fehlermeldungen sogar gewünscht, denn sie erlauben dem Entwickler oder Backend Administrator, einem Fehler überhaupt erst auf die Schliche zu kommen. Über das Internet möchten wir sie aber nicht verteilen, denn ohne Authentifizierung auf dem *Reverse Proxy* könnte sich hinter dem Client ja immer ein Angreifer verstecken. Besser ist es also, die Fehlermeldungen der Backend Applikation zu verbergen, respektive durch eine Fehlermeldung des *Reverse Proxies* zu ersetzen. Die Direktive *ProxyErrorOverride* greift also in den HTTP Response Body ein und ersetzt ihn, wenn ein Status Code grösser gleich 400 vorliegt. Die Anfragen mit normalen Stati unter 400 sind von dieser Direktiven nicht betroffen.

```bash
ProxyErrorOverride	On
```

### Schritt 6: ModRewrite

Neben der Direktive _ProxyPass_ kann auch das *Rewrite-Modul* eingesetzt werden, um die *Reverse Proxy*-Funktionalität auszulösen. Gegenüber dem *ProxyPass* erlaubt dies eine flexiblere Konfiguration. Wir haben *ModRewrite* bis dato nicht gesehen. Da es sich dabei um ein sehr wichtiges Modul handelt, sollten wir es gründlich studieren.

*ModRewrite* definiert eine eigene *RewriteEngine*, welche dazu benutzt wird, einen HTTP Request zu manipulieren; eben umzuschreiben. Diese *RewriteEngine* kann im Server-Kontext, aber auch im *VirtualHost-Kontext* laufen. Genau genommen verwenden wir zwei separate *RewriteEngines*. Die *RewriteEngine* im *VirtualHost-Kontext* kann dabei auch aus dem *Proxy-Container*, den wir oben kennengelernt haben, konfiguriert werden. Wenn wir im Server-Kontext eine *RewriteEngine* definieren, dann kann es passieren, dass diese umgangen wird, wenn eine *Engine* im *VirtualHost-Kontext* existiert. Wir müssen in diesem Fall von Hand dafür sorgen, dass die sogenannten Rewrite-Rules vererbt werden. Setzen wir also im Server-Kontext eine *RewriteEngine* auf, konfigurieren eine Beispiel-Regel und initiieren die Vererbung:

```bash
LoadModule              rewrite_module          modules/mod_rewrite.so
LoadModule              headers_module          modules/mod_headers.so

...

RewriteEngine           On
RewriteOptions          InheritDownBefore

RewriteRule   		^/$	%{REQUEST_SCHEME}://%{HTTP_HOST}/index.html  [redirect,last]
```

Wir initialisieren also die Engine auf Stufe Server. Dann instruieren wir die Engine, die eigenen Regeln an weitere Rewrite Engines zu vererben. Und zwar so, dass die eigenen Regeln vor den nachgeordneten Regeln ausgeführt werden. Danach folgt die eigentliche Regel. Wir instruieren hierbei den Server, bei einem Request ohne Pfad, also einem Request auf "/", den Client zu instruieren, doch eine neue Anfrage an _/index.html_ abzusetzen. Man spricht von einem _Redirect_. Wichtig ist, dass ein *Redirect* sowohl das Schema des Requests, also *http* oder *https*, als auch den Hostnamen aufweisen muss. Relative Pfade funktionieren somit nicht. Da wir ausserhalb des *VirtualHosts* stehen, kennen wir das Schema aber nicht. Und den Hostnamen möchten wir auch nicht hart codieren, sondern lieber den Hostnamen aus dem Request des Clients übernehmen. Diese beiden Werte stehen als Variablen zur Verfügung, wie man im obenstehenden Beispiel sehen kann.

In eckigen Klammern kommen dann Flags zu stehen, welche das Verhalten der RewriteRule beeinflussen. Wir wünschen wie erwähnt einen *Redirect* und teilen der *Engine* dann mit, dass dies die letzte zu verarbeitende Regel sein soll (*last*).

Schauen wir uns einen entsprechenden Request und den retournierten Redirect einmal an:

```bash
$> curl -v http://localhost/
* Hostname was NOT found in DNS cache
*   Trying 127.0.0.1...
* Connected to localhost (127.0.0.1) port 80 (#0)
> GET / HTTP/1.1
> User-Agent: curl/7.35.0
> Host: localhost
> Accept: */*
> 
< HTTP/1.1 302 Found
< Date: Thu, 10 Dec 2015 05:24:42 GMT
* Server Apache is not blacklisted
< Server: Apache
< Location: http://localhost/index.html
< Content-Length: 211
< Content-Type: text/html; charset=iso-8859-1
< 
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>302 Found</title>
</head><body>
<h1>Found</h1>
<p>The document has moved <a href="http://localhost/index.html">here</a>.</p>
</body></html>
* Connection #0 to host localhost left intact
```

Der Server antwortet also neu mit dem HTTP Status Code *302 Found*, der einem typischen *Redirect Status Code* entspricht. Alternativ kommen auch *301*, *303*, *307* oder ganz selten *308* vor. Die Unterschiede sind subtil, beeinflussen aber das Verhalten des Browsers. Wichtig ist dann der *Location-Header*. Er instruiert den Client, einen neuen Request abzusetzen und zwar auf die hier spezifizierte voll qualifiziert URL mit einem Schema. Dies ist für den *Location Header* Pflicht. Hier nur den Pfad zu retournieren in der Annahme, der Client werde dann richtig schliessen, dass es sich um denselben Servernamen handelt, ist falsch und gemäss den Spezifikationen verboten.

Im Response Body-Teil der Antwort wird der Redirect als Link in einen html-Text integriert. Das bedeutet, dass ein User ihn von Hand anklicken könnte, wenn der Browser dem Redirect nicht folgen sollte. Dies ist aber sehr unwahrscheinlich und hat meines Erachtens eher historische Gründe.

Nun kann man sich fragen, weshalb wir im Server-Kontext überhaupt eine *RewriteEngine* eröffnen und nicht alles auf Stufe *VirtualHost* behandeln. Im von mir gewählten Beispiel sieht man, dass dies zu Redundanz führen würde, denn der Redirect von "/" nach "index.html" soll ja auf Port 80 als auch auf dem verschlüsselten Port 443 zur Anwendung kommen. Das ist auch in etwa die Faustregel: Was auf sämtlichen *VirtualHosts* angewendet werden soll, das legen wir mit Vorteil im Server-Kontext fest und vererben es. Individuelle Regeln eines einzigen *VirtualHosts* behandeln wir auch auf dieser Stufe. Typisch ist etwa die folgende Regel, mit der wir sämtliche Anfragen von Port 80 auf Port 443 redirecten können:

```bash
<VirtualHost 127.0.0.1:80>
      
	RewriteEngine		On

	RewriteRule		^/(.*)$	https://%{HTTP_HOST}/$1	[redirect,last]

	...

</VirtualHost>
```

Das gewünschte Schema ist nun klar. Aber links davon ist ein neues Element hinzugekommen. Den Pfad klemmen wir nicht mehr so rasch wie oben ab. Vielmehr fassen wir ihn in eine Klammer und referenzieren den Inhalt der Klammer dahinter wieder im *Redirect* mit *$1*. Das bedeutet, dass wir eine Anfrage auf Port 80 mit derselben URL sogleich an Port 443 weiterverweisen.

Damit ist *ModRewrite* eingeführt. Für weitere Beispiele sei hier auf die Dokumentation verwiesen oder die nachfolgenden Kapitel dieser Anleitung, wo wir noch weitere Rezepte kennenlernen werden.

### Schritt 7: ModRewrite [Proxy]

Wir haben gesehen wie eine *RewriteEngine* initialisiert wird und wie man einfache und etwas komplexere Redirects auslösen kann. Nun werden wir mit diesen Mitteln einen *Reverse Proxy* konfigurieren. Das machen wir wie folgt:

```bash

<VirtualHost 127.0.0.1:443>

    ...

    RewriteEngine	On

    RewriteRule		^/service1/(.*)		http://localhost:8000/service1/$1 [proxy,last]
    ProxyPassReverse	/	              	http://localhost:8000/

    <Proxy http://localhost:8000/service1>

	Require all granted

	AllowOverride none
	Options none

    </Proxy>

```

Die Instruktion folgt einem ähnlichen Muster wie die Variante mit ProxyPass. Allerdings wird hier der hintere Teil des Pfades explizit mittels einer Klammer eingefangen und wie oben bereits gesehen durch "$1" wieder ausgedrückt. Anstatt dem vorangegangenen *Redirect-Flag* kommt nun *proxy* zur Anwendung. *ProxyPassReverse* und die Proxy-Stanza bleiben dann identisch zum Setup via *ProxyPass*.

Soweit die einfache Konfiguration mittels einer RewriteRule. Sie bringt noch keinen wirklichen Vorteil über die *ProxyPass*-Syntax. Die Referenzierung von Pfadteilen mittels *$1*, *$2* etc. bringt etwas an Flexibilität. Aber wenn wir ohnehin mit RewriteRules arbeiten, dann stellen wir durch das RewriteRule-Proxying sicher, dass sich RewriteRule und ProxyPass nicht in die Quere kommen, indem sie denselben Request berühren und sich gegenseitig beeinflussen.

Nun kann es aber sein, dass wir mit einem einzelnen Reverse Proxy mehrere Backends zusammenfassen oder die Last auf mehrere Server verteilen möchten. Ein eigentlicher LoadBalancer ist dazu gefragt. Das sehen wir uns im nächsten Abschnitt an:

### Schritt 8: Balancer [proxy]

Den Apache Loadbalancer müssen wir zunächst als Modul laden:

```bash
LoadModule        proxy_balancer_module           modules/mod_proxy_balancer.so
LoadModule        lbmethod_byrequests_module      modules/mod_lbmethod_byrequests.so
LoadModule	  slotmem_shm_module              modules/mod_slotmem_shm.so
```

Neben dem Loadbalancer-Modul selbst benötigen wir auch ein Modul, welches uns dabei hilft, die Anfragen auf die verschiedenen Backends zu verteilen. Wir gehen den einfachsten Weg und laden das Modul *lbmethod_byrequests*.
Es ist das älteste Modul aus einer Reihe von vier Modulen und verteilt die Anfragen gleichmässig auf die Backends, indem es diese nacheinander abzählt. Bei zwei Backends also einmal nach links und einmal nach rechts.

Hier die Liste der zur Verfügung stehenden Algorithmen:

* mod_lbmethod_byrequests (Abzählen der Requests)
* mod_lbmethod_bytraffic (Aufsummieren der Grösse der Anfragen und der Antworten)
* mod_lbmethod_bybusyness (Loadbalancing aufgrund der aktiven Threads in einer stehenden Verbindung mit den Backends. Das Backend mit der kleinsten Anzahl Threads erhält den nächsten Request)
* mod_lbmethod_heartbeat (Hier kann das Backend einen sogenannten Heartbeat im Netz kommunizieren und dem Reverse Proxy dadurch mitteilen, ob es noch Kapazität frei hat).

Die verschiedenen Module sind online gut dokumentiert, so dass diese knappen Beschreibungen hier für den Moment reichen. Und schliesslich benötigen wir noch ein Modul, das uns bei der Verwaltung von gemeinsam benutzten Speichersegmenten hilft. Diese Funktionalität wird durch das Proxy-Balancer-Modul benötigt und durch `mod_slotmem_shm.so` zur Verfügung gestellt.

Damit sind wir bereit für die Konfiguration des Loadbalancers. Wir können ihn jetzt über die inzwischen bekannte RewriteRule einführen. Diese Anpassung der RewriteRule wirkt sich auch auf die Proxy-Stanza aus, wo der eben definierte Balancer referenziert und aufgelöst werden muss:

```bash
    RewriteRule 	^/service1/(.*)		balancer://backend/service/$1   [proxy,last]
    ProxyPassReverse    /         		balancer://backend/

    <Proxy balancer://backend>
        BalancerMember http://localhost:8000 route=backend-port-8000
        BalancerMember http://localhost:8001 route=backend-port-8001

        Require all granted

        AllowOverride none
        Options none

    </Proxy>
```

Hier definieren wir also zwei Backends, eines auf dem bereits konfigurierten Port 8000 und ein zweites auf Port 8001. Ich schlage vor, diesen Service rasch mittels socat auf dem zweiten Port einzurichten und dann auszuprobieren. Ich habe zwei unterschiedliche Antworten definiert, so dass wir anhand der HTTP Response erkennen können, welches Backend den Request bearbeitet hat. Die sieht dann so aus:

```bash
$> curl -v -k https://localhost/service1/index.html https://localhost/service1/index.html
* Hostname was NOT found in DNS cache
*   Trying 127.0.0.1...
* Connected to localhost (127.0.0.1) port 443 (#0)
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
* 	 subject: CN=lubuntu.fritz.box
* 	 start date: 2013-10-26 18:00:21 GMT
* 	 expire date: 2023-10-24 18:00:21 GMT
* 	 issuer: CN=lubuntu.fritz.box
* 	 SSL certificate verify ok.
> GET /service1/index.html HTTP/1.1
> User-Agent: curl/7.35.0
> Host: localhost
> Accept: */*
> 
< HTTP/1.1 200 
< Date: Thu, 10 Dec 2015 05:42:14 GMT
* Server Apache is not blacklisted
< Server: Apache
< Content-Type: text/plain
< Content-Length: 28
< 
Server response, port 8000
* Connection #0 to host localhost left intact
* Found bundle for host localhost: 0x24e3660
* Re-using existing connection! (#0) with host localhost
* Connected to localhost (127.0.0.1) port 443 (#0)
> GET /service1/index.html HTTP/1.1
> User-Agent: curl/7.35.0
> Host: localhost
> Accept: */*
> 
< HTTP/1.1 200 
< Date: Thu, 10 Dec 2015 05:42:14 GMT
* Server Apache is not blacklisted
< Server: Apache
< Content-Type: text/plain
< Content-Length: 28
< 
Server response, port 8001
* Connection #0 to host localhost left intact
```

In diesem etwas ungewohnten Aufruf werden zwei identische Requests mit einem einzigen Curl-Befehl initiiert. Interessant ist unter anderem der Umstand, dass mit dieser Methode HTTP Keep-Alive von curl angewendet wird. Beim ersten Request landete der Request auf dem ersten Backend, beim zweiten Request auf dem zweiten Backend. Schauen wir uns die zugehörigen Einträge im Access-Log des Servers an:

```bash
127.0.0.1 - - [2015-12-10 06:42:14.390998] "GET /service1/index.html HTTP/1.1" 200 28 "-" "curl/7.35.0" localhost 127.0.0.1 443 proxy-server backend-port-8000 + "-" VmkQtn8AAQEAAH@M3zAAAAAN TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 538 1402 -% 7856 1216 3708 381 0 0
127.0.0.1 - - [2015-12-10 06:42:14.398995] "GET /service1/index.html HTTP/1.1" 200 28 "-" "curl/7.35.0" localhost 127.0.0.1 443 proxy-server backend-port-8001 + "-" VmkQtn8AAQEAAH@M3zEAAAAN TLSv1.2 ECDHE-RSA-AES256-GCM-SHA384 121 202 -% 7035 1121 3752 354 0 0
```

Neben dem erwähnten Keep-Alive ist der Request-Handler von Interesse. Der Request wurde also vom _proxy-server Handler_ bearbeitet. Auch bei der Route sehen wir Einträge, nämlich die oben definierten Werte _backend-port-8000_ und _backend-port-8001_. So ist es uns also möglich, im Access-Log des Servers festzustellen, welche Route ein Request genau genommen hat.

In einer späteren Anleitung werden wir sehen, dass sich der Proxy-Balancer auch in anderen Situationen anwenden lässt. Für den Moment begnügen wir uns aber mit dem Gesehenen und wenden uns den RewriteMaps zu. Bei RewriteMaps handelt es sich um eine Hilfskonstruktion, welche die Mächtigkeit von ModRewrite nochmals erhöht. Wenn wir es mit dem Proxy-Server kombinieren, dann erhöht sich die Flexibilität massiv.

### Schritt 9: RewriteMap [proxy]

RewriteMaps kommen in verschiedenen Ausprägungen vor. Ihre Funktion besteht darin, bei jedem Aufruf einem Schlüssel-Paramter einen Wert zuzuordnen. Eine Hash-Tabelle ist ein einfaches Beispiel. Dann ist es aber auch möglich, externe Skripte als programmierbare RewriteMap zu konfigurieren. Die folgenden Typen von Maps sind möglich:

* txt : Hier wird in einem Text-File nach Schlüssel-Wert-Paaren gesucht.
* rnd : Hier können pro Schlüssel mehrere Werte vorgegeben werden. Sie werden dann zufällig ausgewählt.
* dbm : Diese Variante funktioniert wie die txt-Variante, hat aber als binäre Hash-Tabelle einen grossen Geschwindigkeitsvorteil.
* int : Dieses Kürzel steht für *internal function* und meint eine Funktion aus folgender Liste: *toupper*, *tolower*, *escape* und *unescape*.
* prg : In dieser Variante wird ein externes Skript aufgerufen. Das Skript wird beim Start des Servers gestartet und erhält bei jedem Aufruf der RewriteMap neuen Input via STDIN.
* dbd und fastdbd : Hier wird der Rückgabewert über eine Datenbank-Anfrage gesucht.

Diese Liste macht deutlich, dass RewriteMaps äusserst flexibel sind und in verschiedensten Situationen zur Anwendung kommen können. Die Bestimmung eines Backends für das Proxying ist nur eine von vielen Anwendungsmöglichkeiten. In unserem Beispiel möchten wir sicherstellen, dass ein bestimmter Client mit seinen Anfragen immer auf dasselbe Backend gelangt. Es gibt verschiedene Arten, das zu erreichen, wobei namentlich das Setzen eines Cookies genannt sei. Wir möchten aber nicht in die Requests eingreifen und gleichzeitig vermeiden, dass eine grosse Gruppe von Clients aus einem bestimmten Netzwerkbereich alle auf dasselbe Backend gelangen. Eine gewisse Verteilung soll also stattfinden. Dazu kombinieren wir ModSecurity mit ModRewrite und einer RewriteMap. Sehen wir uns das nach und nach an.

Zunächst bilden wir aus der IP-Adresse des Clients einen Hashwert. Das heisst, wir verwandeln die IP-Adresse in eine zufällige hexadezimale Zeichenfolge:

```bash
SecRule REMOTE_ADDR	"^(.)"	"phase:1,id:50001,capture,nolog,t:sha1,t:hexEncode,setenv:IPHashChar=%{TX.1}"
```

Den mittels der sha1-Funktion generierten binären Hash-Wert haben wir mittels hexEncode in lesbare Zeichen umgewandelt. Auf diesem Wert wenden wir dann den regulären Ausdruck an. "^(.)" meint dabei, dass wir einen Match auf einem beliebigen ersten Zeichen erzielen möchten. Von den darauf folgenden ModSecurity Flags ist namentlich *capture* von Interesse, das den Wert in der Klammer der ersten Transaktionsvariablen *TX.1* zuweist. Aus dieser Variable nehmen wir den Wert dann auf und legen ihn in der Umgebungsvariable IPHashChar.

Wenn Unsicherheit besteht, ob dies wirklich funktioniert, dann lässt sich der Inhalt der Variable *IPHashChar* mittels *%{IPHashChar}e* im Access-Log des Servers abbilden und kontrollieren. Damit kommen wir zur RewriteMap und dem Aufruf derselben:

```bash
RewriteMap hashchar2backend "txt:/apache/conf/hashchar2backend.txt"

RewriteCond 	"%{ENV:IPHashChar}"	^(.)
RewriteRule 	^/service1/(.*)		http://${hashchar2backend:%1|localhost:8000}/service1/$1 [proxy,last]

<Proxy http://localhost:8000/service1>

    Require all granted

    AllowOverride none
    Options none

</Proxy>

<Proxy http://localhost:8001/service1>

    Require all granted

    AllowOverride none
    Options none

</Proxy>
```

Wir führen die Map mittels des Befehls RewriteMap ein. Wir teilen ihr einen Namen zu, definieren ihren Typ und den Weg zum File. Der Aufruf der RewriteMap passiert in einer RewriteRule. Bevor wir die Map wirklich aufrufen, schalten wir eine Rewrite Bedingung ein. Dies geschieht mittels dem Befehl *RewriteCond*. Dort referenzieren wir die Umgebungsvariable *IPHashChar* und bestimmen das erste Byte der Variablen. Wir wissen, dass nur ein einziges Byte in der Variante enthalten ist, aber das tut unserem Vorhaben keinen Abbruch. Auf der nächsten Zeile dann der übliche Start der Proxy-Direktive. Anstatt jetzt aber direkt das Backend anzugeben, referenzieren wir die RewriteMap mit dem vorhin vergebenen Namen. Nach dem Doppelpunkt folgt der Parameter für den Aufruf. Interessanterweise sprechen wir die in der Rewrite Bedingung in der Klammer gefangenen Variablen mit *%1* ein. Die Variable der RewriteRule ist davon nicht betroffen und weiterhin über *$1* referenzierbar. Hinter dem *%1* folgt durch das Pipe-Zeichen abgetrennt der Defaultwert. Sollte also beim Aufruf der Map etwas schief gehen, dann wird *localhost* über Port 8000 angesprochen.

Jetzt fehlt uns natürlich noch die RewriteMap. Im Codebeispiel habe wir ein Text-File vorgegeben. Performanter ist natürlich ein dbm-Hash, aber das steht für den Moment nicht im Zentrum. Hier das Map-File `/apache/conf/hashchar2backend.txt`:

```bash
##
## RewriteMap linking hex characters with one of two backends
##
1	localhost:8000
2	localhost:8000
3	localhost:8000
4	localhost:8000
5	localhost:8000
6	localhost:8000
7	localhost:8000
8	localhost:8000
9	localhost:8001
0	localhost:8001
a	localhost:8001
b	localhost:8001
c	localhost:8001
d	localhost:8001
e	localhost:8001
f	localhost:8001
```

Wir unterscheiden zwei Backends und können hier die Verteilung beliebig vornehmen. Gemeinsam bedeutet dieses eher komplexe Rezept nun, dass wir aus der jeweiligen IP-Adresse einen Hash bilden und daraus das erste Zeichen benützen, um in der eben geschriebenen Hash-Tabelle auf eines von zwei Backends zu schliessen. Solange die IP-Adresse des Clients konstant bleibt (was in der Praxis durchaus nicht immer der Fall sein muss), wird das Resultat dieses Lookups immer dasselbe sein. Das heisst, der Client wird immer auf demselben Backend landen. Man nennt dies IP-Stickyness. Da es sich aber um eine Hash-Operation und nicht um einen simplen IP-Adressen-Lookup handelt, werden zwei Clients mit einer ähnlichen IP-Adresse einen gänzlich anderen Hash erhalten und nicht zwingend auf demselben Backend landen. Wir gewinnen damit eine einigermassen flache Verteilung der Requests und sind dennoch sicher, dass bestimmte Clients bis zu einem Wechsel der IP-Adresse immer auf demselben Backend landen werden.

### Schritt 10: Weiterleiten von Informationen an die Backend-Systeme

Der *Reverse Proxy*-Server schirmt den Applikationsserver vom direkten Zugriff durch den Client ab. Dies bedeutet aber auch, dass der Applikationsserver gewisse Informationen zum Client und seiner Verbindung zum *Reverse Proxy* nicht mehr sehen kann. Zur Kompensation dieses Verlustes setzt das Proxy-Modul drei HTTP Request Header-Zeilen, welche den *Reverse Proxy* beschreiben:

* X-Forwarded-For : Die IP-Adresse des Clients, gefolgt von der IP Adresse des Reverse Proxies
* X-Forwarded-Host : Den originalen HTTP Host-Header in der Anfrage des Clients
* X-Forwarded-Server : Den Servernamen des *Reverse Proxies*

Sind mehrere Proxies hintereinander gestaffelt, dann werden die zusätzlichen IP-Adressen und Servernamen durch Komma abgetrennt beigefügt. Neben diesen Daten zur Verbindung ist es aber sinnvoll, auch noch weitere Daten weiterzugeben. In diese Reihe gehört namentlich die Unique-ID, welche den Request eindeutig identifiziert. Ein gut konfigurierter Backend-Server wird diesen Schlüsselwert ähnlich wie unser *Reverse Proxy* im Logfile ablegen. Eine zukünftige Fehlersuche wird dadurch erleichtert, dass die verschiedenen Logeinträge einfach korreliert werden können.

Häufig wird der Reverse Proxy auch dazu eingesetzt, eine Authentifizierung durchzuführen. Wir haben das zwar noch nicht eingerichtet, aber es ist dennoch sinnvoll, diesen Wert in eine weiterzuverwendende Grundkonfiguration mit aufzunehmen. Wenn keine Authentifizierung definiert wird, dann bleibt dieser Wert einfach leer. Und schliesslich wollen wir das Backend-System auch noch über die Art der Verschlüsselung informieren, auf die sich Client und *Reverse Proxy* geeinigt haben. Der gesamte Block sieht dann so aus:

```bash
RequestHeader set "X-RP-UNIQUE-ID" 	"%{UNIQUE_ID}e"
RequestHeader set "X-RP-REMOTE-USER" 	"%{REMOTE_USER}e"
RequestHeader set "X-RP-SSL-PROTOCOL" 	"%{SSL_PROTOCOL}s"
RequestHeader set "X-RP-SSL-CIPHER" 	"%{SSL_CIPHER}s"
```

Sehen wir an, wie sich das auf die Anfrage zwischen *Reverse Proxy* und Backend auswirkt:

```bash
GET /service1/index.html HTTP/1.1
Host: localhost
User-Agent: curl/7.35.0
Accept: */*
X-RP-UNIQUE-ID: VmpSwH8AAQEAAG@hXBcAAAAC
X-RP-REMOTE-USER: (null)
X-RP-SSL-PROTOCOL: TLSv1.2
X-RP-SSL-CIPHER: ECDHE-RSA-AES256-GCM-SHA384
X-Forwarded-For: 127.0.0.1
X-Forwarded-Host: localhost
X-Forwarded-Server: localhost
Connection: close
```

Die verschiedenen erweiterten Header-Zeilen werden also nacheinander aufgeführt und wo vorhanden mit Werten gefüllt.

### Schritt 11 (Bonus): Die Konfiguration des kompletten Reverse Proxy-Servers inklusive der vorangegangenen Lektionen

Mit dieser kleinen Erweiterung kommen wir zum Abschluss dieser Anleitung und auch zum Ende des Basis-Blockes der verschiedenen Anleitungen. Wir haben in mehreren Lektionen den Aufbau eines Apache Webservers von der Kompilierung über die Grundkonfiguration, das Tuning von ModSecurity bis zur Konfiguration eine Reverse Proxies gesehen und so einen vertieften Einblick in die Funktionsweise des Servers und seiner wichtigsten Module erhalten.

Hier nun die komplette Konfiguration des *Reverse Proxy*-Servers, wie wir sie in den letzten Lektionen erarbeitet haben.

```bash
ServerName        localhost
ServerAdmin       root@localhost
ServerRoot        /apache
User              www-data
Group             www-data
PidFile           logs/httpd.pid

ServerTokens      Prod
UseCanonicalName  On
TraceEnable       Off

Timeout           10
MaxClients        100

Listen            127.0.0.1:80
Listen            127.0.0.1:443

LoadModule        mpm_event_module        modules/mod_mpm_event.so
LoadModule        unixd_module            modules/mod_unixd.so

LoadModule        log_config_module       modules/mod_log_config.so
LoadModule        logio_module            modules/mod_logio.so
LoadModule        rewrite_module          modules/mod_rewrite.so
LoadModule        headers_module          modules/mod_headers.so

LoadModule        authn_core_module       modules/mod_authn_core.so
LoadModule        authz_core_module       modules/mod_authz_core.so

LoadModule        ssl_module              modules/mod_ssl.so

LoadModule        unique_id_module        modules/mod_unique_id.so
LoadModule        security2_module        modules/mod_security2.so

LoadModule        proxy_module            modules/mod_proxy.so
LoadModule        proxy_http_module       modules/mod_proxy_http.so
LoadModule        proxy_balancer_module   modules/mod_proxy_balancer.so
LoadModule        lbmethod_byrequests_module modules/mod_lbmethod_byrequests.so
LoadModule	  slotmem_shm_module      modules/mod_slotmem_shm.so


ErrorLogFormat          "[%{cu}t] [%-m:%-l] %-a %-L %M"
LogFormat "%h %{GEOIP_COUNTRY_CODE}e %u [%{%Y-%m-%d %H:%M:%S}t.%{usec_frac}t] \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %v %A %p %R %{BALANCER_WORKER_ROUTE}e %X \"%{cookie}n\" %{UNIQUE_ID}e %{SSL_PROTOCOL}x %{SSL_CIPHER}x %I %O %{ratio}n%% %D %{ModSecTimeIn}e %{ApplicationTime}e %{ModSecTimeOut}e %{ModSecAnomalyScoreIn}e %{ModSecAnomalyScoreOut}e" extended

LogFormat "[%{%Y-%m-%d %H:%M:%S}t.%{usec_frac}t] %{UNIQUE_ID}e %D \
PerfModSecInbound: %{TX.perf_modsecinbound}M \
PerfAppl: %{TX.perf_application}M \
PerfModSecOutbound: %{TX.perf_modsecoutbound}M \
TS-Phase1: %{TX.ModSecTimestamp1start}M-%{TX.ModSecTimestamp1end}M \
TS-Phase2: %{TX.ModSecTimestamp2start}M-%{TX.ModSecTimestamp2end}M \
TS-Phase3: %{TX.ModSecTimestamp3start}M-%{TX.ModSecTimestamp3end}M \
TS-Phase4: %{TX.ModSecTimestamp4start}M-%{TX.ModSecTimestamp4end}M \
TS-Phase5: %{TX.ModSecTimestamp5start}M-%{TX.ModSecTimestamp5end}M \
Perf-Phase1: %{PERF_PHASE1}M \
Perf-Phase2: %{PERF_PHASE2}M \
Perf-Phase3: %{PERF_PHASE3}M \
Perf-Phase4: %{PERF_PHASE4}M \
Perf-Phase5: %{PERF_PHASE5}M \
Perf-ReadingStorage: %{PERF_SREAD}M \
Perf-WritingStorage: %{PERF_SWRITE}M \
Perf-GarbageCollection: %{PERF_GC}M \
Perf-ModSecLogging: %{PERF_LOGGING}M \
Perf-ModSecCombined: %{PERF_COMBINED}M" perflog

LogLevel                      debug
ErrorLog                      logs/error.log
CustomLog                     logs/access.log extended
CustomLog                     logs/modsec-perf.log perflog env=write_perflog


# == ModSec Base Configuration

SecRuleEngine                 On

SecRequestBodyAccess          On
SecRequestBodyLimit           10000000
SecRequestBodyNoFilesLimit    64000

SecResponseBodyAccess         On
SecResponseBodyLimit          10000000

SecPcreMatchLimit             15000
SecPcreMatchLimitRecursion    15000

SecTmpDir                     /tmp/
SecDataDir                    /tmp/
SecUploadDir                  /tmp/

SecDebugLog                   /apache/logs/modsec_debug.log
SecDebugLogLevel              0

SecAuditEngine                RelevantOnly
SecAuditLogRelevantStatus     "^(?:5|4(?!04))"
SecAuditLogParts              ABIJEFHKZ

SecAuditLogType               Concurrent
SecAuditLog                   /apache/logs/modsec_audit.log
SecAuditLogStorageDir         /apache/logs/audit/

SecDefaultAction              "phase:1,pass,log,tag:'Local Lab Service'"


# == ModSec Rule ID Namespace Definition
# Service-specific before Core-Rules:    10000 -  49999
# Service-specific after Core-Rules:     50000 -  79999
# Locally shared rules:                  80000 -  99999
#  - Performance:                        90000 -  90199
# Recommended ModSec Rules (few):       200000 - 200010
# OWASP Core-Rules:                     900000 - 999999


# === ModSec timestamps at the start of each phase (ids: 90000 - 90009)

SecAction "id:'90000',phase:1,nolog,pass,setvar:TX.ModSecTimestamp1start=%{DURATION}"
SecAction "id:'90001',phase:2,nolog,pass,setvar:TX.ModSecTimestamp2start=%{DURATION}"
SecAction "id:'90002',phase:3,nolog,pass,setvar:TX.ModSecTimestamp3start=%{DURATION}"
SecAction "id:'90003',phase:4,nolog,pass,setvar:TX.ModSecTimestamp4start=%{DURATION}"
SecAction "id:'90004',phase:5,nolog,pass,setvar:TX.ModSecTimestamp5start=%{DURATION}"
                      
# SecRule REQUEST_FILENAME "@beginsWith /" "id:'90005',phase:5,t:none,nolog,noauditlog,pass,setenv:write_perflog"


# === ModSec Recommended Rules (in modsec src package) (ids: 200000-200010)

SecRule REQUEST_HEADERS:Content-Type "text/xml" "id:'200000',phase:1,t:none,t:lowercase,pass,nolog,ctl:requestBodyProcessor=XML"

SecRule REQBODY_ERROR "!@eq 0" "id:'200001',phase:2,t:none,deny,status:400,log,msg:'Failed to parse request body.',\
logdata:'%{reqbody_error_msg}',severity:2"

SecRule MULTIPART_STRICT_ERROR "!@eq 0" \
"id:'200002',phase:2,t:none,log,deny,status:403, \
msg:'Multipart request body failed strict validation: \
PE %{REQBODY_PROCESSOR_ERROR}, \
BQ %{MULTIPART_BOUNDARY_QUOTED}, \
BW %{MULTIPART_BOUNDARY_WHITESPACE}, \
DB %{MULTIPART_DATA_BEFORE}, \
DA %{MULTIPART_DATA_AFTER}, \
HF %{MULTIPART_HEADER_FOLDING}, \
LF %{MULTIPART_LF_LINE}, \
SM %{MULTIPART_MISSING_SEMICOLON}, \
IQ %{MULTIPART_INVALID_QUOTING}, \
IP %{MULTIPART_INVALID_PART}, \
IH %{MULTIPART_INVALID_HEADER_FOLDING}, \
FL %{MULTIPART_FILE_LIMIT_EXCEEDED}'"

SecRule TX:/^MSC_/ "!@streq 0" "id:'200004',phase:2,t:none,deny,status:500,msg:'ModSecurity internal error flagged: %{MATCHED_VAR_NAME}'"


# === ModSecurity Rules (ids: 900000-999999)
                
# === ModSec Core Rules Base Configuration (ids: 900001-900021)

SecAction "id:'900001',phase:1,t:none, \
   setvar:tx.critical_anomaly_score=5, \
   setvar:tx.error_anomaly_score=4, \
   setvar:tx.warning_anomaly_score=3, \
   setvar:tx.notice_anomaly_score=2, \
   nolog, pass"
SecAction "id:'900002',phase:1,t:none,setvar:tx.inbound_anomaly_score_level=10000,setvar:tx.inbound_anomaly_score=0,nolog,pass"
SecAction "id:'900003',phase:1,t:none,setvar:tx.outbound_anomaly_score_level=10000,setvar:tx.outbound_anomaly_score=0,nolog,pass"
SecAction "id:'900004',phase:1,t:none,setvar:tx.anomaly_score_blocking=on,nolog,pass"

SecAction "id:'900006',phase:1,t:none,setvar:tx.max_num_args=255,nolog,pass"
SecAction "id:'900007',phase:1,t:none,setvar:tx.arg_name_length=100,nolog,pass"
SecAction "id:'900008',phase:1,t:none,setvar:tx.arg_length=400,nolog,pass"
SecAction "id:'900009',phase:1,t:none,setvar:tx.total_arg_length=64000,nolog,pass"
SecAction "id:'900010',phase:1,t:none,setvar:tx.max_file_size=10000000,nolog,pass"
SecAction "id:'900011',phase:1,t:none,setvar:tx.combined_file_sizes=10000000,nolog,pass"
SecAction "id:'900012',phase:1,t:none, \
  setvar:'tx.allowed_methods=GET HEAD POST OPTIONS', \
  setvar:'tx.allowed_request_content_type=application/x-www-form-urlencoded|multipart/form-data|text/xml|application/xml|application/x-amf|application/json', \
  setvar:'tx.allowed_http_versions=HTTP/0.9 HTTP/1.0 HTTP/1.1', \
  setvar:'tx.restricted_extensions=.asa/ .asax/ .ascx/ .axd/ .backup/ .bak/ .bat/ .cdx/ .cer/ .cfg/ .cmd/ .com/ .config/ .conf/ .cs/ .csproj/ .csr/ .dat/ .db/ .dbf/ .dll/ .dos/ .htr/ .htw/ .ida/ .idc/ .idq/ .inc/ .ini/ .key/ .licx/ .lnk/ .log/ .mdb/ .old/ .pass/ .pdb/ .pol/ .printer/ .pwd/ .resources/ .resx/ .sql/ .sys/ .vb/ .vbs/ .vbproj/ .vsdisco/ .webinfo/ .xsd/ .xsx/', \
  setvar:'tx.restricted_headers=/Proxy-Connection/ /Lock-Token/ /Content-Range/ /Translate/ /via/ /if/', \
  nolog,pass"

SecRule REQUEST_HEADERS:User-Agent "^(.*)$" "id:'900018',phase:1,t:none,t:sha1,t:hexEncode,setvar:tx.ua_hash=%{matched_var}, \
  nolog,pass"
SecRule REQUEST_HEADERS:x-forwarded-for "^\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b" \
  "id:'900019',phase:1,t:none,capture,setvar:tx.real_ip=%{tx.1},nolog,pass"
SecRule &TX:REAL_IP "!@eq 0" "id:'900020',phase:1,t:none,initcol:global=global,initcol:ip=%{tx.real_ip}_%{tx.ua_hash}, \
  nolog,pass"
SecRule &TX:REAL_IP "@eq 0" "id:'900021',phase:1,t:none,initcol:global=global,initcol:ip=%{remote_addr}_%{tx.ua_hash},setvar:tx.real_ip=%{remote_addr}, \
  nolog,pass"


# === ModSecurity Ignore Rules Before Core Rules Inclusion; order by id of ignored rule (ids: 10000-49999)

# ...


# === ModSecurity Core Rules Inclusion

Include    /modsecurity-core-rules/*.conf


# === ModSecurity Ignore Rules After Core Rules Inclusion; order by id of ignored rule (ids: 50000-59999)

# ...


# === ModSec Timestamps at the End of Each Phase (ids: 90010 - 90019)

SecAction "id:'90010',phase:1,pass,nolog,setvar:TX.ModSecTimestamp1end=%{DURATION}"
SecAction "id:'90011',phase:2,pass,nolog,setvar:TX.ModSecTimestamp2end=%{DURATION}"
SecAction "id:'90012',phase:3,pass,nolog,setvar:TX.ModSecTimestamp3end=%{DURATION}"
SecAction "id:'90013',phase:4,pass,nolog,setvar:TX.ModSecTimestamp4end=%{DURATION}"
SecAction "id:'90014',phase:5,pass,nolog,setvar:TX.ModSecTimestamp5end=%{DURATION}"


# === ModSec performance calculations and variable export (ids: 90100 - 90199)

SecAction "id:'90100',phase:5,pass,nolog,setvar:TX.perf_modsecinbound=%{PERF_PHASE1}"
SecAction "id:'90101',phase:5,pass,nolog,setvar:TX.perf_modsecinbound=+%{PERF_PHASE2}"
SecAction "id:'90102',phase:5,pass,nolog,setvar:TX.perf_application=%{TX.ModSecTimestamp3start}"
SecAction "id:'90103',phase:5,pass,nolog,setvar:TX.perf_application=-%{TX.ModSecTimestamp2end}"
SecAction "id:'90104',phase:5,pass,nolog,setvar:TX.perf_modsecoutbound=%{PERF_PHASE3}"
SecAction "id:'90105',phase:5,pass,nolog,setvar:TX.perf_modsecoutbound=+%{PERF_PHASE4}"
SecAction "id:'90106',phase:5,pass,nolog,setenv:ModSecTimeIn=%{TX.perf_modsecinbound}"
SecAction "id:'90107',phase:5,pass,nolog,setenv:ApplicationTime=%{TX.perf_application}"
SecAction "id:'90108',phase:5,pass,nolog,setenv:ModSecTimeOut=%{TX.perf_modsecoutbound}"
SecAction "id:'90109',phase:5,pass,nolog,setenv:ModSecAnomalyScoreIn=%{TX.inbound_anomaly_score}"
SecAction "id:'90110',phase:5,pass,nolog,setenv:ModSecAnomalyScoreOut=%{TX.outbound_anomaly_score}"


# === ModSec finished

RewriteEngine           On
RewriteOptions          InheritDownBefore

RewriteRule             ^/$  %{REQUEST_SCHEME}://%{HTTP_HOST}/index.html  [redirect,last]



SSLCertificateKeyFile   /etc/ssl/private/ssl-cert-snakeoil.key
SSLCertificateFile      /etc/ssl/certs/ssl-cert-snakeoil.pem

SSLProtocol             All -SSLv2 -SSLv3
SSLCipherSuite          'kEECDH+ECDSA kEECDH kEDH HIGH +SHA !aNULL !eNULL !LOW !MEDIUM !MD5 !EXP !DSS !PSK !SRP !kECDH !CAMELLIA !RC4'
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

    RewriteEngine     On

    RewriteRule       ^/(.*)$  https://%{HTTP_HOST}/$1  [redirect,last]
    
    <Directory /apache/htdocs>

        Require all granted

        Options None
        AllowOverride None

    </Directory>

</VirtualHost>

<VirtualHost 127.0.0.1:443>
    
    SSLEngine On

    ProxyTimeout              60
    ProxyErrorOverride        On

    RewriteEngine             On

    RewriteRule               ^/service1/(.*)	  http://localhost:8000/service1/$1 [proxy,last]
    ProxyPassReverse          /                 http://localhost:8000/


    <Proxy http://localhost:8000/service1>

        Require all granted

        AllowOverride none
        Options none

    </Proxy>

    <Directory /apache/htdocs>

        Require all granted

        Options None
        AllowOverride None

    </Directory>

</VirtualHost>
```

### Verweise

* Apache mod_proxy [https://httpd.apache.org/docs/2.4/mod/mod_proxy.html)](https://httpd.apache.org/docs/2.4/mod/mod_proxy.html)
* Apache mod_rewrite [https://httpd.apache.org/docs/2.4/mod/mod_rewrite.html)](https://httpd.apache.org/docs/2.4/mod/mod_rewrite.html)

### Lizenz / Kopieren / Weiterverwenden

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png" /></a><br />Diese Arbeit ist wie folgt lizenziert / This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.

