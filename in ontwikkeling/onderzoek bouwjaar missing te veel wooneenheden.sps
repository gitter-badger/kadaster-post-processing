* Encoding: windows-1252.
* OPGELET: er is een harde compute period=2019 nodig vlak voor het aggregeren naar swing.

GET
  FILE='C:\temp\kadaster\werkbestanden\eigendom_2018.sav'.
DATASET NAME eigendommen2018 WINDOW=FRONT.

DATASET ACTIVATE eigendommen2018.
DATASET DECLARE ag18.
AGGREGATE
  /OUTFILE='ag18'
  /BREAK=jaartal inkomen bewoonbaar aard bewoner_code bouwjaar laatste_wijziging soort_bebouwing 
    subtype_woning wooneenheden huidig_bewoond
  /KI_mean=MEAN(KI) 
  /oppervlakte_mean=MEAN(oppervlakte)
  /aant_eig=N.

GET
  FILE='C:\temp\kadaster\werkbestanden\eigendom_2019.sav'.
DATASET NAME eigendommen2019 WINDOW=FRONT.

DATASET ACTIVATE eigendommen2019.
DATASET DECLARE ag19.
AGGREGATE
  /OUTFILE='ag19'
  /BREAK=jaartal inkomen bewoonbaar aard bewoner_code bouwjaar laatste_wijziging soort_bebouwing 
    subtype_woning wooneenheden huidig_bewoond
  /KI_mean=MEAN(KI) 
  /oppervlakte_mean=MEAN(oppervlakte)
  /aant_eig=N.

DATASET ACTIVATE ag18.
ADD FILES /FILE=*
  /FILE='ag19'.
EXECUTE.

dataset close ag19.
dataset name eigendommen.

compute totale_bewoning=huidig_bewoond*aant_eig.
recode wooneenheden (missing=0) (0=0) (1 thru highest =1) into wooneenheden_dummy.
recode bewoonbaar ("J"=1) ("N"=0) into bewoonbaar_num.
value labels wooneenheden_dummy
0 "zonder wooneenheden"
1 "met wooneenheden".
value labels bewoonbaar_num
0 "niet bewoonbaar"
1 "bewoonbaar".

string aard_bewoonbaar (a100).
do if bewoonbaar_num=1.
recode aard (else=copy) into aard_bewoonbaar.
end if.

* maak een dummy "bewoond of niet" op basis van  huidig_bewoond.
recode huidig_bewoond (1 thru highest=1) (else=0) into bewoond.
value labels bewoond
0 "geen huidige bewoning"
1 "wel huidige bewoning".


* woonfunctie
** recode op aard op basis van ons wordbestand.
** in de toekomst is dit gewoon een dummy aangeleverd door Cevi.
*** opmerking: privat.delen# komt niet voor in de data.
recode aard
('APPARTEMENT #'=1)
('BUILDING'=1)
('D.AP.GEB.#W'=1)
('HANDELSHUIS'=1)
('HOEVE'=1)
('HUIS'=1)
('HUIS#'=1)
('KAMER #   '=1)
('PRIVAT. DELEN'=1)
('KASTEEL'=1)
('KLOOSTER'=1)
('PRIVAT. DELEN#'=1)
('NOODWONING'=1)
('PASTORIE'=1)
('RUSTHUIS'=1)
('STUDIO #'=1)
('WEESHUIS'=1)
('WELZIJNSGEBOUW'=1)
(else=0) into woonfunctie.
value labels woonfunctie
0 "geen woonfunctie"
1 "wel een woonfunctie".

* in 2019 duiken opeens een heel aantal "appartementen" op die duidelijk geen woning zijn.
* het is niet helemaal duidelijk wat hier dan wel de functie van is, maar we nemen ze alvast niet mee als dingen met een "woonfunctie".
* in 2018 is dit nog zeer zeldzaam, maar we nemen het toch al mee omwille van de consistentie.
if aard = "APPARTEMENT #" & subtype_woning="" woonfunctie=0.

* woongelegenheden.
** indien woonfunctie=1
*** grootste van huishoudens en wooneenheden.
*** woonfunctie=1 & wooneenheden=0 >>> woongelegenheid=1 (indien we niet al een grotere waarde hebben ingevuld!).
** indien woonfunctie=0 
*** tel aantal huishoudens

compute woongelegenheden=$sysmis.
if woonfunctie=1 woongelegenheden=aant_eig*max(wooneenheden,huidig_bewoond).
if woonfunctie=1 & (missing(wooneenheden) | wooneenheden=0) & (missing(huidig_bewoond) | huidig_bewoond=0) woongelegenheden=1*aant_eig.
if (missing(woongelegenheden) | woongelegenheden=0) & woonfunctie=1 woongelegenheden=1*aant_eig.
if woonfunctie=0  woongelegenheden=huidig_bewoond*aant_eig.


compute woongelegenheden_bis=$sysmis.
if woonfunctie=1 woongelegenheden_bis=max(wooneenheden,huidig_bewoond)*aant_eig.
if woonfunctie=0  woongelegenheden_bis=huidig_bewoond*aant_eig.



* woonvoorraad = woongelegenheden.
compute v2210_woonvoorraad=woongelegenheden.

* woonaanbod = woongelegenheden waarbij woonfunctie=1.
if woonfunctie=1 v2210_woonaanbod=woongelegenheden.


* type woongelegenheden
** woonaanbodsindeling (dus woonfunctie=1, maar dit hoeven we niet te expliciteren aangezien alle gebruikte aarden woonfunctie hebben)
** teller=woongelegenheden.
recode aard
('APPARTEMENT #'=2)
('BUILDING'=2)
('D.AP.GEB.#W'=2)
('HANDELSHUIS'=1)
('HOEVE'=1)
('HUIS'=1)
('HUIS#'=1)
('KAMER #   '=2)
('KASTEEL'=1)
('KLOOSTER'=3)
('NOODWONING'=1)
('PASTORIE'=1)
('PRIVAT. DELEN'=2)
('RUSTHUIS'=3)
('STUDIO #'=2)
('WEESHUIS'=3)
('WELZIJNSGEBOUW'=3) into v2210_type_woonaanbod.
value labels v2210_type_woonaanbod
1 "individuele woning"
2 "appartement"
3 "collectieve woning".

if v2210_type_woonaanbod=1 v2210_wa_indiv=woongelegenheden.
if v2210_type_woonaanbod=2 v2210_wa_app=woongelegenheden.
if v2210_type_woonaanbod=3 v2210_wa_coll=woongelegenheden.




****** start bouwjaar.
*** data-cleaning.
compute bouwjaar_clean=bouwjaar.
compute laatste_wijziging_clean=laatste_wijziging.
* gebouwen die in de toekomst (of in het huidige jaar) werden gebouwd beschouwen we als "bouwjaar onbekend".
if bouwjaar>=jaartal bouwjaar_clean = -1.
* gebouwen die werden gerenoveerd in de toekomst  (of in het huidige jaar) werden gebouwd beschouwen we als "wijziging onbekend".
if laatste_wijziging>=jaartal laatste_wijziging_clean = -1.
* gebouwen die pas werden gebouwd nadat ze werden gerenoveerd beschouwen we als fout wijzigingsjaar .
if ( laatste_wijziging<bouwjaar & bouwjaar>=0 & laatste_wijziging>0 ) laatste_wijziging_clean = -1.

* als het bouwjaar groter is dan 5 en kleiner dan 1931, dan is het fout.
if bouwjaar>5 & bouwjaar<1931 bouwjaar_clean=-1.

* als het wijzigingsjaar kleiner is dan 1983, dan is het wellicht een raar geval en nemen we het niet mee.
if laatste_wijziging>0 & laatste_wijziging<1983 laatste_wijziging_clean=-1.

missing values bouwjaar_clean laatste_wijziging_clean (-1).


* tussenstap/dummy code obv variabele 'bouwjaar' (naar gewenste categorieŽn).
* de categorie 'onbekend'  bevat alle missing values + wat we als onlogisch hebben gedefinieerd + de categorie '0000' (="verkoop op plan").
RECODE bouwjaar_clean 
(0=13)
(1=1) 
(2=1) 
(3=1) 
(4=2) 
(5=3) 
(1931 thru 1945=4) 
(1946 thru 1960=5) 
(1961 thru 1970=6) 
(1971 thru 1980=7) 
(1981 thru 1990=8) 
(1991 thru 2000=9) 
(2001 thru 2010=10) 
(2011 thru 2020=11) 
(2021 thru 2030=12) 
(ELSE=13) INTO bouwjaar_cat.

* dummy bouwjaar enkel van de woongelegenheden (obv variabele v2210_woonvoorraad).
* de categorie 'onbekend' (label value 12) bevat alle missing values + de categorie '0000' (="verkoop op plan") + elk jaartal vanaf 2019.
** deze code (value label) moet aangepast worden voor elke nieuwe dataset (laatste jaartal dat wordt meegenomen in de categorie 'na 2010').
compute bouwjaar_cat_wgl=$sysmis.
if v2210_woonvoorraad>=1 bouwjaar_cat_wgl=bouwjaar_cat.
value labels bouwjaar_cat bouwjaar_cat_wgl
1 "voor 1900"
2 "1900-1918"
3 "1919-1930"
4 "1931-1945"
5 "1946-1960"
6 "1961-1970"
7 "1971-1980"
8 "1981-1990"
9 "1991-2000"
10 "2001-2010"
11 "2011-2020"
12 '2021-2030'
13 "onbekend".


recode bouwjaar_cat (13=0) (else=1) into bouwjaar_gekend.

* indicatoren bouwjaar (enkel bij woongelegenheden, obv woonvoorraad).
* al deze indicatoren kunnen eenvoudig opgeteld worden.
if bouwjaar_cat_wgl=1 v2210_wv_bj_voor1900=woongelegenheden.
if bouwjaar_cat_wgl=2 v2210_wv_bj_1900_1918=woongelegenheden.
if bouwjaar_cat_wgl=3 v2210_wv_bj_1919_1930=woongelegenheden.
if bouwjaar_cat_wgl=4 v2210_wv_bj_1931_1945=woongelegenheden.
if bouwjaar_cat_wgl=5 v2210_wv_bj_1946_1960=woongelegenheden.
if bouwjaar_cat_wgl=6 v2210_wv_bj_1961_1970=woongelegenheden.
if bouwjaar_cat_wgl=7 v2210_wv_bj_1971_1980=woongelegenheden.
if bouwjaar_cat_wgl=8 v2210_wv_bj_1981_1990=woongelegenheden.
if bouwjaar_cat_wgl=9 v2210_wv_bj_1991_2000=woongelegenheden.
if bouwjaar_cat_wgl=10 v2210_wv_bj_2001_2010=woongelegenheden.
if bouwjaar_cat_wgl=11 v2210_wv_bj_2011_2020=woongelegenheden.
if bouwjaar_cat_wgl=13 v2210_wv_bj_onbekend=woongelegenheden. 

*tussenstap/dummy 'laatste wijzigingen' naar gewenste categorieŽn (met zelfde label values als bouwjaar_cat).
* de categorie 'onbekend' bevat alle missing values + alle jaartallen tem 1982 + elk jaartal "in de toekomst".
RECODE laatste_wijziging_clean 
(1983 thru 1990=8) 
(1991 thru 2000=9) 
(2001 thru 2010=10) 
(2011 thru 2020=11) 
(2021 thru 2030=12) 
(ELSE=13) INTO laatste_wijziging_cat.


* dummy laatste wijziging enkel van de woongelegenheden (obv variabele v2210_woonvoorraad).
* de categorie 'onbekend' (label value 12) bevat alle missing values + alle jaartallen tem 1982 + elk jaartal in de toekomst.
compute laatste_wijziging_cat_wgl=$sysmis.
if v2210_woonvoorraad>=1 laatste_wijziging_cat_wgl=laatste_wijziging_cat.
value labels laatste_wijziging_cat laatste_wijziging_cat_wgl
8 "1983-1990"
9 "1991-2000"
10 "2001-2010"
11 "2011-2020"
12 "2021-2030"
13 "onbekend".

* indicatoren laatste wijziging (enkel bij woongelegenheden, obv woonvoorraad).
* al deze indicatoren kunnen eenvoudig opgeteld worden.
if laatste_wijziging_cat_wgl=8 v2210_wv_lw_1983_1990=woongelegenheden.
if laatste_wijziging_cat_wgl=9 v2210_wv_lw_1991_2000=woongelegenheden.
if laatste_wijziging_cat_wgl=10 v2210_wv_lw_2001_2010=woongelegenheden.
if laatste_wijziging_cat_wgl=11 v2210_wv_lw_2011_2020=woongelegenheden.
if laatste_wijziging_cat_wgl=13 v2210_wv_lw_onbekend=woongelegenheden.


* we maken een combinatie van bouwjaar en wijzigingsjaar om een indicatie te krijgen van de "recentheid" van het woonpatrimonium.
* voor gebouwen gebouwd VOOR 1983 zonder wijzigingsjaar geldt:
- gebouwd voor 1983 en geen gekende wijziging
- bij een gebouw van uit 1900 kunnen we *geen* onderscheid maken tussen: gebouwd en nooit aangepast; of gebouwd en wie weet aangepast voor 1983
- voorlopig doen we daarom enkel "alle woongelegenheden die sinds 1983 gewijzigd of gebouwd zijn".

compute recentste_jaar=max(bouwjaar_clean,laatste_wijziging_clean).
if recentste_jaar>=1983 & recentste_jaar <= 1990 v2210_wgl_lwbj_1983_1990=woongelegenheden.
if recentste_jaar>=1991 & recentste_jaar <= 2000 v2210_wgl_lwbj_1991_2000=woongelegenheden.
if recentste_jaar>=2001 & recentste_jaar <= 2010 v2210_wgl_lwbj_2001_2010=woongelegenheden.
if recentste_jaar>=2011 & recentste_jaar <= 2020 v2210_wgl_lwbj_2011_2020=woongelegenheden.
*if recentste_jaar>=2021 & recentste_jaar <= 1990 v2210_wgl_lwbj_2021_2030=woongelegenheden.
if recentste_jaar>=1983 v2210_wgl_lwbj_1983p=woongelegenheden.


EXECUTE.
** einde bouwjaar.


* EINDE LUIK 2.

* LUIK3: toevoegen bewoning zonder link.
compute LUIK3=$sysmis.

PRESERVE.
 SET DECIMAL COMMA.

GET DATA  /TYPE=TXT
  /FILE="C:\temp\kadaster\2018\KAD_2018_bewoning_zonder_link.txt"
  /DELCASE=LINE
  /DELIMITERS="\t"
  /ARRANGEMENT=DELIMITED
  /FIRSTCASE=2
  /DATATYPEMIN PERCENTAGE=95.0
  /VARIABLES=
  provincie A4
  jaartal F4.0
  niscode A5
  adrescode A12
  straatnaamcode F6.0
  huisbis A12
  aantal_gezinnen F2.0
  /MAP.
RESTORE.

CACHE.
EXECUTE.
DATASET NAME bzl WINDOW=FRONT.

* komt zelfs in 2019 nog voor.
recode niscode ('12030'='12041')
('12034'='12041')
('44011'='44083')
('44049'='44083')
('44001'='44084')
('44029'='44084')
('44036'='44085')
('44072'='44085')
('44080'='44085')
('45017'='45068')
('45057'='45068')
('71047'='72042')
('72040'='72042')
('72025'='72043')
('72029'='72043').

string stat_sector (a9).
compute stat_sector = concat(niscode,"ZZZZ").
rename variables aantal_gezinnen = bewoning_zonder_link.
match files
/file=*
/keep=provincie
jaartal
niscode
bewoning_zonder_link
stat_sector.


DATASET ACTIVATE eigendommen.
ADD FILES /FILE=*
  /FILE='bzl'.
EXECUTE.
dataset close bzl.

compute v2210_hh_onbekend = bewoning_zonder_link.




* LUIK 4: aggregatie naar Swing.
compute LUIK4=$sysmis.
* platte onderwerpen.

*voorbereiding.
rename variables stat_sector=geoitem.

DATASET DECLARE aggr.
AGGREGATE
  /OUTFILE='aggr'
  /BREAK=geoitem
/v2210_woonvoorraad=sum(v2210_woonvoorraad)
/v2210_woonaanbod=sum(v2210_woonaanbod)
/v2210_wa_indiv=sum(v2210_wa_indiv)
/v2210_wa_app=sum(v2210_wa_app)
/v2210_wa_coll=sum(v2210_wa_coll)
/v2210_wv_eengezinswoningen=sum(v2210_wv_eengezinswoningen)
/v2210_wv_meergezinswoningen=sum(v2210_wv_meergezinswoningen)
/v2210_wv_mg_2_5=sum(v2210_wv_mg_2_5)
/v2210_wv_mg_6_10=sum(v2210_wv_mg_6_10)
/v2210_wv_mg_11p=sum(v2210_wv_mg_11p)
/v2210_huishoudens=sum(v2210_huishoudens)
/v2210_huurders=sum(v2210_huurders)
/v2210_inwonend_eigenaarsgezin=sum(v2210_inwonend_eigenaarsgezin)
/v2210_hh_onbekend=sum(v2210_hh_onbekend)
/v2210_wv_bj_voor1900=sum(v2210_wv_bj_voor1900)
/v2210_wv_bj_1900_1918=sum(v2210_wv_bj_1900_1918)
/v2210_wv_bj_1919_1930=sum(v2210_wv_bj_1919_1930)
/v2210_wv_bj_1931_1945=sum(v2210_wv_bj_1931_1945)
/v2210_wv_bj_1946_1960=sum(v2210_wv_bj_1946_1960)
/v2210_wv_bj_1961_1970=sum(v2210_wv_bj_1961_1970)
/v2210_wv_bj_1971_1980=sum(v2210_wv_bj_1971_1980)
/v2210_wv_bj_1981_1990=sum(v2210_wv_bj_1981_1990)
/v2210_wv_bj_1991_2000=sum(v2210_wv_bj_1991_2000)
/v2210_wv_bj_2001_2010=sum(v2210_wv_bj_2001_2010)
/v2210_wv_bj_2011_2020=sum(v2210_wv_bj_2011_2020)
/v2210_wv_bj_onbekend=sum(v2210_wv_bj_onbekend)
/v2210_wv_lw_1983_1990=sum(v2210_wv_lw_1983_1990)
/v2210_wv_lw_1991_2000=sum(v2210_wv_lw_1991_2000)
/v2210_wv_lw_2001_2010=sum(v2210_wv_lw_2001_2010)
/v2210_wv_lw_2011_2020=sum(v2210_wv_lw_2011_2020)
/v2210_wv_lw_onbekend=sum(v2210_wv_lw_onbekend)
/v2210_wgl_lwbj_1983_1990=sum(v2210_wgl_lwbj_1983_1990)
/v2210_wgl_lwbj_1991_2000=sum(v2210_wgl_lwbj_1991_2000)
/v2210_wgl_lwbj_2001_2010=sum(v2210_wgl_lwbj_2001_2010)
/v2210_wgl_lwbj_2011_2020=sum(v2210_wgl_lwbj_2011_2020)
/v2210_wgl_lwbj_1983p=sum(v2210_wgl_lwbj_1983p).


GET
  FILE='C:\github\gebiedsniveaus\verzamelbestanden\verwerkt_alle_gebiedsniveaus.sav'.
DATASET NAME allegebieden WINDOW=FRONT.

DATASET ACTIVATE allegebieden.
DATASET DECLARE uniekstatsec.
AGGREGATE
  /OUTFILE='uniekstatsec'
  /BREAK=statsec gewest
  /N_BREAK=N.
dataset activate uniekstatsec.
dataset close allegebieden.
delete variables N_BREAK.
rename variables statsec=geoitem.

DATASET ACTIVATE aggr.
MATCH FILES /FILE=*
  /FILE='uniekstatsec'
  /BY geoitem.
EXECUTE.
dataset close uniekstatsec.

* OPGELET: aanpassen - dit kan niet op basis van "jaartal" omdat dit missing is voor de lege sectoren.
compute period=2018.

string geolevel (a7).
compute geolevel="statsec".


* enkel voor het zicht.
alter type v2210_woonvoorraad
v2210_woonaanbod
v2210_wa_indiv
v2210_wa_app
v2210_wa_coll
v2210_wv_eengezinswoningen
v2210_wv_meergezinswoningen
v2210_wv_mg_2_5
v2210_wv_mg_6_10
v2210_wv_mg_11p
v2210_huishoudens
v2210_huurders
v2210_inwonend_eigenaarsgezin
v2210_hh_onbekend
v2210_wv_bj_voor1900
v2210_wv_bj_1900_1918
v2210_wv_bj_1919_1930
v2210_wv_bj_1931_1945
v2210_wv_bj_1946_1960
v2210_wv_bj_1961_1970
v2210_wv_bj_1971_1980
v2210_wv_bj_1981_1990
v2210_wv_bj_1991_2000
v2210_wv_bj_2001_2010
v2210_wv_bj_2011_2020
v2210_wv_bj_onbekend
v2210_wv_lw_1983_1990
v2210_wv_lw_1991_2000
v2210_wv_lw_2001_2010
v2210_wv_lw_2011_2020
v2210_wv_lw_onbekend
v2210_wgl_lwbj_1983_1990
v2210_wgl_lwbj_1991_2000
v2210_wgl_lwbj_2001_2010
v2210_wgl_lwbj_2011_2020
v2210_wgl_lwbj_1983p (f8.0).


* regel1: indien gebied onbekend: enkel dingen inlezen indien nodig. Alle zinloze waarden vervangen we door -99996.
* regel 2: indien Brussel: ALLES is een brekende missings -99999 (TOGA).
* regel 3: indien in een niet-onbekende statsec (alles behalve iets met "zzzz" is 0 = 0 en ook missing=0.

* regel 1.
do if char.index(geoitem,"ZZZZ")>0.
recode v2210_woonvoorraad v2210_woonaanbod v2210_wa_indiv v2210_wa_app
v2210_wa_coll v2210_wv_eengezinswoningen v2210_wv_meergezinswoningen v2210_wv_mg_2_5
v2210_wv_mg_6_10 v2210_wv_mg_11p v2210_huishoudens v2210_huurders
v2210_inwonend_eigenaarsgezin v2210_hh_onbekend v2210_wv_bj_voor1900 v2210_wv_bj_1900_1918
v2210_wv_bj_1919_1930 v2210_wv_bj_1931_1945 v2210_wv_bj_1946_1960 v2210_wv_bj_1961_1970
v2210_wv_bj_1971_1980 v2210_wv_bj_1981_1990 v2210_wv_bj_1991_2000 v2210_wv_bj_2001_2010
v2210_wv_bj_2011_2020 v2210_wv_bj_onbekend v2210_wv_lw_1983_1990 v2210_wv_lw_1991_2000
v2210_wv_lw_2001_2010 v2210_wv_lw_2011_2020 v2210_wv_lw_onbekend v2210_wgl_lwbj_1983_1990
v2210_wgl_lwbj_1991_2000 v2210_wgl_lwbj_2001_2010 v2210_wgl_lwbj_2011_2020 v2210_wgl_lwbj_1983p
(0=-99996) (missing=-99996).
end if.

* regel 2.
do if gewest=4000.
recode v2210_woonvoorraad v2210_woonaanbod v2210_wa_indiv v2210_wa_app
v2210_wa_coll v2210_wv_eengezinswoningen v2210_wv_meergezinswoningen v2210_wv_mg_2_5
v2210_wv_mg_6_10 v2210_wv_mg_11p v2210_huishoudens v2210_huurders
v2210_inwonend_eigenaarsgezin v2210_hh_onbekend v2210_wv_bj_voor1900 v2210_wv_bj_1900_1918
v2210_wv_bj_1919_1930 v2210_wv_bj_1931_1945 v2210_wv_bj_1946_1960 v2210_wv_bj_1961_1970
v2210_wv_bj_1971_1980 v2210_wv_bj_1981_1990 v2210_wv_bj_1991_2000 v2210_wv_bj_2001_2010
v2210_wv_bj_2011_2020 v2210_wv_bj_onbekend v2210_wv_lw_1983_1990 v2210_wv_lw_1991_2000
v2210_wv_lw_2001_2010 v2210_wv_lw_2011_2020 v2210_wv_lw_onbekend v2210_wgl_lwbj_1983_1990
v2210_wgl_lwbj_1991_2000 v2210_wgl_lwbj_2001_2010 v2210_wgl_lwbj_2011_2020 v2210_wgl_lwbj_1983p
(else=-99999).
end if.

* regel 3.
do if gewest=2000 & char.index(geoitem,"ZZZZ")=0 .
recode v2210_woonvoorraad v2210_woonaanbod v2210_wa_indiv v2210_wa_app
v2210_wa_coll v2210_wv_eengezinswoningen v2210_wv_meergezinswoningen v2210_wv_mg_2_5
v2210_wv_mg_6_10 v2210_wv_mg_11p v2210_huishoudens v2210_huurders
v2210_inwonend_eigenaarsgezin v2210_hh_onbekend v2210_wv_bj_voor1900 v2210_wv_bj_1900_1918
v2210_wv_bj_1919_1930 v2210_wv_bj_1931_1945 v2210_wv_bj_1946_1960 v2210_wv_bj_1961_1970
v2210_wv_bj_1971_1980 v2210_wv_bj_1981_1990 v2210_wv_bj_1991_2000 v2210_wv_bj_2001_2010
v2210_wv_bj_2011_2020 v2210_wv_bj_onbekend v2210_wv_lw_1983_1990 v2210_wv_lw_1991_2000
v2210_wv_lw_2001_2010 v2210_wv_lw_2011_2020 v2210_wv_lw_onbekend v2210_wgl_lwbj_1983_1990
v2210_wgl_lwbj_1991_2000 v2210_wgl_lwbj_2001_2010 v2210_wgl_lwbj_2011_2020 v2210_wgl_lwbj_1983p
(missing=0).
end if.

EXECUTE.
delete variables gewest.

* opmerking: na toepassen van deze regel zou het onmogelijk moeten zijn dat er nog velden zijn met een sysmis.


if wooneenheden=0 & bewoonbaar="J" onnozel_ding=1.

RECODE onnozel_ding_sum (SYSMIS=0) (ELSE=1) INTO ondummy. 
recode huidig_bewoond_sum (0=0) (else=1) into bewoonddummy.
recode wooneenheden_sum  (0=0) (else=1) into wooneenhdummy.
EXECUTE.
