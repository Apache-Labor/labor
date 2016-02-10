##Title: Apache und ModSecurity Logfiles visualisieren

###Was machen wir?

Wir werten Logfiles visuell aus.

###Warum tun wir das?

In den vorangegangenen Lektionen haben wir das Apache Logformat angepasst und verschiedene statistische Auswertungen durchgeführt. Wir haben es bis anhin aber unterlassen, die gewonnenen Zahlen grafisch darzustellen. Tatsächlich bietet aber die Visualisierung von Daten eine grosse Hilfe beim Erkennen von Problemen. Namentlich Zeitreihen sind sehr aufschlussreich und auch Performance-Probleme lassen sich visuell viel besser quantifizieren und isolieren. Daneben bietet aber auch die graphische Darstellung von False-Positives interessante Aufschlüsse.

Der Wert von Visualisierung liegt auf der Hand und tatsächlich sind Graphen mit gutem Grund je länger je mehr ein wichtiger Bestandteil von Dashboards und regelmässigen Reports. In dieser Lektion zielen wir aber nicht auf die formvollendeten Graphen ab, sondern kümmern uns darum, wie wir mit möglichst einfachen Mitteln zu aussagekräftigen Graphen kommen.

Zu diesem Zweck bedienen wir uns einem wenig bekannten Feature von Gnuplot und füllen ModSecurity Alerts in die Graphviz.

###Schritt 1 : Graphische Darstellung von Zeitreihen in der Shell

Das Aufkommen von Einträgen in Logfiles folgt einem zeitlichen Verlauf. Tatsächlich ist es aber relativ schwierig diesem zeitlichen Verlauf im Textfile selbst zu folgen. Eine Visualisierung des Logfiles schafft Abhilfe. Dashboards wurden schon erwähnt und verschiedene kommerzielle Produkte und Open Source Projekte haben sich in den letzten Jahren etabliert. Diese Werkzeuge sind sehr sinnvoll. Oft sind sie aber nicht einfach zugänglich oder verfügen nicht über die richtigen Daten, die wir eigentlich darstellen möchten. Eine grosse Lücke ist deshalb die Darstellung von Graphen in der Shell. Tatsächlich beherrscht das graphiche Werkzeug gnuplot auch ASCII und kann komplett von der Kommandozeile aus gesteuert werden.

Gnuplot ist in der Bedienung und Steuerung anspruchsvoll und wer nur gelegentlich damit arbeitet hat eine wiederkehrende Lernkurve vor sich. Aus diesem Grund habe ich ein Wrapper-Skript namens arbigraph entwickelt, das einfache Graphen mit Hilfe von Gnuplot darstellen kann. Für eine weitere Bearbeitung im eigentlichen Gnuplot-Tool werden die von arbigraph angewendeten Steuerungsbefehle ausgegeben. FIXME Link Arbigraph

Erzeugen wir also einen einfachen Graphen, welcher die Anzahl der Requests pro Stunde aus einem einem Logfile herauszieht und in einem zeitlichen Verlauf darstellt. Wir ziehen dazu das Access-Log heran, das wir beim Tunen von ModSecurity False Positives in einer vorangegangenen Anleitung bereits kennengelernt haben. FIXME Link

Konzentrieren wir uns auf die Einträge vom 20. bis 29. Mai und extrahieren wir daraus die Timestamps:

```bash
$> grep 2015-05-2 labor-07-example-access.log | altimestamp | head
2015-05-20 12:53:11.139981
2015-05-20 12:53:12.232266
2015-05-20 12:54:57.772135
2015-05-20 12:54:58.842986
2015-05-20 12:54:59.009303
2015-05-20 12:54:59.003103
2015-05-20 12:54:59.006098
2015-05-20 12:54:58.992113
2015-05-20 12:54:58.994096
2015-05-20 12:55:00.270296
```

Die Aufsummierung pro Stunde geht einfach, indem wir den Zeitstempel beim Doppelpunkt schneiden und mittels `uniq` auszählen. Sicherheitshalber bauen wir noch ein `sort` ein, denn Logfiles sind nicht in jedem Fall chronologisch (Der Eintrag folgt beim Abschluss des Requests, der Zeitstempel bezeichnet aber den Eingang der Request-Zeile der Anfrage. Das bedeutet, dass ein "langsamer" Request von 12:59 im Logfile nach einem "raschen" Request von 13:00 zu stehen kommen kann).

```bash
$> grep 2015-05-2 labor-07-example-access.log | altimestamp | cut -f: -f1 | sort | uniq -c | head
     37 2015-05-20 12
      6 2015-05-20 13
      1 2015-05-20 14
    105 2015-05-20 15
     38 2015-05-20 16
     25 2015-05-20 17
     19 2015-05-20 18
     32 2015-05-20 19
     19 2015-05-20 22
      1 2015-05-21 06
```

Das scheint zu funktionieren, obschon sich im Logfile auch Lücken ausmachen lassen. Um diese werden wir uns später kümmern. In der ersten Spalte sehen wir nun die Requests pro Stunde, während die zweite und dritte Spalte den Zeitpunkt, die Stunde eben, beschreibt. Das Resultat füttern wir dann in das angesprochene Skript `arbigraph`, das von sich aus bei der Darstellung nur die erste Spalte berücksichtigt:

```bash
$> grep 2015-05-2 labor-07-example-access.log | altimestamp | cut -f: -f1 | sort | uniq -c | arbigraph

  250 ++-----------------+-------------------+-------------------+-------------------+-------------------+-------------------++
      |                  +                   +                   +                   +                   +       Col 1 ******+|
      |                                                            **                                                         |
      |                                                            **                                                         |
      |                                                            **                                                         |
  200 ++                                                           **                              **                        ++
      |                                                            **                              **    **                   |
      |                                                            **                              **    **                   |
      |                                                           ***                              **    **       ** **       |
      |                                                           ***                              **    **       ** **       |
  150 ++                        **                                ***            **                ** *****       ** ** **   ++
      |                 **      **                                ***            **                ** *******     ***** **    |
      |                 **      **                                ***            **   **           ** *******     ***** **    |
      |           **    **     ***                                ***            **   **           ** *******     ***** **    |
      |          ***    **     ***                                ***           ***   **  **       ** *******     ***** **    |
  100 ++ **      ***    **     ***                                ***           ***** **  **       ** *******     ***** ***  ++
      |  **      ***    **     ***        **                     ****           ***** **  **       ** *******     *********   |
      |  **     ****   ***     ***        **                     *****          ***** **  **       ** *******     *********   |
      |  **     *****  ***     ***  ***   ** **                  *****          ********  **       **********   ***********   |
      |  **     *****  ***     ***  ***   ** ****                *****          ******** ***       **********   ***********   |
   50 ++ **     **********   ****** ***   *******                *****          ************       **********   ***********  ++
      ** ***    **********   ****** ***   ******* **             *****  **   ** ************       **********   ***********   |
      ** *** ** **********   **********   ******* **        **   *****  ***  ** **************     ************ ************  |
      ** *****************   ********** ********* ****      ** ************* ** **************   **************************** |
      *********************  **************************    *** ********************************  ******************************
    0 *************************************************************************************************************************
                         20                  40                  60                  80                 100                 120
```

Wir sehen in dieser rudimentären graphischen Darstellung die Zahl der Anfragen auf der Y-Achse. Auf der X-Achse sehen wir den Zeitverlauf. 
Die Lastspitze liegt bei gegen 250 Requests pro Stunde, was natürlich sehr wenig Verkehr ist. Generell sehen wir ein starkes Auf und Ab des Verkehrsaufkommense. Oben rechts sehen wir die Legende, welche die Sterne per Default als `Col 1` beschreibt.
Als gravierender Nachteil erweist sich die untaugliche Beschriftung auf der X-Achse, denn tatsächlich bezeichnen die Zahlen von 20-120
lediglich die Zeilennummer des Wertes auf der Y-Achse.

Da wir bei der Datenbasis ja Lücken im Datenset haben, können wir innerhalb des Graphen von der Zeilenzahl und mithin von der X-Achse nicht mehr
auf den Zeitpunkt eines Wertes zurückschliessen. Zunächst müssen wir diese Lücken schliessen.

###Schritt 4 : Füllen der Lücken

Anstatt dass wir die Datums- und Stundenfolge aus dem Logfile ableiten bauen wir sie selbst auf und suchen zu jeder Datums-Stunden-Kombination die Anzahl der Anfragen im Logfile. Das repetitive `grep` auf demselben Logfile ist dabei etwas ineffizient, aber für die vorliegende Grösse des Logfiles durchaus tauglich.


```bash

$> for DAY in {20..29}; do for HOUR in {00..23}; do echo "2015-05-$DAY $HOUR"; done; done 
2015-05-20 00
2015-05-20 01
2015-05-20 02
2015-05-20 03
2015-05-20 04
2015-05-20 05
2015-05-20 06
2015-05-20 07
2015-05-20 08
2015-05-20 09
2015-05-20 10
...

for DAY in {20..29}; do for HOUR in {00..23}; do echo "2015-05-$DAY $HOUR"; done; done | while read STRING; do echo -n "$STRING "; grep -c "$STRING" labor-07-example-access.log; done
2015-05-20 00 0
2015-05-20 01 0
2015-05-20 02 0
2015-05-20 03 0
2015-05-20 04 0
2015-05-20 05 0
2015-05-20 06 0
2015-05-20 07 0
2015-05-20 08 0
2015-05-20 09 0
2015-05-20 10 0
2015-05-20 11 0
2015-05-20 12 37
2015-05-20 13 6
2015-05-20 14 1
2015-05-20 15 105
...
```
Wir lesen also den kombinierte Datum-Stunden-String in eine While-Schleife ein. Dann geben wir ihn mittels `echo` aus und vermeiden mittels `-n` den Zeilenumbruch. `grep -c` sucht dann im Logfile nach dem String und retourniert die gezählten die Fundstellen. Damit erhalten wir dasselbe Resultat wie im vorigen Beispiele, allerdings sind die Lücken nun gefüllt und die Reihenfolge der Spaltung hat sich verändert. Der Vorteil bei der Umkehr der Spaltenreihenfolge ist, dass wir uns nicht mehr um das Abschneiden des Datum FIXMEFüllen wir diese Ausgabe in unser Graphen-Skript:


```bash
$> for DAY in {20..29}; do for HOUR in {00..23}; do echo "2015-05-$DAY $HOUR"; done; done | while read STRING; do echo "`grep -c \"$STRING\" labor-07-example-access.log` $STRING"; done | arbigraph



  250 ++-----------------------+------------------------+------------------------+------------------------+------------------++
      |                        +                        +                        +                        +      Col 1 ****** |
      |                                                                            *                                          |
      |                                                                            *                                          |
      |                                                                            *                                          |
  200 ++                                                                           *                     **                  ++
      |                                                                            *                     ** **                |
      |                                                                            *                     ** **                |
      |                                                                           **                     ** **        ***     |
      |                                                                           **                     ** **        ***     |
  150 ++                           *                                              **          *          *****        *****  ++
      |                  **        *                                              **          *          ******       *****   |
      |                  **        *                                              **          * **       ******       *****   |
      |               ** **       **                                              **          * **       ******       *****   |
      |               ** **       **                                              **         ** ****     ******       *****   |
  100 ++     **       ** **       **                                              **         *******     ******       *****  ++
      |      **       ** **       **         **                                   **         *******     ******       *****   |
      |      **      *** **       **         **                                   ***        *******     ******       *****   |
      |      **      *** **       ** **      ***                                  ***        *******     ******      ******   |
      |      **      *** **       ** **      ****                                 ***        *******     ******      ******   |
   50 ++     **      ******      ******      ****                                 ***        *******     ******      ******  ++
      |     ***      ******      ******      **** *                               ***** **   *******     ******      ******   |
      |     *****    ******      ******      **** *                       **      ***** **   ********    *******     *******  |
      |     ******   ******      *********   **** * **                    **     *********   ********  * ********    ******** |
      |     ******   ******    + *********   *********  +                 **     *********   ********  * ********    *********|
    0 ++----******---*********-+-*********---*********--+--*--**-----**-*-***----**********--***********-********----*********+
                               50                      100                      150                      200

```

Nun erscheint eine gewisse Regelmässigkeit. Je 24 Werte machen einen ganzen Tag aus. Mit diesem Wissen sehen wir den Tagsrhythmus, können Samstag und Sonntag vermuten und sehen eventuell sogar eine gewisse Mittagspause angedeutet.


###Schritt 2 : X-Axis Label

FIXME


###Schritt 2 : Weitere Label

`Arbigraph` bietet einige Einflussmöglichkeiten auf den Graphen. Schauen wir uns die Optionen mal an:

```bash
$> arbigraph -h

<STDIN> | arbigraph [OPTIONS] 

A script to plot a simple graph

 -c  --columnnames STR     Name for columns. Seperate by ';'.
 -C  --custom STR          Custom arbitrary gnuplot directives; will be placed right
                           before the plot directive. Separate commands with semicolon.
 -d  --dots                Graph with dots instead of blocks
 -h  --help                This text
 -H  --height  STR         Graph height in characters
 -l  --lines               Graph with lines instead of blocks
     --label               Additional text inside the graph. Default positioned top left
 -L  --logscale            Logarithmic scale. Default is normale scale.
 -m  --minx STR            Starting value of x-axis. Default is 1
 -n  --noscript            Do not output the script below the graph
 -o  --output STR          Write graph into a file (png)
 -s  --sameaxis            Use the same y-axis. Default is seperate axis
 -t  --title STR           Title of graph
 -w  --width STR           Width of graph (terminal actually). Default is terminal width
 -2                        Usa an additional, second data column

Example: 
 ls -l /tmp | head -15 | grep -v total | awk '{ print $5 " " $9 } ' | arbigraph

Arbigraph will graph the first column. Subsequent columns are ignored.
The X-axis is actually the line number of a value.
Command line option "minx" therefore defines the
starting point of the line numbering.

If you work with --label, you can reposition it to the right by adding "(right)"
inside the label text. This will not be printed. You can use \n to get a CR.

```

Die gesuchte Option ist `--columnnames` und zusätzlich vielleicht noch `--title`. Um eine andere Darstellung auszuprobieren bietet es sich an, mit `--lines` zu arbeiten:


```bash
$> for DAY in {20..29}; do for HOUR in {00..23}; do echo "2015-05-$DAY $HOUR"; done; done | while read STRING; do echo "`grep -c \"$STRING\" labor-07-example-access.log` $STRING"; done | arbigraph --lines --columnnames "Num of Reqs/h" --title "Daily Rhythm of Requests in labor-07-example-access.log"


                                       Daily Rhythm of Requests in labor-07-example-access.log

  250 ++-----------------------+------------------------+------------------------+------------------------+------------------++
      |                        +                        +                        +                       Num of Reqs/h ****** |
      |                                                                            *                                          |
      |                                                                            *                                          |
      |                                                                            *                                          |
  200 ++                                                                           *                      *                  ++
      |                                                                            *                      *  *                |
      |                                                                            *                      *  *         **     |
      |                                                                            *                      *  *         **     |
      |                            *                                               *          *           * **         **     |
  150 ++                           *                                               **         *           ****         ** *  ++
      |                   *        *                                               **         *  *        *** *        ****   |
      |                   *        *                                              * *         *  *        *** *        ****   |
      |                *  *        *                                              * *         *  *        **  *       *  **   |
      |       *       ** **        **                                             * *         ** * *     ***  *       *  **   |
  100 ++      *       ** **        **         *                                   * *         **** *     ***  *       *  **  ++
      |       *       ** **        **         *                                   * *         **** *     ***  *       *  **   |
      |       *       ** **       * **        *                                   * *         ******     ***  *       *  **   |
      |       *       ** **       * ***       **                                  * *         ******     ***  *       *  * *  |
   50 ++      *       * ***       * ***       ***                                 * *        * * ***     * *  *       *  * * ++
      |     ***       * ***       * ***      * ** *                               * *    *   *   ***     * *  *       *  * *  |
      |     ** **    *   **       * ***      * ** *                        *      * * *  *   *    ***    * *  **     *   * *  |
      |     ** ***   *   **       *   * **   *   *** *                     *     ** ** * *   *    ***  * *    ***    *   * ** |
      |     **  ***  *   **    + *    ****   *   *** *  +                 **     **    ***   *    ***  ***+    **    *     ***|
    0 ********--******-----*******-----*******---*-**-****************************-----**-****-------*****+-----******-----****
                               50                      100                      150                      200

```

###Schritt 5 : Weitere Varianten dieses Graphes

Der Graph lässt sich noch etwas erweitern. Wir können etwa die Zahl der POST-Requests und GET-Requests parallel darstellen. Der Übersichtlichkeit halber verwenden wir nun die kurzen Options-Namen beim Aufruf von `arbigraph`:

```bash
$> for DAY in {20..29}; do for HOUR in {00..23}; do echo "2015-05-$DAY $HOUR"; done; done | while read STRING; do echo "`grep  \"$STRING\" labor-07-example-access.log | grep -c POST` `grep  \"$STRING\" labor-07-example-access.log | grep -c GET`  $STRING" ; done | arbigraph -l -2 -c "Num of POST Reqs/h;Num of GET Reqs/h"

     +----------------------+-----------------------+-----------------------+-----------------------+-------------------+
     |                      +                       +                       +                 Num of POST Reqs/h ****** |
  20 ++                                                                        *               Num of GET Reqs/h ######++
     |                                                                         *                       *               ++ 200
     |                                                                         *                    #  *                |
     |                                                                         *              *     #  *                |
     |                                                                        #*              *     #  *                |
     |                                                                        **              *     #  *         *#     |
  15 ++                          *                                            **              *     #  **        *#    ++
     |                           *                                            **         #    *     #  **        *# #  ++ 150
     |                           *                                            **         # *  *     # #**        *# #   |
     |                  #        *                                            **         # *  *     ###**        *###   |
     |      *           #       **                                            **         # *# *     ###**        * ##   |
     |      *        #  #       **                                            **         #**# *     ###**        * ##   |
  10 ++     *       *# ##       **          *                                 **         #*** *     ###**       ** #*  ++ 100
     |      *       *# ##       **          *                                 **         ******     #*#**       ** #*   |
     |      *       ** ##       **         **                                 **         ******     #****       * *#*   |
     |      **      ** ##       **         **                                 **         ******     *****#      * *#*   |
     |      **      ** #*       ***#       **                                 **         ******     ***  *      * *#*#  |
   5 ++     **      **#**       ***#       *** *                              **         ******     ***  *      * *#** ++
     |      **      **#**      #***#       *** *                             #*#**  #   #**#***     ***  *      *  *** ++ 50
     |     #**     *#*#**      *# * #     **** *                             #* **# #   *   ***     ***  *      *  * *  |
     |     #**#    * ****      *  **#     ****#**                      #     #* **# ##  *    ***    ***  *     #*  * *  |
     |     #*** #  * ****      *  ***##   ** *#** #                    #     *  **# ##  *    ***  # **   **    #*  * *# |
     |    #*** **  *   *#*  +  *    ***#  **  *** * +      *          #*    +*  ** #**  *    ***  * **   ***   #*    **#|
   0 ******-*--*****-----*******-----******---*-******************************----*******----*--****+------*****-----**** 0
                            50                     100                     150                     200

```

Mittels der Option `-2` teilen wir `arbigraph` mit, dass zwei Datenkolonnen vorhanden sind. `columnnames` lässt sich mittels Strichpunkt unterteilen. Als verwirrend erweist sich nun noch die Y-Achse. Die linke Y-Achse gilt den POST-Anfragen. Die rechte Y-Achse bedient die GET-Requests. Das macht den Graphen eher schlecht lesbar. Abhilfe findet sich in der Option `--sameaxis` welche zu einer Vereinheitlichung der Y-Achse führt.


```bash
$> for DAY in {20..29}; do for HOUR in {00..23}; do echo "2015-05-$DAY $HOUR"; done; done | while read STRING; do echo "`grep  \"$STRING\" labor-07-example-access.log | grep -c POST` `grep  \"$STRING\" labor-07-example-access.log | grep -c GET`  $STRING" ; done | arbigraph -l -2 -c "Num of POST Reqs/h;Num of GET Reqs/h" --sameaxis


      +----------------------+-----------------------+-----------------------+-----------------------+------------------+
      |                      +                       +                       +                Num of POST Reqs/h ****** |
      |                                                                        #               Num of GET Reqs/h ###### |
  200 ++                                                                       #                                       ++ 200
      |                                                                        #                     #                  |
      |                                                                        #                     #                  |
      |                                                                        #                     # #                |
      |                                                                        #                     # #          #     |
      |                                                                        #                     # ##        ##     |
  150 ++                                                                       #          #          # ##        ## #  ++ 150
      |                           #                                            ##         #          ####        ## #   |
      |                  #        #                                            ##         #          ####        ####   |
      |                  #       ##                                           # #        ## #        ## #        # ##   |
      |               #  #       ##                                           # #        ## #        ## #        # ##   |
  100 ++             ## ##       ##                                           # #        ## #       ### #       #  ##  ++ 100
      |      #       ## ##       ##                                           # #        #### #     ### #       #  ##   |
      |      #       ## ##       ##         #                                 # #        #### #     ### #       #  ##   |
      |      #       ## ##       ##         #                                 # #        #### #     ##   #      #  ##   |
      |      ##      ## ##       ####       #                                 # #        ######     ##   #      #  # #  |
      |      ##      # ###       ####       ###                               # #        ######     ##   #      #  # #  |
   50 ++     ##      # ###      #####       ###                               # #   #    ######     ##   #      #  # # ++ 50
      |     ###      # ###      ## ##      #### #                             # # # #    #  ###     ##   #      #  # #  |
      |     ####    #   ##      #  ##      ## # #                      #      # # # ##   #   ###    ##   #     #   # #  |
      |     ## ##   #   ##      # * # ##   #  ### #                    #     ##*### ##   #   #*#  # #  * ##    # * # ## |
      |    ##*  ##  #** **   +  #*** ###   #**##* ## +                 ##    #***  ###   ****#*#  ###**** ##   # ** *###|
    0 ***************-***********-*********************************************-***********--**********--********--*-**** 0
                             50                     100                     150                     200

```

Damit wird es schon viel lesbarer. Wir sehen nun, wie selten die POST Requests im Vergleich zu den GET Requests tatsächlich sind.
In der grafischen Darstellung sind es nur noch keine Hügel entlang der X-Achse. Wir können die Hügel etwas erhöhen indem
wir eine logarithmische Y-Skala verwenden:


```bash

>for DAY in {20..29}; do for HOUR in {00..23}; do echo "2015-05-$DAY $HOUR"; done; done | while read STRING; do echo "`grep  \"$STRING\" labor-07-example-access.log | grep -c GET` `grep  \"$STRING\" labor-07-example-access.log | grep -c POST`  $STRING" ; done | arbigraph -l -2 -c "Num of GET Reqs/h;Num of POST Reqs/h" --sameaxis --logscale



      +----------------------+-----------------------+-----------------------+-*---------------------+------------------+
      +                      +                       +                       + *               Num of GET Reqs/h ****** +
      |                           *                                            *          *   Num of POST Reqs/h **#*## |
      |               *  *        *                                            **         * *        ** *        ****   |
  100 ++     *       **  *       **         *                                 * *        **** *      ** *        * **  ++ 100
      +      *       ** **       **         *                                 * *        **** *      ** *       *  **   +
      +      *       ** **       ****       *                                 * *        ******      *  *       *  **   +
      +      **      * ***       ****       ***                               * *        ******     **   *      *  ***  +
      +      **      * ***      *****       *** *                             * *   *    *  ***     **   *      *  * *  +
      +     ****     * ***      *  **       * * *                             * * * *    *  ****    **   *      *  * *  +
      |     ****     * ***      *  **       * * *                      *      * * * *    *  ****    *    *      *  * *  |
      +     ** *     *  **      *   *  *    * * * *                    *     **#*** *    *   ***    *  # *      *  * *  +
      |     ** **    *  **      *   *  *    * * * *                    *     **# ** **   *   ***  * *  # **     *# * ** |
      |     ** **    *  **      * # * **    * *** **                   *     **## * **   * # ***  * *  ## *     *#   ** |
   10 ++    ** **    *  **      *## * **    *#*** **                   *     * ## * **   * ##***  * *  ## *     *#  #***+ 10
      +     ** **    *# **      *##  ***    *#*** **                   *     * ## ****   *### #*  * *#### *     *#  #***+
      +     ** **   *##  *      *##  ***    *#*** **                   *     * ## ****   *### #*  * *#### *     * # #***+
      +     **#**   *##  *      *### ***    *#*** **                   *     *# # ****   *# # #*  * *#### *     * # #***+
      +     **#**   *## #*      *### ***    *#*** **                   *     *# #  ***   *# ###*  * *## # *     *  ##***+
      +     **#**   *## #*      *### ***    *#*** **        *          *     *# ## ***   *# ###*  * *## # *     *  ##***+
      +     **#**   *####* *    *  ##***    *#*** **        *          *     *# ## ***   *  ###*  * *##  #*     *  # ***+
      |     **#**   *####* *    *  ##***    *#*** **        *          *     *# ## ***   *  ####* * *#   #*     *  # ***|
      +     **#**   *####* *    *  ##***    *#*** **        *          * *   *# ###***   *  ####* * *#   #*     *  # ***+
      |     **#**   *#  #* *    *   #***    * *** **        *          * *   *# ###***   *  ####* * *#   #*     *    ***|
      |     **#**   *#  #* * +  *   #***    * *** ** +      *          ***   *# ###***   *  ####*** *#   #*     *    ***|
    1 ++----**#**---*#--#*-*-+--*---#***----*-***-**-+--*---*-----**-*-***---*#-###****--*--####***-*#---#*-----*----***+ 1
                             50                     100                     150                     200

```

Damit ist die Grenze der Fähigkeiten von `arbigraph` erreicht. Für `gnuplot` selbst ist damit noch lange nicht Ende der Fahnenstange, aber das Wrapperskript haben wir ausgeschöpft. Den Sprung von `arbigraph`  Für alles andere müssen wir direkt auf `gnuplot` zurückgreifen. Dabei hilft eine weitere Option von `arbigraph` welche die Gnuplot-Kommandos ausgibt. Diese können wir dann leicht in ein Skript überführen und per STDIN an `gnuplot` übergeben. FIXME



```bash
```


###Schritt 6 : Graphische Darstellung einer Werte-Verteilung in der Shell

###Schritt 7 : Logarithmische Skala

###Schritt 8 : Ausgabe als PNG

FIXME: arbigraph -h

###Bonus: Visualisierung von ModSecurity Rule Alerts


###Voraussetzungen

* Ein Apache Webserver, idealerweise mit einem File-Layout wie bei [Anleitung 1 (Kompilieren eines Apache Servers)](https://www.netnea.com/cms/apache_tutorial_1_apache_compilieren/)
* Verständnis der minimalen Konfiguration in [Anleitung 2 (Apache minimal konfigurieren)](https://www.netnea.com/cms/apache_tutorial_2_apache_minimal_konfigurieren/)
* Ein Apache Webserver mit SSL-/TLS-Unterstützung wie in [Anleitung 4 (Konfigurieren eines SSL Servers)](https://www.netnea.com/cms/apache-tutorial-4-ssl-server-konfigurieren)
* Ein Apache Webserver mit erweitertem Zugriffslog wie in [Anleitung 5 (Das Zugriffslog Ausbauen und Auswerten)](https://www.netnea.com/cms/apache-tutorial-5-zugriffslog-ausbauen/)
* Ein Apache Webserver mit ModSecurity wie in [Anleitung 6 (ModSecurity einbinden)](https://www.netnea.com/cms/apache-tutorial-6-modsecurity-einbinden/)
* Ein Apache Webserver mit einer Core Rules Installation wie in [Anleitung 7 (Core Rules einbinden)](http://www.netnea.com/cms/modsecurity-core-rules-einbinden/)



###Verweise

* [gnuplot](http://www.gnuplot.info)
* [graphviz](http://www.graphviz.org)
* [do-binning.rb](https://github.com/Apache-Labor/labor/blob/master/bin/do-binning.rb)
* [arbigraph](https://github.com/Apache-Labor/labor/blob/master/bin/arbigraph)

### Lizenz / Kopieren / Weiterverwenden

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png" /></a><br />Diese Arbeit ist wie folgt lizenziert / This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.

