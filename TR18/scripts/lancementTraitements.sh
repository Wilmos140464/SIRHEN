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
repLog=/mnt/applis_mid_ru3/TR18/logs
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
msg "decollage en cours ... "
/mnt/applis_mid_ru3/TR18/scripts/SIRHEN_6.3_FLQTD_EXT_RUN_AAF.sh -l -e ru3 2>&1 | tee $repLog/SIRHEN_6.3_FLQTD_EXT_RUN_AAF-${DATELOG}.log
msg "RUN_AAF lancé"
/mnt/applis_mid_ru3/TR18/scripts/SIRHEN_6.3_FLQTD_EXT_RUN_LDAP.sh -l -e ru3 2>&1 | tee $repLog/SIRHEN_6.3_FLQTD_EXT_RUN_LDAP-${DATELOG}.log
msg "RUN_LDAP lancé"
# on lance le RUN_INFO en background des fis c'est ncessaire ??
/mnt/applis_mid_ru3/TR18/scripts/TR18_TLQTD_SIRHEN_6.3_RUN_INFO.sh -l -e ru3 2>&1 | tee $repLog/TR18_TLQTD_SIRHEN_6.3_RUN_INFO-${DATELOG}.log &
sleep 5
msg "RUN_INFO lancé"

msg "En attente de l'alunage ... "
msg "demarrage de  COPIE-FICHIERS "
/mnt/applis_mid_ru3/TR18/scripts/TR18_TLQTD_SIRHEN_6.3_COPIE-FICHIERS.sh -l -e ru3 2>&1 | tee $repLog/TR18_TLQTD_SIRHEN_6.3_COPIE-FICHIERS-${DATELOG}.log &
msg "module COPIE-FICHIER envoyé"
# Gestion des scenarios demarre / arrete
/mnt/applis_mid_ru3/TR18/scripts/SIRHEN_6.3_FLQTD_EXT_AAF_PILOTAGE.sh -l -e ru3 2>&1 | tee $repLog/SIRHEN_6.3_FLQTD_EXT_AAF_PILOTAGE-${DATELOG}.log &
msg "module AAF_PILOTAGE envoyé"
/mnt/applis_mid_ru3/TR18/scripts/SIRHEN_6.3_FLQTD_EXT_LDAP_PILOTAGE.sh -l -e ru3 2>&1 | tee $repLog/SIRHEN_6.3_FLQTD_EXT_LDAP_PILOTAGE-${DATELOG}.log &
msg "module LDAP_PILOTAGE envoyé"

# Non ne tue pas tes fils !
disown -h
msg " Fin des preparatifs "

) &> $filelog 

