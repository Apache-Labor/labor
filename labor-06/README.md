##Title: OWASP ModSecurity Core Rules einbinden

###Was machen wir?

Wir binden die OWASP ModSecurity Core Rules in unseren Apache Webserver ein und merzen Fehlalarme aus.

###Warum tun wir das?

Die Web Application Firewall ModSecurity, wie wir sie in Anleitung Nummer 6 eingerichtet haben, besitzt noch beinahe keine Regeln. Der Schutz spielt aber erst, wenn man ein möglichst umfassendes Regelset hinzukonfiguriert. Die Core Rules bieten generisches Blacklisting. Das heisst, sie untersuchen die Anfragen und die Antworten nach Hinweisen auf Angriffe. Die Hinweise sind oft Schlüsselwörter und typische Muster, die auf verschiedenste Arten von Angriffen hindeuten können. Das bringt es mit sich, dass auch Fehlalarme ausgelöst werden (*False Positives*). Für eine erfolgreiche Installation müssen wir diese wegkonfigurieren.

###Voraussetzungen

* Ein Apache Webserver, idealerweise mit einem File-Layout wie bei [Anleitung 1 (Kompilieren eines Apache Servers)](https://www.netnea.com/cms/apache_tutorial_1_apache_compilieren/) erstellt.
* Verständnis der minimalen Konfiguration in [Anleitung 2 (Apache minimal konfigurieren)](https://www.netnea.com/cms/apache_tutorial_2_apache_minimal_konfigurieren/).
* Ein Apache Webserver mit SSL-/TLS-Unterstützung wie in [Anleitung 4 (Konfigurieren eines SSL Servers)](https://www.netnea.com/cms/apache-tutorial-4-ssl-server-konfigurieren/)
* Ein Apache Webserver mit erweitertem Zugriffslog wie in [Anleitung 5 (Das Zugriffslog Ausbauen und Auswerten)](https://www.netnea.com/cms/apache-tutorial-5-zugriffslog-ausbauen/)
* Ein Apache Webserver mit ModSecurity wie in [Anleitung 6 (ModSecurity einbinden)](https://www.netnea.com/cms/apache-tutorial-6-modsecurity-einbinden/)

Wir werden mit dem neuen Major Release 3.0 des Core Rule Sets arbeiten; kurz CRS3. Das offizielle CRS3 Paket wird mit einer _INSTALL_ Datei ausgeliefert, welche das Einrichten der Regeln sehr gut erklärt (zufälligerweise habe ich neben dieser Anleitung hier auch einen grossen Teil des INSTALL Files geschrieben). Wir werden den Installationsprozess aber etwas umstellen, damit er besser auf unsere Bedürfnisse passt.

###Schritt 1: OWASP ModSecurity Core Rules herunterladen

Die ModSecurity Core Rules werden unter dem Dach von *OWASP*, dem Open Web Application Security Project entwickelt. Die Rules selbst liegen auf *GitHub* und können wie folgt heruntergeladen werden. 

```
$> cd /apache/conf
$> wget https://github.com/SpiderLabs/owasp-modsecurity-crs/archive/v3.0.0.tar.gz
$> tar -xvzf v3.0.0.tar.gz
owasp-modsecurity-crs-3.0.0/
owasp-modsecurity-crs-3.0.0/CHANGES
owasp-modsecurity-crs-3.0.0/IDNUMBERING
owasp-modsecurity-crs-3.0.0/INSTALL
owasp-modsecurity-crs-3.0.0/KNOWN_BUGS
owasp-modsecurity-crs-3.0.0/LICENSE
owasp-modsecurity-crs-3.0.0/README.md
owasp-modsecurity-crs-3.0.0/crs-setup.conf.example
owasp-modsecurity-crs-3.0.0/documentation/
owasp-modsecurity-crs-3.0.0/documentation/OWASP-CRS-Documentation/
owasp-modsecurity-crs-3.0.0/documentation/README
...
$> sudo ln -s owasp-modsecurity-crs-3.0.0 /apache/conf/crs
$> cp crs/crs-setup.conf.example crs/crs-setup.conf
$> rm v3.0.0.tar.gz
```

Dies entpackt den Basis Teil des Core Rule Set im Verzeichnis `/apache/conf/owasp-modsecurity-crs-3.0.0`. Wir kreieren einen Link von `/apache/conf/crs` in dieses Verzeichnis. Dann kopieren wir eine Datei namens `crs-setup.conf.example` und zum Abschluss löschen wir das CRS tar File.

Dieses Setup File erlaubt es uns, mit mehreren verschiedenen Einstellungen herumzuspielen. Es lohnt sich einen Blick darauf zu werfen; und sei es nur um zu sehen, was es alles gibt. Für den Moment sind wir aber mit den Basis-Einstellungen zufrieden und werden die Datei nicht anfassen; wir werden einfach sicher stellen, dass es unter dem neuen Dateinamen `crs-setup.conf` zur Verfügung steht. Dann können wir das Apache Konfigurationsfile anpassen und die Regeln einbinden.

###Schritt 2: Core Rules einbinden

In der Anleitung 6, in welcher wir ModSecurity selbst eingebunden haben, markierten wir bereits einen Bereich für die Core-Rules. In diesen Bereich fügen wir die Include-Direktive jetzt ein. Konkret kommen vier Teile zur bestehenden Konfiguration hinzu. (1) Die Core Rules Basis-Konfiguration, (2) ein Teil für selbst zu definierende Regelausschlüsse vor dem Core Rule Set (sogenannte Rule Exclusions). Dann (3) die Core Rules selbst und schliesslich ein Teil (4) für selbst zu definierende Regelausschlüsse nach dem Core Rule Set.

Die sogenannten Rule Exclusions bezeichnen Regeln und Direktiven, die dazu dienen, mit den oben beschriebenen Fehlalarmen umzugehen. Manche Fehlalarme müssen verhindert werden, bevor die entsprechende Core Rule geladen wird. Manche Fehlalarme können erst nach der Definition der Core Rule selbst abgefangen werden. Aber der Reihe nach. Hier zunächst der neue Konfigurationsblock den wir in die Basiskonfiguration, die wir beim Einrichten von ModSecurity erstellt haben, einführen:

```bash
# === ModSec Core Rules Base Configuration (ids: 900000-900999)

Include    /apache/conf/crs/crs-setup.conf

SecAction "id:900110,phase:1,pass,nolog,\
  setvar:tx.inbound_anomaly_score_threshold=1000,\
  setvar:tx.outbound_anomaly_score_threshold=1000"

SecAction "id:900000,phase:1,pass,nolog,\
  setvar:tx.paranoia_level=1"


# === ModSec Core Rules: Runtime Exclusion Rules (ids: 10000-49999)

# ...


# === ModSecurity Core Rules Inclusion

Include    /apache/conf/crs/rules/*.conf


# === ModSec Core Rules: Startup Time Rules Exclusions

# ...
```

Das CRS arbeitet mit einem Basis-Konfigurationsfile namens `crs-setup.conf`, das wir während der Installation vorbereitet haben. Das Kopieren des Files garantiert, dass wir das CRS updaten können, ohne dass wir unsere Basis-Konfiguration überschreiben - es sei denn, wir wollen das wirklich.

Wir können die verschiedenen Einstellungen im Basis-Konfigurationsfile anpassen. Die Strategie in dieser Anleitung ist es allerdings, die wichtigen Dinge direkt in unserer Apache Konfiguration zu definieren. Wir möchten nicht den kompletten Inhalt von `crs-setup.conf` in unsere Konfiguration einfügen, nur um die minimalen Einstellungen zum Start des CRS zu erhalten. Stattdessen laden wir die Datei über ein *Include* Statement und setzen diejenigen Werte, die wir zu ändern gedenken, in der Apache Konfiguration selbst. Ich möchte hier auch nicht die ganzen Einstellungen im `crs-setup.conf` referieren, aber ein Blick lohnt sich wirklich.

Für den Moment lassen wir das unberührt und nehmen aber wie erwähnt drei entscheidende Werte aus `crs-setup.conf` heraus und definieren sie in unserer Konfiguration, damit wir sie dauerhaft in Blick behalten können. Zunächst setzen wir zwei Limiten in der Regel _900110_: Den Anomalie-Wert der Anfragen und den Anomalie-Wert der Antworten. Dies geschieht mittels der `setvar` Action, welche hier beide Werte auf 1'000 setzt.

Was bedeutet das? Das CRS arbeitet per Default mit einem Zähl-Mechanismus. Für jede Regel, die eine Anfrage verletzt, wird ein Zähler erhöht. Wenn der Request sämtliche Regeln passiert hat, dann wird der Wert mit der Limite verglichen. Sollte er die Limite erreichen, wird der Request blockiert. Dasselbe geschieht mit der Antwort wo wir Informationslecks gegenüber dem Client verhindern möchten.

Von Haus aus kommt das CRS im Blocking Mode daher. Wenn eine Regel verletzt wird und der Zähler die Limite erreicht, wird die Blockade der Anfrage sofort ausgelöst. Aber wir sind noch nicht sicher, ob unser Service wirklich sauber läuft und die Gefahr von Fehlalarmen ist immer da. Wir möchten unerwünschte Blockaden verhindern, deshalb setzen wir die Limite zunächst bei 1'000 an. Regelverletzungen bringen maximal 5 Punkte. Und selbst wenn die Kumulation möglich ist, wird eine Anfrage die Limite kaum erreichen. Aber wir bleiben dennoch prinzipiell im Blocking Mode und wenn unser Vertrauen in unsere Konfiguration wächst, dann können wir die Limiten einfach schrittweise reduzieren.

Die zweite Regel, die Regel `900000`, setzt den _Paranoia Level_ auf 1. Das CRS ist in vier Gruppen von Regeln unterteilt; Regeln der Paranoia Stufen 1 - 4. Wie der Name bereits erahnen lässt, je höher der Paranoia Level, desto neurotischer die Regeln. Per Default stellen wir den Level auf 1, wo die Regeln noch vernünftig und Fehlalarme selten sind. Wenn wir den PL auf 2 erhöhen, werden neue Regeln hinzugeladen. Nun treten etwas mehr Fehlalarme, sogenannte *False Positives* auf. Deren Zahl steigt mit PL3 weiter an und auf der letzten Stufe PL4 wird es nun Fehlalarme hageln, als ob die Web Application Firewall jeden Sinn für ein vernünftiges Mass verloren hätte. Für den Moment müssen wir aber nur wissen, dass wir die Agressivität des Regelwerks über die Paranoia Level Einstellung kontrollieren können und dass PL3 und PL4 wirklich für diejenigen Benutzer existieren, welche sehr hohe Sicherheitsanforderungen besitzen. Wir starten bei PL1.

###Schritt 3: Ein genauerer Blick auf den Regel-Ordner

Im Zentrum des vorangehenden Konfigurationsblocks liegt ein Include Statement, das sämtliche Dateien mit der Endung `.conf` aus dem Unterverzeichnis `rules` im CRS Verzeichnis lädt. Schauen wir uns diese Files einmal an:

```bash
$> ls -1
crs/rules/REQUEST-901-INITIALIZATION.conf
crs/rules/REQUEST-903.9001-DRUPAL-EXCLUSION-RULES.conf
crs/rules/REQUEST-903.9002-WORDPRESS-EXCLUSION-RULES.conf
crs/rules/REQUEST-905-COMMON-EXCEPTIONS.conf
crs/rules/REQUEST-910-IP-REPUTATION.conf
crs/rules/REQUEST-911-METHOD-ENFORCEMENT.conf
crs/rules/REQUEST-912-DOS-PROTECTION.conf
crs/rules/REQUEST-913-SCANNER-DETECTION.conf
crs/rules/REQUEST-920-PROTOCOL-ENFORCEMENT.conf
crs/rules/REQUEST-921-PROTOCOL-ATTACK.conf
crs/rules/REQUEST-930-APPLICATION-ATTACK-LFI.conf
crs/rules/REQUEST-931-APPLICATION-ATTACK-RFI.conf
crs/rules/REQUEST-932-APPLICATION-ATTACK-RCE.conf
crs/rules/REQUEST-933-APPLICATION-ATTACK-PHP.conf
crs/rules/REQUEST-941-APPLICATION-ATTACK-XSS.conf
crs/rules/REQUEST-942-APPLICATION-ATTACK-SQLI.conf
crs/rules/REQUEST-943-APPLICATION-ATTACK-SESSION-FIXATION.conf
crs/rules/REQUEST-949-BLOCKING-EVALUATION.conf
crs/rules/RESPONSE-950-DATA-LEAKAGES.conf
crs/rules/RESPONSE-951-DATA-LEAKAGES-SQL.conf
crs/rules/RESPONSE-952-DATA-LEAKAGES-JAVA.conf
crs/rules/RESPONSE-953-DATA-LEAKAGES-PHP.conf
crs/rules/RESPONSE-954-DATA-LEAKAGES-IIS.conf
crs/rules/RESPONSE-959-BLOCKING-EVALUATION.conf
crs/rules/RESPONSE-980-CORRELATION.conf
```

Die Regel Dateien gruppieren sich in Request und in Response Regeln. Wir starten mit einer Initialisierungsregel-Datei mit der Nummer 901. Im `crs-setup.conf` sind sehr viele Sachen auskommentiert. So lange sie nicht aktiviert werden, setzt das 901er Regel-File einfach einen Default-Wert. Dies erlaubt es uns, mit einer einfachen und sauberen Konfiguration zu arbeiten und dennoch vernünftige Default-Werte zu setzen. Danach folgen zwei applikationsspezifische Dateien für Drupal und Wordpress. Darauf folgt ein File mit Ausnahmen, das für uns für den Moment ohne Belang ist. Mit 910 geht es mit den richtigen Regeln los.

Jede Datei widmet sich einem Thema respektive einem Angriffstyp. Das CRS besetzt den Zahlenraum der IDs von 900'000 bis 999'999. Die ersten drei Zahlenwerte jeder einzelnen Regel korrespondieren mit den drei Zahlen im Namen der Regeldatei. Das bedeutet die IP Reputations Regeln in der Datei `REQUEST-910-IP-REPUTATION.conf` besetzen den Zahlrenaum von 910'000 bis 910'999. Die Regeln, welche die Methode durchsetzen, folgen von 911'000 bis 911'999, und so weiter. Manche dieser Regeldateien sind klein und sie nützen den ihnen zugewiesenen Zahlenraum bei weitem nicht aus. Andere sind viel grösser und die berüchtigten SQL Injection Regeln riskieren das Dach ihrer IDs eines Tages zu erreichen.

Eine wichtige Datei ist `REQUEST-949-BLOCKING-EVALUATION.conf`. Darin wird der Anomalie-Wert gegen die Limite für die eingehenden Anfragen verglichen und gegebenenfalls blockiert.

Darauf folgenden die Regeln, die sich um die Antworten kümmern. Sie sind geringer in der Anzahl und suchen prinzipiell nach Code Lecks (Stack Traces!) und Lecks in Fehlermeldungen (die einem Angreifer sehr dabei helfen, eine SQL Attacke zu konstruieren). Der Anomalie-Wert der Antworten wird im Regel-File mit dem Prefix 959 überprüft.

Manche Regeln kommen mit Daten-Files. Diese Dateien haben die `.data` Endung und residieren in demselben Verzeichnis, wie die Regeln. Diese Daten-Files werden typischerweise dann verwendet, wenn eine Anfrage gegen eine lange Liste mit Schlüsselwörtern wie unerwünschte User-Agents oder PHP Funktionsnamen geprüft werden müssen. Es ist ganz interessant, da mal einen Blick drauf zu werfen.

In unserer Apache Konfiguration ist vor und nach der *Include* Direktive für die Regeln etwas Platz frei. Dort werden wir uns in Zukunft um die Fehlalarme kümmern. Manche werden behandelt, bevor die Regel selbst zugeladen wird. Andere kommen erst zum Zug, wenn die Regel bereits hereingeladen wurde; also nach dem *Include* Statement. Wir kommen später in dieser Anleitung darauf zurück.

Der Vollständigkeit halber hier die komplette Apache Konfiguration inklusive ModSecurity, dem CRS und all den Konfigurationsteilen von früheren Anleitungen auf die wir uns abstützen.

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
MaxRequestWorkers 100

Listen            127.0.0.1:80
Listen            127.0.0.1:443

LoadModule        mpm_event_module        modules/mod_mpm_event.so
LoadModule        unixd_module            modules/mod_unixd.so

LoadModule        log_config_module       modules/mod_log_config.so
LoadModule        logio_module            modules/mod_logio.so

LoadModule        authn_core_module       modules/mod_authn_core.so
LoadModule        authz_core_module       modules/mod_authz_core.so

LoadModule        ssl_module              modules/mod_ssl.so

LoadModule        unique_id_module        modules/mod_unique_id.so
LoadModule        security2_module        modules/mod_security2.so

ErrorLogFormat          "[%{cu}t] [%-m:%-l] %-a %-L %M"
LogFormat "%h %{GEOIP_COUNTRY_CODE}e %u [%{%Y-%m-%d %H:%M:%S}t.%{usec_frac}t] \"%r\" %>s %b \
\"%{Referer}i\" \"%{User-Agent}i\" %v %A %p %R %{BALANCER_WORKER_ROUTE}e %X \"%{cookie}n\" \
%{UNIQUE_ID}e %{SSL_PROTOCOL}x %{SSL_CIPHER}x %I %O %{ratio}n%% \
%D %{ModSecTimeIn}e %{ApplicationTime}e %{ModSecTimeOut}e \
%{ModSecAnomalyScoreIn}e %{ModSecAnomalyScoreOut}e" extended

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

SecPcreMatchLimit             100000
SecPcreMatchLimitRecursion    100000

SecTmpDir                     /tmp/
SecUploadDir                  /tmp/
SecDataDir                    /tmp/

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

SecAction "id:90000,phase:1,nolog,pass,setvar:TX.ModSecTimestamp1start=%{DURATION}"
SecAction "id:90001,phase:2,nolog,pass,setvar:TX.ModSecTimestamp2start=%{DURATION}"
SecAction "id:90002,phase:3,nolog,pass,setvar:TX.ModSecTimestamp3start=%{DURATION}"
SecAction "id:90003,phase:4,nolog,pass,setvar:TX.ModSecTimestamp4start=%{DURATION}"
SecAction "id:90004,phase:5,nolog,pass,setvar:TX.ModSecTimestamp5start=%{DURATION}"
                      
# SecRule REQUEST_FILENAME "@beginsWith /" "id:90005,phase:5,t:none,nolog,noauditlog,pass,\
# setenv:write_perflog"



# === ModSec Recommended Rules (in modsec src package) (ids: 200000-200010)

SecRule REQUEST_HEADERS:Content-Type "text/xml" \
  "id:200000,phase:1,t:none,t:lowercase,pass,nolog,ctl:requestBodyProcessor=XML"

SecRule REQBODY_ERROR "!@eq 0" \
  "id:200001,phase:2,t:none,deny,status:400,log,msg:'Failed to parse request body.',\
  logdata:'%{reqbody_error_msg}',severity:2"

SecRule MULTIPART_STRICT_ERROR "!@eq 0" \
"id:200002,phase:2,t:none,log,deny,status:403, \
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

SecRule TX:/^MSC_/ "!@streq 0" \
  "ID:200004,phase:2,t:none,deny,status:500,\
  msg:'ModSecurity internal error flagged: %{MATCHED_VAR_NAME}'"


# === ModSec Core Rules Base Configuration (ids: 900000-900999)

Include    /apache/conf/crs/crs-setup.conf

SecAction "id:900110,phase:1,pass,nolog,\
  setvar:tx.inbound_anomaly_score_threshold=1000,\
  setvar:tx.outbound_anomaly_score_threshold=1000"

SecAction "id:900000,phase:1,pass,nolog,\
  setvar:tx.paranoia_level=1"


# === ModSec Core Rules: Runtime Exclusion Rules (ids: 10000-49999)

# ...


# === ModSecurity Core Rules Inclusion

Include    /apache/conf/crs/rules/*.conf


# === ModSec Core Rules: Config Time Exclusion Rules (no ids)

# ...


# === ModSec Timestamps at the End of Each Phase (ids: 90010 - 90019)

SecAction "id:90010,phase:1,pass,nolog,setvar:TX.ModSecTimestamp1end=%{DURATION}"
SecAction "id:90011,phase:2,pass,nolog,setvar:TX.ModSecTimestamp2end=%{DURATION}"
SecAction "id:90012,phase:3,pass,nolog,setvar:TX.ModSecTimestamp3end=%{DURATION}"
SecAction "id:90013,phase:4,pass,nolog,setvar:TX.ModSecTimestamp4end=%{DURATION}"
SecAction "id:90014,phase:5,pass,nolog,setvar:TX.ModSecTimestamp5end=%{DURATION}"


# === ModSec performance calculations and variable export (ids: 90100 - 90199)

SecAction "id:90100,phase:5,pass,nolog,\
  setvar:TX.perf_modsecinbound=%{PERF_PHASE1},\
  setvar:TX.perf_modsecinbound=+%{PERF_PHASE2},\
  setvar:TX.perf_application=%{TX.ModSecTimestamp3start},\
  setvar:TX.perf_application=-%{TX.ModSecTimestamp2end},\
  setvar:TX.perf_modsecoutbound=%{PERF_PHASE3},\
  setvar:TX.perf_modsecoutbound=+%{PERF_PHASE4},\
  setenv:ModSecTimeIn=%{TX.perf_modsecinbound},\
  setenv:ApplicationTime=%{TX.perf_application},\
  setenv:ModSecTimeOut=%{TX.perf_modsecoutbound},\
  setenv:ModSecAnomalyScoreIn=%{TX.anomaly_score},\
  setenv:ModSecAnomalyScoreOut=%{TX.outbound_anomaly_score}"

SSLCertificateKeyFile   /etc/ssl/private/ssl-cert-snakeoil.key
SSLCertificateFile      /etc/ssl/certs/ssl-cert-snakeoil.pem

SSLProtocol             All -SSLv2 -SSLv3
SSLCipherSuite          'kEECDH+ECDSA kEECDH kEDH HIGH +SHA !aNULL !eNULL !LOW !MEDIUM !MD5 !EXP !DSS \
!PSK !SRP !kECDH !CAMELLIA !RC4'
SSLHonorCipherOrder     On

SSLRandomSeed           startup file:/dev/urandom 2048
SSLRandomSeed           connect builtin

DocumentRoot		/apache/htdocs

<Directory />
      
	Require all denied

	Options SymLinksIfOwnerMatch

</Directory>

<VirtualHost 127.0.0.1:80>
      
      <Directory /apache/htdocs>

        Require all granted

        Options None

      </Directory>

</VirtualHost>

<VirtualHost 127.0.0.1:443>
    
      SSLEngine On

      <Directory /apache/htdocs>

              Require all granted

              Options None

      </Directory>

</VirtualHost>

```

Wir haben das CRS eingebettet und sind nun für den Testbetrieb bereit. Die Regeln inspizieren Anfragen und Antworten. Sie werden Alarme auslösen, wenn sie etwas merkwürdiges in den Requests vorfinden. Aber sie werden keine Transaktion blockieren, da die Anomalie-Limiten sehr hoch eingestellt wurden. Probieren wir das mal aus.

###Schritt 4: Zu Testzwecken Alarme auslösen

Zum Start machen wir etwas Einfaches. Es ist ein Rquest, der exakt eine Regel auslöst, wenn wir auf einfachste Art und Weise versuchen, eine Bash Shell aufzurufen. Wir wissen natürlich, dass unser Labor-Server gegenüber so einer dummen Attacke nicht verwundbar ist. ModSecurity weiss das aber nicht und wird immer noch versuchen uns zu schützen:

```bash
$> curl localhost/index.html?exec=/bin/bash
<html><body><h1>It works!</h1></body></html>
```

Wie vorausgesagt wurden wir nicht blockiert, aber schauen wir uns die Logs einmal an und schauen wir, ob etwas passiert ist:

```bash
$> tail -1 /apache/logs/access.log
127.0.0.1 - - [2016-10-25 08:40:01.881647] "GET /index.html?exec=/bin/bash HTTP/1.1" 200 48 "-" …
"curl/7.35.0" localhost 127.0.0.1 40080 - - + "-" WA7@QX8AAQEAABC4maIAAAAV - - 98 234 -% …
7672 2569 117 479 5 0
```

Es sieht nach einem Standard `GET` Request aus, der den Status 200 retourniert. Der interessante Teil ist das zweite Feld von hinten aus gezählt. In der Anleitung zum Access Log haben wir ein ausführliches Log-Format definiert, in dem wir zwei Positionen für die beiden Anomaly Scores reserviert haben.  Bis dato waren diese Werte leer; jetzt werden sie aber gefüllt. Der erste der beiden Werte ist der Wert für den Request, der zweite den für die Antwort. Unsere Anfrage mit dem Parameter `/bin/bash` gab uns einen Anomalie-Wert von 5. Dies wird vom CRS als kritische Regelverletzung betrachtet. Eine Verletzung der Stufe *Error* ergibt 4 Punkte, eine Warnung 3 und bei einer Notiz sind es noch 2 Punkte. Wenn man die CRS Regeln überblickt, dann zeigt sich, dass die allermeisten eine kritische Verletzung beschreiben und jeweils einen Wert von 5 zuweisen.

Aber eigentlich möchten wir ja wissen, welche Regel den Alarm auslöste. Wir können einfach des Ende des Error Logs ausgeben. Aber benützen wir doch die Unique ID um alle Nachrichten aus dem Error Log herauszufiltern, welche unseren Request betreffen. Die Unique ID war Teil des Access Logs (*WA7@QX8AAQEAABC4maIAAAAV*), das ist also sehr einfach.


```bash
[2016-10-25 08:40:01.881938] [authz_core:debug] 127.0.0.1:42732 WA7@QX8AAQEAABC4maIAAAAV AH01626:…
authorization result of Require all granted: granted
[2016-10-25 08:40:01.882000] [authz_core:debug] 127.0.0.1:42732 WA7@QX8AAQEAABC4maIAAAAV AH01626:…
authorization result of <RequireAny>: granted
[2016-10-25 08:40:01.884172] [-:error] 127.0.0.1:42732 WA7@QX8AAQEAABC4maIAAAAV …
[client 127.0.0.1] ModSecurity: Warning. Matched phrase "/bin/bash" at ARGS:exec. …
[file "/apache/conf/crs/rules/REQUEST-932-APPLICATION-ATTACK-RCE.conf"] [line "448"] …
[id "932160"] [rev "1"] [msg "Remote Command Execution: Unix Shell Code Found"] …
[data "Matched Data: /bin/bash found within ARGS:exec: /bin/bash"] [severity "CRITICAL"] …
[ver "OWASP_CRS/3.0.0"] [maturity "1"] [accuracy "8"] [tag "application-multi"] …
[tag "language-shell"] [tag "platform-unix"] [tag "attack-rce"] …
[tag "OWASP_CRS/WEB_ATTACK/COMMAND_INJECTION"] [tag "WASCTC/WASC-31"] [tag "OWASP_TOP_10/A1"] …
[tag "PCI/6.5.2"] [hostname "localhost"] [uri "/index.html"] …
[unique_id "WA7@QX8AAQEAABC4maIAAAAV"]
```

Das Authorisierungsmodul rapportiert zwei Mal im Logfile auf Stufe Debug. Aber auf der dritten Zeile sehen wir den Alarm, den wir suchen. Schauen wir uns das im Detail an. Die CRS Logeinträge enthalten viel mehr Informationen als eine normale Apache Meldung, so dass es sich wirklich lohnt, das Logformat noch einmal im Detail zu betrachten.

Der Beginn der Zeile besteht aus apache-spezifischen Teilen wie dem Zeitstempel und der Severity, also dem Schweregrad der Meldung, so wie der Server es betrachtet. *ModSecurity* Nachrichten besitzen immer die Stufe *Error*. Das Logformat von ModSecurity und das Apache Error Log, so wie wir es definiert haben, besitzen einige Redundanzen. Das erste Auftauchen der IP Adresse des Clients mit der Source Port Nummer und die Unique ID des Requests werden von Apache geschrieben. Die eckigen Klammern mit derselben Client IP Adresse markiert den Beginn der ModSecurity Alarm Meldung. Die charakteristische Markierung des CRS ist `ModSecurity: Warning`. Es beschreibt, dass eine Regel ausgelöst wurde, ohne dass die Anfrage blockiert worden wäre. Dies zeigt, dass die Regel ausgeschlagen hat, aber lediglich der Anomalie-Wert erhöht wurde. Es ist sehr einfach zwischen einem Alarm und einer tatsächlichen Blockade zu unterscheiden. Namentlich weil die einzelnen Regeln ja nie blockieren, sondern immer nur den Zähler erhöhen. Die Blockage selbst wird von einer separaten Regel ausgelöst, welche den Anomalie-Wert überprüft. Aber da wir ja eine sehr hohe Limite gesetzt haben, dürfen wir annehmen, dass das nicht so schnell passiert. ModSecurity umschreibt Regelverletzungen immer als *ModSecurity. Warning ...*. Die Blockaden werden dann als *ModSecurity. Access denied ...* rapportiert. Eine Warnung hat nie einen direkten Einfluss auf den Client: Solange wir kein *Access denied ...* sehen, können wir sicher sein, dass ModSecurity den Client und seine Anfrage nicht beeinträchtigt hat.

Was folgt darauf? Eine Referenz auf das Zeichenmuster, das in der Anfrage gefunden wurde. Die spezifische Muster `/bin/bash` wurde im Parameter `exec` entdeckt. Dann folgt eine Serie mit Informationsbrocken mit demselben, sich wiederholenden Format: Sie stehen in Klammern und besitzen ihren eigenen Identifikator. Zunächst sehen wir den *file* Identifikator. Er zeigt an, in welchem File die Regel, welche den Alarm auslöste, zu finden ist. Dies wird von der Zeilennummer innerhalb der Datei gefolgt. Der *id* Parameter ist wichtig. Die Regel *932160*, um die es hier geht, befindet sich in der Gruppe von Regeln, welche sich gegen Remote Command Execution wehren, also gegen das ausführen von Kommandos auf unserem Server. Diese sind im Block 932'000 bis 932'999 definiert. Dann folgt *rev* als Referenz an die Revisionsnummer der Regel. Im CRS macht dieser Wert eine Aussage darüber wie oft eine Regel revidiert worden ist. Wenn sie revidiert wird, dann wird *rev* um eines erhöht. Das Kürzel *msg*, kurz für *message*, beschreibt den Typ der Attacke der entdeckt worden ist. Der relevante Teil des Anfrage, der *exec* Parameter, erscheint im Block *data*. In meinem Beispiel geht es also ganz klar um einen Fall von *Remote Code Execution* (RCE).

Dann folgt die Schwere des Regelverstosses, der *Severity Level*. Dies korrespondiert mit dem Anomalie-Wert der Regel. Wir haben bereits festgestellt, dass es sich um eine kritische Regelverletzung handelt. Deshalb wird die dies auch hier auf dieser Stufe rapportiert. Mit *ver* kommen wir zur Release-Identifikation des CRS, gefolgt von *maturity* und dann *accuracy*. Beide Werte sind als Referenz auf die Qualität einer Regel gemeint. Aber der Support ist inkonsistent und man sollte den Werten nicht allzu sehe vertrauen.

Dann kommen wir zu den Tags, die der Regel zugewiesen sind. Sie werden jedem Alarm mitgegeben. Die Tags klassifizieren den Typ der Attacke. Die Referenzen können zum Beispiel für die Analyse und die Statistik eingesetzt werden. Zum Ende folgen drei weitere Werte, Hostname, URI und Unique ID, welche den Request noch etwas klarer definieren (Die *unique_id*, bereits durch Apache gelistet, ist etwas redundant).

Damit haben wir die komplette Alarmmeldung, welche zu einem Anomalie-Wert von 5 führte, untersucht. Es handelte sich nur um eine einzige Anfrage mit einem einzigen Alarm. Generieren wir doch mal weitere Alarme. *Nikto* ist ein einfaches Hilfsmittel, das uns in dieser Situation helfen kann. Es ist ein Security Sanner, der seit Urzeiten existiert. Er ist nicht sehr mächtig, aber einfach in der Benutzung und sehr schnell. Also genau das richtige Tool, um viele Alarme zu generieren. *Nikto* muss vermutlich noch installiert werden. Der Scanner ist aber in den meisten Distributionen enthalten.


```bash
$> nikto -h localhost
- Nikto v2.1.4
---------------------------------------------------------------------------
+ Target IP:          127.0.0.1
+ Target Hostname:    localhost
+ Target Port:        80
+ Start Time:         2016-10-26 10:07:07
---------------------------------------------------------------------------
+ Server: Apache
+ No CGI Directories found (use '-C all' to force check all possible dirs)
+ ETag header found on server, fields: 0x30 0x53ab921464f15 
+ Allowed HTTP Methods: GET, HEAD, POST, OPTIONS 
+ /login.php: Admin login page/section found.
+ 6448 items checked: 0 error(s) and 3 item(s) reported on remote host
+ End Time:           2016-10-26 10:07:57 (50 seconds)
---------------------------------------------------------------------------
+ 1 host(s) tested
```

Dieser Scan dürfte zahlreiche *ModSecurity Alarme* auf dem Server ausgelöst haben. Werfen wir einen Blick auf das Error Log. In meinem Fall gab es mehr als 7'300 Einträge. Wenn wir diese diese mit den zahlreichen Authorisierungsnachrichten und den Hinweisen auf die zahlreichen 404er (Nikto Proben auf Dateien, welche auf unserem Server nicht vorhanden sind) zusammennehmen, dann landen wir sehr schnell bei einem rapide wachsenden Error Log. Der einzelne Nikto-Lauf führte bei mir zu einer Logdatei von 8,8MB. Wenn wir über den Baum mit den Audit Logs schauen, dann sehen wir sogar 78 MB Logfiles. Es ist offensichtlich: Man muss ein genaues Auge auf diese Log-Dateien halten oder der Server bricht unter einer Denial of Service Attacke auf die schiere Grösse der Logfiles zusammen.


###Schritt 5: Analysieren der Alarme

Wir betrachten also 7'300 Alarme. Und selbst wenn das Format der Einträge jetzt klar ist, ohne ein Hilfsmittel ist das alles sehr schwer zu lesen, geschweige denn zu analysieren. Eine einfache Abhilfe sind einige *Shell Aliase*, welche individuelle Informationsteile aus den Einträgen herausschneidet. Diese neuen Aliase sind bereits im Alias-File vorhanden, das wir in der Anleitung zu dem Logformat des Access Logs betrachtet haben.


```
$> cat ~/.apache-modsec.alias
...
alias meldata='grep -o "\[data [^]]*" | cut -d\" -f2'
alias melfile='grep -o "\[file [^]]*" | cut -d\" -f2'
alias melhostname='grep -o "\[hostname [^]]*" | cut -d\" -f2'
alias melid='grep -o "\[id [^]]*" | cut -d\" -f2'
alias melip='grep -o "\[client [^]]*" | cut -b9-'
alias melline='grep -o "\[line [^]]*" | cut -d\" -f2'
alias melmatch='grep -o " at [^\ ]*\. \[file" | sed -e "s/\. \[file//" | cut -b5-'
alias melmsg='grep -o "\[msg [^]]*" | cut -d\" -f2'
alias meltimestamp='cut -b2-25'
alias melunique_id='grep -o "\[unique_id [^]]*" | cut -d\" -f2'
alias meluri='grep -o "\[uri [^]]*" | cut -d\" -f2'
...
$> source ~/.apache-modsec.alias 
```

Diese Abkürzungen beginnen mit dem Präfix *mel*, kurz für *ModSecurity error log*, gefolgt vom Feldnamen. Versuchen wir es, die Regel-IDs aus den Nachrichten auszugeben:

```
$> cat logs/error.log | melid | tail
941160
920440
920440
911100
920100
930100
930110
930110
930120
932160
```

Das scheint das zu machen, was wir erwarten. Erweitern wir das Beispiel in ein paar Schritten:

```
$> cat logs/error.log | melid | sort | uniq -c | sort -n
      1 920220
      1 920290
      1 921150
      1 932115
      2 920280
      2 941140
      3 942270
      4 920420
      4 933150
      6 932110
      9 911100
     11 920100
     12 942100
     13 920430
     13 932100
     13 932105
     15 941170
     15 941210
     17 920170
     35 932150
     67 933130
     70 933160
    115 941180
    136 920270
    139 932160
    141 931110
    191 930100
    219 920440
    219 930120
    246 941110
    248 941100
    249 941160
    531 930110
   2274 931120
   2340 913120
$> cat logs/error.log | melid | sort | uniq -c | sort -n | while read STR; do \
echo -n "$STR "; \
ID=$(echo "$STR" | sed -e "s/.*\ //"); \
grep $ID logs/error.log | head -1 | melmsg; \
done
1 920220 URL Encoding Abuse Attack Attempt
1 920290 Empty Host Header
1 921150 HTTP Header Injection Attack via payload (CR/LF deteced)
1 932115 Remote Command Execution: Windows Command Injection
2 920280 Request Missing a Host Header
2 941140 XSS Filter - Category 4: Javascript URI Vector
3 942270 Looking for basic sql injection. Common attack string for mysql, oracle and others.
4 920420 Request content type is not allowed by policy
4 933150 PHP Injection Attack: High-Risk PHP Function Name Found
6 932110 Remote Command Execution: Windows Command Injection
9 911100 Method is not allowed by policy
11 920100 Invalid HTTP Request Line
12 942100 SQL Injection Attack Detected via libinjection
13 920430 HTTP protocol version is not allowed by policy
13 932100 Remote Command Execution: Unix Command Injection
13 932105 Remote Command Execution: Unix Command Injection
15 941170 NoScript XSS InjectionChecker: Attribute Injection
15 941210 IE XSS Filters - Attack Detected.
17 920170 GET or HEAD Request with Body Content.
35 932150 Remote Command Execution: Direct Unix Command Execution
67 933130 PHP Injection Attack: Variables Found
70 933160 PHP Injection Attack: High-Risk PHP Function Call Found
115 941180 Node-Validator Blacklist Keywords
136 920270 Invalid character in request (null character)
139 932160 Remote Command Execution: Unix Shell Code Found
141 931110 Possible Remote File Inclusion (RFI) Attack: Common RFI Vulnerable Parameter Name …
191 930100 Path Traversal Attack (/../)
219 920440 URL file extension is restricted by policy
219 930120 OS File Access Attempt
246 941110 XSS Filter - Category 1: Script Tag Vector
248 941100 XSS Attack Detected via libinjection
249 941160 NoScript XSS InjectionChecker: HTML Injection
531 930110 Path Traversal Attack (/../)
2274 931120 Possible Remote File Inclusion (RFI) Attack: URL Payload Used w/Trailing Question …
2340 913120 Found request filename/argument associated with security scanner
```

Damit können wir arbeiten. Aber es ist vielleicht notwendig, die Kommandos zu erklären. Wir extrahieren die Regel-IDs aus dem Error Log, dann sortieren wir sie, summieren sie mittels `uniq -c` und sortieren sie wieder nach der Anzahl der gefundenen Zahlen. Das ist der erste Kommando-Block. Eine Beziehung zwischen den einzelnen Regeln fehlt noch, denn mit der ID-Nummer ist noch nicht viel anzufangen. Wir erhalten die Namen aus dem Error Log, indem wir den vorher durchgeführten Test zeilenweise in einer Schleife durchführen. Wir füllen die ID, welche wir haben, in die Schleife (`$STR`). Dann separieren wir die Anzahl der jeweils pro ID gefundenen Alarme wieder von der ID. Die geschieht mittels einem eingebetteten Unterbefehls (`ID = $ (echo" $ STR "| sed -e" s /.* \ // ")`). Wir verwenden dann die IDs, die wir gerade gefunden haben, um das Error-Log noch einmal für einen Eintrag zu durchsuchen. Wir nehmen aber nur die erste Fundstelle und Extrahieren den *msg* Teil und zeigen ihn an. Fertig.

Man könnte jetzt denken, dass es besser wäre, einen zusätzlichen Alias zu definieren, um die ID und die Beschreibung der Regel in einem einzigen Schritt zu definieren. Dies führt uns jedoch auf den falschen Weg, denn es gibt Regeln, die dynamische Teile in und nach den Klammern enthalten (zum Beispiel Anomalie-Werte in den Regeln, die den Schwellenwert überprüfen: ID 949110 und 980130!). Das würde also nicht klappen. Denn natürlich wollen wir diese Alarme kombinieren und zusammenfügen, um die Regel nur einmal zuzuordnen. Um die Analyse wirklich zu vereinfachen, müssen wir die dynamischen Elemente herauslöschen. Hier ist ein zusätzlicher Alias, der diese Idee implementiert und auch Teil der `.apache-modsec.alias` Datei ist:

```bash
alias melidmsg='grep -o "\[id [^]]*\].*\[msg [^]]*\]" | \
sed -e "s/\].*\[/] [/" -e "s/\[msg //" |\
cut -d\  -f2- | tr -d "\]\"" | sed -e "s/(Total .*/(Total ...) .../"'
```

```bash
$> cat logs/error.log | melidmsg | sucs
      1 920220 URL Encoding Abuse Attack Attempt
      1 920290 Empty Host Header
      1 921150 HTTP Header Injection Attack via payload (CR/LF deteced)
      1 932115 Remote Command Execution: Windows Command Injection
      2 920280 Request Missing a Host Header
      2 941140 XSS Filter - Category 4: Javascript URI Vector
      3 942270 Looking for basic sql injection. Common attack string for mysql, oracle …
      4 920420 Request content type is not allowed by policy
      4 933150 PHP Injection Attack: High-Risk PHP Function Name Found
      6 932110 Remote Command Execution: Windows Command Injection
      9 911100 Method is not allowed by policy
     11 920100 Invalid HTTP Request Line
     12 942100 SQL Injection Attack Detected via libinjection
     13 920430 HTTP protocol version is not allowed by policy
     13 932100 Remote Command Execution: Unix Command Injection
     13 932105 Remote Command Execution: Unix Command Injection
     15 941170 NoScript XSS InjectionChecker: Attribute Injection
     15 941210 IE XSS Filters - Attack Detected.
     17 920170 GET or HEAD Request with Body Content.
     35 932150 Remote Command Execution: Direct Unix Command Execution
     67 933130 PHP Injection Attack: Variables Found
     70 933160 PHP Injection Attack: High-Risk PHP Function Call Found
    115 941180 Node-Validator Blacklist Keywords
    136 920270 Invalid character in request (null character)
    139 932160 Remote Command Execution: Unix Shell Code Found
    141 931110 Possible Remote File Inclusion (RFI) Attack: Common RFI Vulnerable Parameter …
    191 930100 Path Traversal Attack (/../)
    219 920440 URL file extension is restricted by policy
    219 930120 OS File Access Attempt
    246 941110 XSS Filter - Category 1: Script Tag Vector
    248 941100 XSS Attack Detected via libinjection
    249 941160 NoScript XSS InjectionChecker: HTML Injection
    531 930110 Path Traversal Attack (/../)
   2274 931120 Possible Remote File Inclusion (RFI) Attack: URL Payload Used w/Trailing …
   2340 913120 Found request filename/argument associated with security scanner
```

Das bringt uns weiter. Es zeigt sich, dass die Core Rules viele böswillige Anfragen entdeckt haben und wir haben jetzt eine Idee, welche Regeln dabei eine Rolle spielten. Die Regel, die am häufigsten ausgelöst wurde, *913120*, ist keine Überraschung, und wenn man in der Ausgabe nach oben schaut, macht das alles wirklich Sinn.

###Schritt 6: Falsche Alarme auswerten

Der *Nikto* Scan löste also tausende von Alarmen aus. Sie waren wahrscheinlich gerechtfertigt. In der normalen Verwendung von *ModSecurity* stehen die Dinge freilich etwas anders aus. Das Core Rule Set wurde so konzipiert und optimiert, dass sie in der Paranoia Stufe 1 so wenige Fehlalarme wie möglich auslösen. Doch in der Produktion wird es früher oder später False Positives geben. Je nach Anwendung sind sie häufiger oder seltener. Aber selbst eine normale Installation dürfte früher oder später Fehlalarme aufweisen. Und wenn wir den Paranoia Level erhöhen, um gegenüber Angriffen wachsamer zu sein, dann wird auch die Menge der False Positives ansteigen. Sehr steil wird der Anstieg, wenn wir bis zu PL 3 oder 4 gehen. So steil, dass es einige explodieren nennen würden.

Um reibungslos laufen zu können, muss zuerst die Konfiguration fein abgestimmt werden. Legitime Anträge und Angriffsversuche müssen unterschieden werden können. Wir wollen ein grosse Trennschärfe erreichen. Wir wollen *ModSecurity* und das CRS so konfigurieren, dass das System genau weiss, wie man zwischen legitimen Anfragen und Angriffen unterscheidet.

Falsche Alarme sind in beide Richtungen möglich. Angriffe, die nicht erkannt werden, werden als *False Negatives* bezeichnet. Die Core Rules sind strikt und sehr sorgfältig, um die Anzahl der *Falschen Negatives* niedrig zu halten. Ein Angreifer muss viel Detailwissen besitzen, um das Regelwerk umgehen zu können; gerade in den höheren Paranoia-Levels. Leider führt diese Strenge auch dazu, dass Alarme für normale Anfragen ausgelöst werden. Meist weist es auf eine ungenügende Trennschärfe hin, wenn *False Positives* oder *False Negatives* vorkommen. Beide Werte hängen eng zusammen: Reduziert man die Menge der *False Negatives* erhält man dafür mehr *False Positives* und umgekehrt. Beide korrelieren stark miteinander.

Wir müssen diesen Zusammenhang überwinden: Wir wollen die Trennschärfe erhöhen, um die Anzahl der *False Positives* zu verringern, ohne die Anzahl der *Falschen Negatives* zu erhöhen. Wir können dies durch Feinabstimmung des Regelwerks an einigen wenigen Stellen tun. Für bestimmte Anfragen oder Parameter müssen dazu bestimmte Regeln ausgeschlossen werden. Aber zuerst müssen wir ein klares Bild von der aktuellen Situation haben: Wie viele *False Positives* gibt es und welche der Regeln werden in einem bestimmten Kontext verletzt? Wie viele *False Positives* sind wir bereit, auf dem System zu erlauben? Sie auf Null zu reduzieren ist sehr herausfordernd, wenn man den Schutz aufrecht erhalten will. Aber wir können mit Prozentsätzen arbeiten. Ein mögliches Ziel wäre: 99,99% der legitimen Anfragen sollten passiwren, ohne von der WAF blockiert zu werden. Dies ist realistisch, erfordert aber je nach Anwendung ein wenig Arbeit. 99,99% der Anfragen ohne einen falschen Alarm ist auch eine Zahl, wo professionelle Nutzung beginnt. Aber ich habe Setups, wo wir nicht bereit sind, mehr als 1 falscher Alarm in 1 Million von Anfragen zu akzeptieren. Das sind 99,9999%.

Um ein solches Ziel zu erreichen, benötigen wir ein oder zwei Werkzeuge, um uns eine gute Basis zu verschaffen. Genauer gesagt, müssen wir mehr über die Zahlen herausfinden. Dann, in einem zweiten Schritt betrachten wir das Error Log, um zu verstehen, welche Regeln genau zu den Alarmen geführt haben. Wir haben gesehen, dass das Zugriffslog die Anomalie-Werte der Anfragen rapporiert. Versuchen wir diese Werte zu extrahieren und sie in einer passenden Form darzustellen.

In der Anleitung 5 arbeiteten wir mit einer Beispielprotokolldatei mit 10'000 Einträgen. Wir verwenden diese Protokolldatei erneut: [tutorial-5-example-access.log](https://www.netnea.com/files/tutorial-5-example-access.log). Die Datei kommt von einem echten Server, aber die IP-Adressen, Servernamen und Pfade wurden vereinfacht oder umgeschrieben. Die Informationen, die wir für unsere Analyse benötigen, sind aber noch da. Werfen wir doch mal einen Blick auf die Verteilung der Anomalie-Werte:

```
$> egrep -o "[0-9-]+ [0-9-]+$" tutorial-5-example-access.log | cut -d\  -f1 | sucs
      1 21
      2 41
      8 5
     11 2
     17 3
     41 -
   9920 0
$> egrep -o "[0-9-]+$" tutorial-5-example-access.log | sucs
     41 -
   9959 0
```

Die erste Befehlszeile liest die eingehenden Anomalie-Werte. Es ist der zweitletzte Wert auf der Access-log Zeile. Wir nehmen die beiden letzten Werte (*egrep*) und dann schneiden wir den ersten mittels *cut* heraus. Danach sortieren wir die Ergebnisse mit dem vertrauten *sucs* alias. Der ausgehende Anomalie Wert ist der letzte Wert auf der Logzeile. Aus diesem Grund braucht es keinen *cut*-Befehl in der zweiten Kommandozeile.

Die Ergebnisse geben uns eine Vorstellung von der Situation: Die überwiegende Mehrheit der Anfragen passiert das ModSecurity-Modul ohne Regelverstoss: 9920 Anfragen mit der Punktzahl 0. 41 Anfragen verletzten eine oder mehrere Regeln. Das sind relative viele für eine Core Rule Set 3.0 Installation. In der Tat, ich habe zusätzliche falsche Alarme provoziert, um wirklich etwas zu sehen. Denn das CRS ist heutzutage soweit optimiert, dass es viel Verkehr braucht, um eine gewisse Menge an Alarmen zu erhalten - oder wir müssten den Paranoia Level auf einem nicht abgestimmten System sehr hoch einstellen.

Der Wert 41 erscheint zweimal, was einer hohen Anzahl von schwerwiegenden Regelverletzungen entspricht. Dies ist sehr häufig in der Praxis, denn eine ernsthafte SQL Injection verursacht eine ganze Reihe von Alarmen. In 41 Fällen haben wir keinen Wert für die Antworten des Servers erhalten. Dabei handelt es sich um Protokolleinträge leerer Anfragen, bei denen eine Verbindung zum Client aufgebaut wurde, aber keine Anforderung gestellt wurde. Wir haben diese Möglichkeit im regulären Ausdruck mit *egrep* berücksichtigt, indem auch der Standardwert "-" akzeptiert wird. Neben diesen leeren Eingaben ist nichts anderes auffällig. Dies ist typisch, wenn auch ein Bisschen hoch. In aller Regel sehen wir eine gewisse Anzahl von Verletzungen durch die Requests, aber sehr wenige Einträge aufgrund der Responses.

Aber das gibt uns immer noch nicht die richtige Idee über die Tuning Schritte, welche nötig sind, um diese Installation reibungslos laufen lassen zu können. Um diese Informationen in einer geeigneten Form präsentieren zu könnnen, habe ich ein Ruby Skript vorbereitet, das Anomalie-Werte analysiert: [modsec-positive-stats.rb](https://www.netnea.com/files/modsec-positive-stats.rb) (Eventuell muss noch das Paket _ruby_ installiert werden, damit es läuft). Es nimmt die beiden Anomalie-Scores als Eingabe; wir müssen sie allerdings mit einem Strichpunkt trennen, um sie an das Skript übergeben zu können. Das lässt sich wie folgt bewerkstelligen:

```
$> cat tutorial-5-example-access.log  | egrep -o "[0-9-]+ [0-9-]+$" | tr " " ";" | modsec-positive-stats.rb
INCOMING                     Num of req. | % of req. |  Sum of % | Missing %
Number of incoming req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. incoming score   |     41 |   0.4100% |   0.4100% |  99.5900%
Reqs with incoming score of   0 |   9920 |  99.2000% |  99.6100% |   0.3900%
Reqs with incoming score of   1 |      0 |   0.0000% |  99.6100% |   0.3900%
Reqs with incoming score of   2 |     11 |   0.1100% |  99.7200% |   0.2800%
Reqs with incoming score of   3 |     17 |   0.1699% |  99.8900% |   0.1100%
Reqs with incoming score of   4 |      0 |   0.0000% |  99.8900% |   0.1100%
Reqs with incoming score of   5 |      8 |   0.0800% |  99.9700% |   0.0300%
Reqs with incoming score of   6 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of   7 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of   8 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of   9 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  10 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  11 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  12 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  13 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  14 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  15 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  16 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  17 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  18 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  19 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  20 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  21 |      1 |   0.0100% |  99.9800% |   0.0200%
Reqs with incoming score of  22 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  23 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  24 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  25 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  26 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  27 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  28 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  29 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  30 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  31 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  32 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  33 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  34 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  35 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  36 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  37 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  38 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  39 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  40 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  41 |      2 |   0.0200% | 100.0000% |   0.0000%

Average:   0.0217        Median   0.0000         Standard deviation   0.6490


OUTGOING                     Num of req. | % of req. |  Sum of % | Missing %
Number of outgoing req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. incoming score   |     41 |   0.4100% |   0.4100% |  99.5900%
Reqs with outgoing score of   0 |   9959 |  99.5900% | 100.0000% |   0.0000%

Average:   0.0000        Median   0.0000         Standard deviation   0.0000
```

Das Skript trennt die Scores der eingehenden Anfragen von den Werten der Antworten. Die eingehenden werden zuerst behandelt. Bevor das Skript die Ergebnisse verarbeiten kann, beschreibt es, wie oft ein leerer Wert gefunden wurde. In unserem Fall war das 41 Mal so, wie wir gesehen haben. Dann kommt die Aussage für den Zahlenwert 0: 9920 Requests. Dies deckt 99,2% der Anfragen ab. Zusammen mit den leeren Werten liegen wir bereits bei 99,61% (*Sum of %*). 0,39% hatten einen höheren Anomalie Wert (*Missing %*). Wir hatten uns ja gesagt, dass 99,99% der Anfragen den Server ohne Alarme passieren können sollten. Wir sind damit etwa 0,38% oder 38 Anfragen von diesem Ziel entfernt. Der nächste vorkommende Anomalie Wert ist 2. Er erscheint 11 mal oder in etwa 0,11% der Requests. Der Anomalie Wert 3 erscheint 17 Mal und eine Punktzahl von 5 kann 8 Mal gefunden werden. Alles in allem sind wir damit bei 99,97% angelangt. Dann gibt es einen einzigen Request mit einer Punktzahl von 21 und schliesslich 2 Anfragen mit einer Punktzahl von 41. Um eine Deckung von 99,99% zu erreichen, müssen wir bis zu diesem Wert tunen. Aufgrund der 2 Anfragen mit 41 Punkten müssen wir hier faktisch eine Abdeckung von 100% erreichen.

In den oben rapportieren Werten gibt es vermutlich einige *False Positives*. In der Praxis müssen wir das ganz klar bestimmen, bevor wir mit der Feinabstimmung des Services beginnen. Es wäre völlig falsch, ein False Positive auf Grund eines berechtigten Alarms anzunehmen, den Alarm in der Zukunft zu unterdrücken und einen Angriff so zu verpassen. Vor dem Tuning müssen wir sicherstellen, dass keine Angriffe in der Protokolldatei vorhanden sind. Das ist nicht immer einfach. Manuelle Überprüfung hilft, man kann sich auf bekannte IP-Adressen beschränken, Pre-Authentifizierung, Testen / Tuning auf ein Test-System getrennt vom Internet, Filterung des Access-Protokoll nach Herkunftsland oder für eine bekannte IP-Adresse, etc.. Es gibt viele Möglichkeiten und es ist ein so grosses Thema, dass es schwierig ist, allgemein Empfehlungen zu machen. Aber das Problem muss auf jeden Fall sehr ernst genommen werden.

###Step 7: Behandlung von False Positives: Einzelne Regeln ausschalten

Der einfache Umgang mit einem False Positive besteht darin, die Regel einfach zu deaktivieren. Wir unterdrücken also den Alarm, in dem wir die Regel aus dem Regelsatz ausschliessen. Der CRS-Begriff für diese Technik heisst *Rules Exclusion* oder *Exclusion Rules*. Das Wort Regel kommt vor, weil dieser Ausschluss das Schreiben von Regeln oder Direktiven beinhaltet, die selbst wieder Regeln entsprechen.

Das Ausschliessen einer Regel macht wenig Aufwand, aber es ist natürlich potenziell riskant, da die Regel nicht nur für legitime Benutzer deaktiviert wird, sondern auch für Angreifer. Durch die vollständige Deaktivierung einer Regel beschränken wir die Fähigkeit von *ModSecurity*. Oder, drastischer ausgedrückt, ziehen wir der WAF die Zähne.

Vor allem bei höheren Paranoia-Niveaus gibt es Regeln, die einfach mit gewissen Anwendungen einfach nicht zusammenarbeiten und falsche Alarme in allen möglichen Situationen auslösen. Deshalb gibt es also durchaus Anwendungsfälle für das vollständige Deaktivieren einer Regel. Ein nennenswertes Beispiel ist Regel mit der ID `920300`: *Request Missing an Accept Heder*. Es gibt einfach sehr viele User-Agents, die Request ohne *Accept-Header* übermitteln, weshalb es eigens eine eigene Regel für dieses Problem gibt. Erhöhen wir den Paranoia Level mal auf 2 indem wir den Wert `tx.paranoia_level` in er Regel 900'000 auf 2 setzen. Dann senden wir eine Anfrage ohne *Accept-Header* und lösen damit einen Alarm aus (Ich empfehle, den Paranoia Level danach wieder auf 1 zurückzudrehen):

```bash
$> curl -v -H "Accept: " http://localhost/index.html
...
> GET /index.html HTTP/1.1
> User-Agent: curl/7.32.0
> Host: localhost
...
$> tail /apache/logs/error.log | melidmsg
920300 Request Missing an Accept Header
```

Die Regel wurde also wie gewünscht ausgelöst. Nun wollen wir diese Regel gezielt ausschliessen. Wir haben mehrere Optionen und starten mit der einfachsten: Wir schliessen die Regel zur Startzeit von Apache aus. Das bedeutet, dass wir die Regel aus dem Satz der geladenen Regel entfernen und damit sicher stellen, dass nach dem Start keine Prozessorzyklen mehr auf die Regel verschwendet werden. Natürlich können wir nur Dinge entfernen, die vorher geladen wurden. Diese Anweisung muss also nach der CRS-Include-Direktive platziert werden. Im Konfigurations-Block, den wir vorher in dieser Anleitung beschrieben haben, war ein Platz für diese Art von Auschluss-Anweisungen reserviert. Wir füllen unsere Direktive an dieser Stelle ein:

```bash
# === ModSec Core Rules: Config Time Exclusion Rules (no ids)

# ModSec Exclusion Rule: 920300 Request Missing an Accept Header
SecRuleRemoveById 920300
```

Die Anweisung steht gemeinsam mit einem Kommentar, der beschreibt, was wir überhaupt ausschliessen. Es ist generell eine gute Praxis, das so zu handhaben. Wir haben die Option, Regeln mittels einer ID zu bezeichnen (das haben wir eben gemacht), mehrere Regeln durch ein Komma getrennt aufzulisten, einen ID Bereich zu bezeichnen oder aber wir können Regeln durch ihre Tags bezeichnen. Hier ist ein Beispiel, das die Regel durch einen ihrer Tags ausschliesst:

```bash
# ModSec Exclusion Rule: 920300 Request Missing an Accept Header
SecRuleRemoveByTag "MISSING_HEADER_ACCEPT$"
```

Wie wir sehen, akzeptiert diese Richtlinie reguläre Ausdrücke als Parameter. Leider ist die Unterstützung nicht universell: Zum Beispiel ist die mit einem Pipe-Zeichen ausgedrückte *OR* Funktionalität nicht implementiert. In der Praxis muss man ausprobieren und sehen, was funktioniert und was nicht.

Technisch gibt es eine zusätzliche Richtlinie, `SecRuleRemoveByMsg`. Allerdings sind die Meldungen nicht garantiert stabil zwischen Releases und sie sind ohnehin nicht sehr konsistent. Daher sollten wir nicht versuchen, Regel Ausschlüsse für das CRS über dieses Statement zu konstruieren.

Das sind also die *Rule Exclusions* zur Startzeit. Regeln so zu umgehen ist einfach und lesbar, aber es ist auch ein drastischer Schritt, den wir in einem Produktions-Setup nicht sehr oft verwenden können. Denn wenn unsere Probleme mit der Regel 920300 auf einen einzigen legitimen Uptime-Agent beschränkt sind, der lediglich die Verfügbarkeit unseres Services überprüft, indem er die Indexseite anfordert, können wir das Ausschalten der Regel diesen individuellen Request beschränken. Dies ist nicht mehr ein Regel Ausschluss zur Startzeit, sondern neu zur Laufzeit (*Runtime*). Wir wenden ihn so an, dass er mit einer bestimmten Bedingung verknüpft wird. Runtime Ausschlüsse nutzen die *SecRule* Direktive kombiniert mit einer speziellen Aktion, die den Regelausschluss ausführt. Dies muss zur Laufzeit vor dem Ausführen der betreffenden, alarmierenden Regel geschehen. Aus diesem Grund müssen Runtime-Regelausschlüsse vor der CRS-Include-Anweisung platziert werden. Auch hierfür haben wir im Regelblock einen Bereich reserviert:


```bash
# === ModSec Core Rules: Runtime Exclusion Rules (ids: 10000-49999)

# ModSec Exclusion Rule: 920300 Request Missing an Accept Header
SecRule REQUEST_FILENAME "@streq /index.html" \
    "phase:1,nolog,pass,id:10000,ctl:ruleRemoveById=920300"
```

Das ist jetzt schwerer zu lesen. Besonders zu beachten ist das *ctl*-Statement: `ctl:ruleRemoveById=920300`. Dies ist die Steueraktion, die für Laufzeitänderungen der Konfiguration der ModSecurity-Regel-Engine verwendet wird. Wir verwenden *ruleRemoveById* als Steueranweisung und wenden diese auf die Regel ID 920300 an. Dieser Block wird innerhalb einer standardmässigen *SecRule* -Richtlinie platziert. Dies ermöglicht es uns, die volle Leistung von *SecRule* zu verwenden, um Regel 920300 in sehr spezifischen Situationen auszuschliessen. Hier schliessen wir es abhängig vom Pfad der Anforderung aus. Aber wir könnten es auch abhängig von der IP-Adresse des Agenten anwenden - oder eine Kombination der beiden in einer verketteten Befehlsfolge.

Wie bei den Ausschlüssen zur Startzeit sind wir nicht auf einen Ausschluss durch die Regel ID Nummer beschränkt. Ausschlüsse via Tags funktionieren ebenso (`ctl: ruleRemoveByTag`). Auch hier werden reguläre Ausdrücke unterstützt, aber nur bis zu einem gewissen Grad.

Startzeit Ausschlüsse von Regeln sowie Laufzeit Ausschlüsse haben dieselbe Wirkung. Intern aber sind sie fundamental unterschiedlich. Mit den Runtime-Ausschlüssen erhalten wir granulare Kontrolle auf Kosten der Leistung, da der Ausschluss für jede einzelne Anfrage neu ausgewertet wird. Startup Time Rule Exclusions sind performanter, und sie sind auch einfacher zu lesen und zu schreiben.

###Schritt 8: Behandlung von False Positives: Einzelne Regeln für bestimmte Parameter ausschalten

Als nächstes versuchen wir zu verhindern, dass eine Regel einen ganz bestimmten Parameter überprüft. Im Gegensatz zu unserem Beispiel 920300, das auf den spezifischen Accept-Header schaute, zielen wir nun auf Regeln, welche die ARGS-Variablengruppe untersuchen.

Nehmen wir an, wir haben ein Passwort-Feld in einem Authentifizierungsschema wie in der vorangegangenen Anleitung verwendet. Benutzern wird empfohlen, schwer zu erraten Passwörter mit vielen Sonderzeichen zu verwenden. Das Core Rule Set sendet darauf einen steten Strom von Warnungen aufgrund der seltsamen Muster in diesem Parameter-Feld.

Hier ist ein künstliches Beispiel, das die Regel 942100 auslöst, welche die Bibliothek libinjection nutzt, um SQL-Injektionen zu erkennen. Das Ausführen des folgenden Kommandos führt zu einem Alarm:

```bash
$> curl --data "password=' or f7x=gZs" localhost/login/login.do
```

Aus Sicherheitsperspektive ist mit diesem Passwort nichts Falsches dran. Tatsächlich sollten wir diese Regel einfach ausschalten. Aber natürlich wäre es ein Fehler, die Regel komplett auszuschalten, denn bei anderen Parametern als dem Kennwort macht die Regel sehr wohl Sinn. Idealerweise schliessen wir also nur den Parameter *password* von der Untersuchung durch diese Regel aus. Hier ist die Startzeit Direktive um diesen Parameter von der Regel 942100 zu verbergen:

```bash
# ModSec Exclusion Rule: 942100 SQL Injection Attack Detected via libinjection
SecRuleUpdateTargetById 942100 !ARGS:password
```

Diese Direktive addiert *nicht ARGS:password" zur Liste der Parameter für Regel 942100. Die schliesst den Passwort Parameter damit effektiv von der Regel aus. Die Direktive akzeptiert natürlich auch Regel-Bereiche als Parameter. Und natürlich existiert sie auch in einer Variante in der wir die Regel über ihre Tags definieren können:

```bash
# ModSec Exclusion Rule: 942100 SQL Injection Attack Detected via libinjection
SecRuleUpdateTargetByTag "attack-sqli" !ARGS:password
```

Das in diesem Beispiel verwendete Tag *attack-sqli* weist auf eine breite Palette von SQL-Injection-Regeln hin. So wird das Statement verhindern, dass eine ganze Klasse von Regeln den Passwort Parameter ignoriert. Dies ist für diesen Kennwortparameter sinnvoll, kann aber für andere Parameter zu weit gehen. Es hängt also wirklich von der Anwendung und dem betreffenden Parameter ab.

Ein Passwortparameter wird grundsätzlich nur bei der Login-Anforderung und der Registrierung verwendet, so dass wir mit der `SecRuleUpdateTargetById`-Direktive in der Praxis arbeiten können, damit alle Vorkommen des Parameters von der Regel 942100 befreit werden. Aber es gilt doch zu beachten, dass die Richtlinie serverweit wirkt. Wenn der Server also mehrere Dienste mit mehreren virtuellen Apache-Hosts beherbergt, die jeweils eine andere Anwendung ausführen, dann deaktivieren die beiden Befehle `SecRuleUpdateTargetById` und` SecRuleUpdateTargetByTag` diese Regeln für sämtliche Applikationen in deren Requests ein Parameter mit Namen *password* vorkommt.

Nehmen wir also an, dass wir *password* nur unter bestimmten Bedingungen ausschliessen möchten: Beispielsweise sollte die Regel immer dann aktiv bleiben, wenn ein Security Scanner die Anfrage übermittelt. Ein ziemlich guter Weg, um Scanner zu erkennen ist es, auf den *Referer-Header* zu achten. Wir können es so halten, dass wir den Header überprüfen und wenn er unserer Erwartung entspricht, dann deaktivieren wir die Überprüfung des Parameters *password* zur Laufzeit durch die Regel 942100. Dieser Runtime-Regelausschluss funktioniert erneut mit einer Control-Action; ähnlich wie wir es oben gesehen haben:

```bash
SecRule REQUEST_HEADERS:Referer "@streq http://localhost/login/displayLogin.do" \
    "phase:1,nolog,pass,id:10000,ctl:ruleRemoveTargetById=942100;ARGS:password"
```

Das Format der Steuer-Aktion ist wirklich schwer zu begreifen: Zusätzlich zur Regel ID fügen wir einen Strichpunkt und dann den Passwort-Parameter als Teil der ARGS-Gruppe von Variablen hinzu. In ModSecurity wird dies als ARGS-Auflistung mit dem Doppelpunkt als Trennzeichen bezeichnet. Nicht ganz leicht, aber wir müssen versuchen, uns das zu merken!

Im professionellen Einsatz ist dies wahrscheinlich dasjenige Rule Exclusion Konstrukt, das am meisten verwendet wird (nicht jedoch mit dem Referer-Header, sondern mit der Variable *REQUEST_FILENAME*). Diese ganze Direktive ist auf der Parameterebene sehr granular und kann aufgrund der Flexibilität *SecRule* so konstruiert werden, dass es nur minimale Auswirkungen auf die legitimen Requests hat. Wenn wir lieber mit einem Tag als mit einer ID arbeiten möchten, dann geht das wie folgt:

```bash
SecRule REQUEST_HEADERS:Referer "@streq http://localhost/login/displayLogin.do" \
    "phase:1,nolog,pass,id:10000,ctl:ruleRemoveTargetByTag=attack-sqli;ARGS:password"
```

Dieser Abschnitt war sehr wichtig. Daher noch einmal zusammenfassen: Wir definieren eine Regel, um eine andere Regel zu unterdrücken. Wir verwenden dafür ein Regel-Muster, das es uns erlaubt, einen Pfad als Bedingung definieren zu können. Dies ermöglicht es uns, Regeln für einzelne Teile einer Anwendung zu deaktivieren, aber nur an Stellen, an denen Fehlalarme auftreten. Und gleichzeitig bewahrt es uns davor, Regeln auf dem gesamten Server zu deaktivieren.

Damit haben wir alle vier grundlegenden Methoden gesehen, um falsche Alarme über Regelausschlüsse zu behandeln. Damit ist der Werkzeugkasten beisammen, um alle Fehlalarme nacheinander abzuarbeiten.

###Schritt 9: Die Anomalie-Limite nachjustieren

Die Behandlung von falschen Positiven ist manchmal mühsam. Doch wenn man das Ziel verfolgt, Applikationen wirklich zu schützen, dann lohnt es sich gewiss. Als wir das Statistik-Skript einführten, haben wir festgelegt, dass mindestens 99,99% der Anfragen das Regelwerk ohne False Positives passieren können sollten. Die verbleibenden Alarme, wohl in der Mehrzahl von Angreifern verursachte Anfragen, sollten blockiert werden. Aber wir laufen immer noch mit einer Anomalie von 1'000. Wir müssen das auf ein vernünftiges Niveau reduzieren. Mit einer Grenze, die höher als 30 oder 40 liegt, ist es unwahrscheinlich, etwas ernsthaft stoppen zu können. Mit einem Schwellenwert von 20 sehen wir einen ersten Effekt und bei einer Limite von 10 erhalten wir einen ziemlich guten Schutz vor Standard-Angreifern. Selbst wenn eine einzelne Regel nur 5 Punkte erzielt, verursachen einige Angriffsklassen wie etwa SQL-Injections meistens mehrere Alarme, so dass eine Grenze von 10 schon recht viele Angreifer abwehrt. In anderen Kategorien ist die Abdeckung mit Regeln weniger umfangreich. Das bedeutet, dass die Akkumulation mehrerer Regeln weniger stark wirkt. So ist es perfekt möglich, mit einem bestimmten Angriff unter 10 zu bleiben. Deshalb gibt erst eine Limite von 5 für eingehende Requests und 4 für abgehende Responses einen wirklich guten Schutz. Dies entspricht den Default Werten des CRS.

Aber wie können wir die Grenze von 1000 bis 5 senken, ohne die Produktion zu beeinträchtigen? Es braucht ein gewisses Vertrauen in die eigenen Tuning Fähigkeiten um diesen grossen Schritte zu schaffen. Besser ist es über mehrere Iterationen zu gehen: Eine erste Tuning-Runde wird mit einer Grenze von 1'000 durchgeführt. Wenn die eklatantesten Quellen von False Positives auf diese Weise eliminiert wurden, dann warten wir eine vorgegebene Zeitspanne und verringern dann die Grenze auf 50 und untersuchen die Protokolle erneut. Wir tunen und reduzieren später auf 30, dann 20, 10 und schliesslich 5. Nach jeder Reduktion muss man die neuen Log-Files überprüfen und das Statistik-Skript erneut ausführen. Ein Blick auf die Statistik erlaubt eine Aussage, was wir von einer Reduktion der Limiten erwarten können. Schauen wir uns die Statistik von vorher also nochmals genauer an:

```bash
INCOMING                     Num of req. | % of req. |  Sum of % | Missing %
Number of incoming req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. incoming score   |     41 |   0.4100% |   0.4100% |  99.5900%
Reqs with incoming score of   0 |   9920 |  99.2000% |  99.6100% |   0.3900%
Reqs with incoming score of   1 |      0 |   0.0000% |  99.6100% |   0.3900%
Reqs with incoming score of   2 |     11 |   0.1100% |  99.7200% |   0.2800%
Reqs with incoming score of   3 |     17 |   0.1699% |  99.8900% |   0.1100%
Reqs with incoming score of   4 |      0 |   0.0000% |  99.8900% |   0.1100%
Reqs with incoming score of   5 |      8 |   0.0800% |  99.9700% |   0.0300%
Reqs with incoming score of   6 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of   7 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of   8 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of   9 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  10 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  11 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  12 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  13 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  14 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  15 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  16 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  17 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  18 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  19 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  20 |      0 |   0.0000% |  99.9700% |   0.0300%
Reqs with incoming score of  21 |      1 |   0.0100% |  99.9800% |   0.0200%
Reqs with incoming score of  22 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  23 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  24 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  25 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  26 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  27 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  28 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  29 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  30 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  31 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  32 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  33 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  34 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  35 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  36 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  37 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  38 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  39 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  40 |      0 |   0.0000% |  99.9800% |   0.0200%
Reqs with incoming score of  41 |      2 |   0.0200% | 100.0000% |   0.0000%
```

10'000 Anfragen sind nicht wirklich ein grosses Logfile, aber es wird für unsere Zwecke reichen. Basierend auf den Daten können wir sofort entscheiden die Anomalie Limite auf 50 zu reduzieren. Es ist unwahrscheinlich, dass ein Request diese Limite erreicht. Und wenn er die Limite erreicht, dann dürfte es sich um einen sehr seltenen Fall handeln, der sehr rar ist und in der Produktion kaum eine massive Beeinträchtigung des Betriebes nach sich zieht.

Die Verringerung der Limite auf 30 wäre wahrscheinlich ein wenig übereifrig, da die Spalte auf der rechten Seite anzeigt, dass 0,02% der Anfragen mehr als 30 Punkte erzielten. Wir sollten die False Positives bei 41 behandeln, bevor wir die Grenze auf 30 reduzieren.

Mit diesen statistischen Daten zeichnet sich der Tuning-Prozess ab: Das iterative Behandeln von einzelnen Fehlalarmen mit Hilfe des *modsec-positive-stats.rb*-Skripts bringt Ordnung und Berechenbarkeit in den Tuning Prozess.

Für die ausgehenden Antworten ist die Situation ein bisschen einfacher, da wir kaum Werte höher als 5 sehen werden. Es gibt einfach nicht genug Regeln, um eine kumulative Wirkung zu haben. Wahrscheinlich weil es nicht viel gibt, was man an einer Antwort überprüfen könnte. Deshalb reduziere ich den Outgoing Anomaly Score jeweils rasch auf 5 oder 4 (was aus den Default Wert des CRS darstellt).

Ich denke, das Tuning-Konzept und die Theorie sind jetzt ganz klar. In der nächsten Anleitung werden wir mit Tuning der False Positives fortfahren und uns etwas Praxis mit den hier demonstrierten Techniken erarbeiten. Und ich werde auch ein Skript vorstellen, das dabei hilft, die komplizierteren Regel Ausschlüsse zu konstruieren.

### Schritt 10 (Goodie): Zusammenfassung der Wege zur Bekämpfung von Falschpositionen

Es ist vielleicht am besten, die Rule Exclusion Direktiven in einer Grafik zusammenzufassen: Hier ein Cheatsheet für den freien Gebrauch!

<a href="https://www.netnea.com/cms/rule-exclusion-cheatsheet-download/"><img src="https://www.netnea.com/files/tutorial-7-rule-exclusion-cheatsheet_small.png" alt="Rule Exclusion CheatSheet" width="476" height="673" /></a>




###Verweise
- [Spider Labs Blog Post: Exception
  Handling](http://blog.spiderlabs.com/2011/08/modsecurity-advanced-topic-of-the-week-exception-handling.html)
- [ModSecurity
  Referenzhandbuch](https://github.com/SpiderLabs/ModSecurity/wiki/Reference-Manual)

### Lizenz / Kopieren / Weiterverwenden

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png" /></a><br />Diese Arbeit ist wie folgt lizenziert / This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.


































