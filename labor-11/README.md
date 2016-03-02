##Title: Den vollen Verkehr sniffen und mitschreiben

###Was machen wir?

Wir schreiben den vollen HTTP Verkehr mit. Dazu entschlüsseln wir wo nötig den Verkehr.

###Warum tun wir das?

Im Alltag kommt es immer wieder vor, dass beim Betrieb eines Webservers oder eines Reverse Proxies Fehler auftreten, die nur mit Mähe bearbeitet werden können. In zahlreichen Fällen herrscht Uneinigkeit Kommunikationsteilnehmer den Fehler genau verursacht hat, oder es fehlt die Klarheit, was genau durch die Leitung ging. In diesen Fällen ist es wichtig, den gesamten Verkehr mitschreiben zu können, um auf dieser Basis den Fehler zu isolieren.

###Voraussetzungen

* Ein Apache Webserver, idealerweise mit einem File-Layout wie bei [Anleitung 1 (Kompilieren eines Apache Servers)](https://www.netnea.com/cms/apache_tutorial_1_apache_compilieren/)
* Verständnis der minimalen Konfiguration in [Anleitung 2 (Apache minimal konfigurieren)](https://www.netnea.com/cms/apache_tutorial_2_apache_minimal_konfigurieren/)
* Ein Apache Webserver mit SSL-/TLS-Unterstützung wie in [Anleitung 4 (Konfigurieren eines SSL Servers)](https://www.netnea.com/cms/apache-tutorial-4-ssl-server-konfigurieren)
* Ein Apache Webserver mit erweitertem Zugriffslog wie in [Anleitung 5 (Das Zugriffslog Ausbauen und Auswerten)](https://www.netnea.com/cms/apache-tutorial-5-zugriffslog-ausbauen/)
* Ein Apache Webserver mit ModSecurity wie in [Anleitung 6 (ModSecurity einbinden)](https://www.netnea.com/cms/apache-tutorial-6-modsecurity-einbinden/)
* FIXME: Anleitung 7
* Ein Reverse Proxy wie in [Anleitung 9 (Reverse Proxy einrichten)](https://www.netnea.com/cms/apache-tutorial-9-reverse-proxy-einrichten/)

###Schritt FIXME : ModSecurity Full Traffic Log schreiben

Wir haben in der Anleitung 6 gesehen, wie wir ModSecurity konfigurieren können, damit es den gesamten Verkehr einer einzigen Client IP Adresse mitschreibt. Je nach Settings der Direktive `SecAuditLogParts` werden aber nicht sämtliche Teile der Anfragen festgehalten. Schauen wir uns die verschiedenen Optionen dieser Direktive an. Die Audit-Engine von ModSecurity bezeichnet verschiedene Teile des Audit-Logs mit verschiedenen Buchstabenkürzeln. Sie lauten wie folgt:

* Teil A: Der Startteil eines einzelnen Eintrages / Requests (zwingend)
* Teil B: Die HTTP Request Header
* Teil C: Der HTTP Request Body (inklusive rohe Dateien bei einem File Upload; nur wenn der Body-Zugriff mittels `SecRequestBodyAccess` gesetzt wurde)
* Teil E: Der HTTP Response Body (nur wenn der Body-Zugriff mittels `SecResponseBodyAccess` aktiviert wurde)
* Teil F: Die HTTP Response Header (Ohne die beiden Date- und Server-Header, die von Apache selbst kurz vor dem Verlassen des Servers gesetzt werden)
* Teil H: Zusatzinfos zum Request FIXME
* Teil I: Der HTTP Request Body in einer platzsparenden Version (hochgeladene Files in nicht ihrer vollen Länge einschliesst, sondern nur einzelne Schlüsselparameter dieser Dateien)
* Teil J: Zusätzliche Informationen über File Uploads
* Teil K: Liste sämtlicher Regeln, die eine positive Antwort lieferten (Die Regeln selbst werden normalisiert inklusive sämtlicher vererbten Deklarationen)
* Teil Z: Abschluss eines einzelnen Eintrages / Requests (zwingend)

In der Anleitung 6 haben wir die folgende Auswahl für die einzelnen Header getroffen.:

```bash
SecAuditLogParts        ABIJEFHKZ
```

Damit haben wir ein sehr umfassendes Protokoll festgelegt. Das ist in einem Labor-Setup das richtige Vorgehen. In einer produktiven Umgebung macht dies allerdings nur in Ausnahmefällen Sinn. Eine typische Ausprägung dieser Direktive in einer produktiven Umgebung lautet deshalb:

```bash
SecAuditLogParts            "ABFHKZ"
```

Hier werden die Request- und Response-Bodies nicht mehr mitgeschrieben. Das spart sehr viel Speicherplatz, was gerade bei schlecht getunten Systemen wichtig ist. Diejenigen Teile der Bodies, welche einzelne Regeln verletzten, werden im Error-Log und im K-Teil dennoch notiert werden. Das reicht in vielen Fällen. Fallweise möchte man aber dennoch den gesamten Body mitschreiben. In diesen Fällen bietet sich eine `ctl`-Direktive an:

```bash
SecRule REMOTE_ADDR  "@streq 127.0.0.1"   "id:10000,phase:1,pass,log,auditlog,msg:'Initializing full traffic log',ctl:auditLogParts=+IJE"
```

FIXME Check this


###Schritt FIXME : ModSecurity Full Traffic Log einer einzigen Session schreiben

Der erste Schritt erlaubte die dynamische Veränderung der Audit-Log-Teile für eine bekannte IP-Adresse. Was aber, wenn wir
das Logging dynamisch für ausgewählte Sessions dauerhaft einschalten und wie im obigen Beispiel gezeigt, auf den vollen Request ausdehnen möchten?

Ivan Ristić beschreibt in seinem ModSecurity Handbuch ein Beispiel in dem eine ModSecurity Collection herangezogen wird, um eine eigene Session zu erzeugen, welche über einen einzelnen Request hinaus aktiv bleibt. Wir benützen diese Idee als Basis und schreiben ein etwas komplexeres Beispiel.

FIXME Pseudo:
- Phase:5 Wenn Inbound Anomaly Score > Limit: Session initialisieren und LogParts erweitern
- Phase:5 Wenn Outbound Anomaly Score > Limit: Session initialisieren und LogParts erweitern
- Phase:1 Falls Session LogParts erweitern

###Schritt FIXME : Verkehr des Clients mit dem Server / Reverse Proxy mithören

Der Verkehr zwischen einem Client und dem Reverse Proxy lässt sich mit den oben geschilderten Techniken in aller Regel gut dokumentieren. Dazu kommen die Möglichkeiten auf dem Client den Verkehr zu dokumentieren. Die modernen Browser bringen dazu verschiedene Möglichkeiten und sie scheinen mir alle adäquat zu sein. Allerdings kommt es in der Praxis vor, dass Komplikationen das Mitschreiben des Verkehrs erschweren oder verunmöglichen. Sei es, dass ein Fat Client ausserhalb eines Browsers verwendet wird, der Client lediglich auf einem mobilen Gerät zum Einsatz kommt, ein zwischengeschalteter Proxy den Verkehr in die eine oder andere Richtung verändert, dass der Verkehr nach dem Verlassen von ModSecurity durch ein weiteres Modul nochmals verändert wird oder aber dass ModSecurity gar keinen Zugriff auf den Verkehr erhält. Letzteres ist ein einzelnen Fällen tatsächlich ein Problem, da ein Apache Modul die weitere Verarbeitung eines Requests abbrechen un damit den Zugriff durch ModSecurity unterdrücken kann.

Aus all diesen Gründen kann es vorkommen, dass die Einträge im Audit-Log nicht demjenigen entspricht, was tatsächlich auf dem Client ankam, oder nicht mehr dem entspricht, was der Client ursprünglich geschickt hatte. In diesen Fällen ist es wünschenswert, punktuell den tatsächlichen Traffic mitzuschreiben und die verschlüsselten Daten zu dechiffrieren. Diesem Ansinnen steht allerdings die starke Verschlüsselung gegenüber, welche wir in der vierten Anleitung konfiguriert haben, um sie abhörsicher zu machen. Die von uns favorisierten Ciphers setzen hiezu auf sogenannte `Forward Secrecy`. Das bedeutet, dass ein Mithörer so ausgeschaltet wird, dass selbst der Besitz des Chiffrierschlüssels ein Mithören nicht mehr erlaubt. Das heisst zwischen dem Client und dem Server ist jedes Mitschreiben des Verkehrs ausgeschlossen. Es sei denn wir postieren einen Prozess dazwischen, welcher die Verbindung terminiert und dem Client ein eigenes Zertifikat vorlegt.

In allen anderen Fällen, in denen wir eine Entschlüsselung erzwingen wollen, aber den Client nicht umkonfigurieren können, müssen wir eine andere, schwächere Verschlüsselsungsart einsetzen, die `Forward Secrecy` nicht beherrscht. Dazu eignet sich etwa der FIXME Cipher. Wenn wir den Cipher clientseitig nicht setzen können, dann müssen wir die Verschlüsselung für den kompletten Server schwächen. Es liegt auf der Hand, dass die nicht erwünscht ist, und höchstens punktuell Sinn macht. Sei es dass wir den Client auf ein separates System binden oder die Umkonfiguration zeitlich beschränken.

Versuchsweise liess sich Apache mittels der konditionalen `<if>`-Direktive auch so konfigurieren, dass er einem einzelnen Client einen anderen Cipher präsentiert. Allerdings gelingt dies nur via ein `SSL-Renegotiate`, was die gängigen Entschlüsselungshilfsmittel wiederum nicht zu verarbeiten vermögen. Das heisst, für den Moment bleibt nur,, den kompletten Server auf eine schwächere Verschlüsselung umzustellen. Im Hinblick auf die Sicherheits rate ich dringend dazu, zunächst alle anderen Mittel auszuschöpfen bevor auf diese Variante zurückgegriffen wird.

FIXME Example





###Schritt FIXME : Verschlüsselten Verkehr des Clients mit dem Server / Reverse Proxy mitschreiben


FIXME Sniffing in pcap File



###Schritt FIXME : Verkehr entschlüsseln

FIXME decrypt of pcap File

###Schritt FIXME : Verkehr des Reverse Proxies mit dem Applikationsserver mithören

- stunnel
- tcpdump









###Verweise

* FIXME ModSec Handbuch
* mod_firehose
* wireshark step by step

### Lizenz / Kopieren / Weiterverwenden

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png" /></a><br />Diese Arbeit ist wie folgt lizenziert / This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.

