#/bin/sh

# Lancement de la fusée TR18
#
# creation :  EF le 21/06/2017
#
# Traitements global des scenarios TR18 et reception
#
# Lance les scenarios
#   .. puis des traitements de gestions de fin de scenarios
# Pas beoin de faire de nohup
# Toutes les logs sont dans le meme fichier et aussi dans des fichiers separes

filename=$(echo $0 | xargs basename | cut -d\. -f 1)
environnement=$(hostname -s | cut -c1-3)
repTR18=/mnt/applis_mid_${environnement}/TR18/
repLog=${repTR18}/logs
filelog=$repLog/${filename}.log

echo "log synchro dans ${filelog} + logs classiques" 
echo "tail -100f ${filelog}" 
echo "   ... pour voir les logs"

(
# Fonction quit arrete en exit 1 avec message d'erreur
function quit {
        echo  -e $(date +"%x %X") - $1
        echo
        exit 1
}

# Function msg envoie message avec la date
function msg {
        echo  -e $(date +"%x %X") - $1
}

DATELOG=$(date +"%Y%m%d%H%M%S")
msg "Phase de ménage instensif ..."
/appli/sunopsis/TRAITEMENTS/shell/script_save_fichiers_tr18.sh
msg "OK"
# Lancement des scenarios
msg "$filename - decollage en cours ... "
$repTR18/scripts/SIRHEN_6.3_FLQTD_EXT_RUN_AAF.sh -l -e $environnement 2>&1 | tee $repLog/SIRHEN_6.3_FLQTD_EXT_RUN_AAF-${DATELOG}.log &
sleep 5
msg "$filename - RUN_AAF lancé"
$repTR18/scripts/SIRHEN_6.3_FLQTD_EXT_RUN_LDAP.sh -l -e $environnement 2>&1 | tee $repLog/SIRHEN_6.3_FLQTD_EXT_RUN_LDAP-${DATELOG}.log &
sleep 5
msg "$filename - RUN_LDAP lancé"
$repTR18/scripts/TR18_TLQTD_SIRHEN_6.3_RUN_INFO.sh -l -e $environnement 2>&1 | tee $repLog/TR18_TLQTD_SIRHEN_6.3_RUN_INFO-${DATELOG}.log &
sleep 5
msg "$filename - RUN_INFO lancé"
echo
msg "$filename - En attente de l'alunage ... "
msg "$filename - demarrage de  COPIE-FICHIERS "
$repTR18/scripts/TR18_TLQTD_SIRHEN_6.3_COPIE-FICHIERS.sh -l -e $environnement 2>&1 | tee $repLog/TR18_TLQTD_SIRHEN_6.3_COPIE-FICHIERS-${DATELOG}.log &
msg "$filename - module COPIE-FICHIER envoyé"
# Gestion des scenarios demarre / arrete
$repTR18/scripts/SIRHEN_6.3_FLQTD_EXT_AAF_PILOTAGE.sh -l -e $environnement 2>&1 | tee $repLog/SIRHEN_6.3_FLQTD_EXT_AAF_PILOTAGE-${DATELOG}.log &
msg "$filename - module AAF_PILOTAGE envoyé"
$repTR18/scripts/SIRHEN_6.3_FLQTD_EXT_LDAP_PILOTAGE.sh -l -e $environnement 2>&1 | tee $repLog/SIRHEN_6.3_FLQTD_EXT_LDAP_PILOTAGE-${DATELOG}.log &
msg "$filename - module LDAP_PILOTAGE envoyé"

# Non ne tue pas tes fils !
disown -h
msg "$filename - Fin des preparatifs "

) 2>&1 | tee $filelog 

