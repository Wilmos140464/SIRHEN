#!/bin/bash
###==========================================================================
#@(#) PROCEDURE: 	SIRHEN-SIRHEN
#@(#) OBJET: 		Restauration de la base TAMPON de SAU avec le backup TAMPON de PR3
#@(#) AUTEUR: 		BG
#@(#) DATE CREATION: 	2016/11/02
#@(#)
###==========================================================================

### set -x est parametre si la variable S_DEBUG est vraie
[ "${S_DEBUG}" = "true" ] && set -x

echo -e "\n\nDÈbut de la restore de TAMPON PR3 sur SAU : "`date`

###===========###
### Variables ###
###===========###

### Definition des variables locales ( Lettres capitales pour le debut de chaque syllabes)

NbStep=$(egrep "STEP[0-9]" $0|wc -l)

Pid="[${$}]"
echo " Le PID du script est : ${Pid} "
ordo_exec=1

###===========###
### Parametre ###
###===========###
while getopts ":le::" opt; do
        ###echo "getopts a trouv√© l'option $opt"
        case $opt in
                l)
                        ordo_exec=0
			env=""
                ;;
                e)
                        env=$( echo ${OPTARG} | tr [A-Z] [a-z])
                ;;
                \?)
                        echo -e "### Fin anormale de traitement lors de la verification des options d'appel"
                        echo -e "### L'option -$OPTARG n'est pas valide"
                        exit 1;
                ;;
        esac
done

###===========###
### Fonctions ###
###===========###

MESSAGE ()
### objet:	
###	Affiche un message dans la log du job et la trace automate
### Requiert: 
### 	- $1: Message texte
{
	echo -e ${1}
	[ $ordo_exec -eq 1 ] && ${UXEXE}/uxset msg "${1}"
}


TEST_ERROR ()
### objet:	
###	Test si il y a une erreur 
### Requiert: 
### 	- $1: Code Retour
###  	- $2: Message d'erreur (optionel)      
{
	if [ ${1} != 0 ] ; then  
		MESSAGE "### Fin anormale de traitement dans STEP${CntStep}"
		MESSAGE "### Code Retour 	=${1}"
		MESSAGE "### Msg  Erreur 	=${2}"

		## Recuperation de la derniere log
	        trace=`ls -rt /mnt/applis_mid_sau/SIRHEN/logs/TAMPON_TLQTD_SIRHEN_6.3_SIRHEN-SAU_RESTORE_db203_db2itamp*|tail -1`
       		/bin/mail -s "sau-sir-db203.sirhen.hp.in.phm.education.gouv.fr : Plateforme SAU : Restore KO de la base TAMPON PR3 sur TAMPON SAU : `date` " sirhen-itp@education.gouv.fr < $trace

		exit 1
	else
		MESSAGE "\t### Fin valide de traitement."
	fi
}

STEP0 ()

### objet: Chargement des variables necessaire a l'execution du script	
###	varibales globales statique et dynamique / variable locales statiques
{
	MESSAGE "### $FUNCNAME chargement des variables globales et locales  ### "	
	Command="source /mnt/applis_mid_$env/SIRHEN/conf/global_var_script_tampon"
	MESSAGE "Lancement de la commande : ${Command} "	
	eval ${Command}
	TEST_ERROR ${?} "Impossible de recuperer ou instancier les variables globales!"

	Command="source /mnt/applis_mid_$env/SIRHEN/conf/local_var_script_tampon_restore"
	MESSAGE "Lancement de la commande : ${Command} "	
	eval ${Command}
	TEST_ERROR ${?} "Impossible de recuperer ou instancier les variables locales!"
	
}

echo -e "\n\nFin du step0 restore sur SAU : "`date`

STEP1 ()

### objet: Verification du besoin de restauration du backup TAMPON vers TAMPON SAU
###     Y-a-t-il une base TAMPON : variable $exist_tampon == true
{
	MESSAGE "### $FUNCNAME   Verification du besoin de restauration du backup TAMPON vers TAMPON SAU ${UXARCHIVE} ### "
	MESSAGE "Verification de l'initialisation de la variable exist_tampon"
	Command=' [ ! -z $exist_tampon ] '
	eval ${Command}
	TEST_ERROR ${?} "Variable exist_tampon non definie!"

	if [ "$exist_tampon" == false ]; then
		MESSAGE "Pas de base TAMPON sur l'environnement SAU => pas de backup"
		true
		TEST_ERROR ${?} "Erreur improbable"

		MESSAGE ""
        	MESSAGE "### Sortie OK du traitement de l'UPROC $(basename $0)"
       		exit 0
	fi 
}

echo -e "\n\nFin du step1 restore sur SAU : "`date`

STEP2 ()

### objet: Restauration phase 5: lever la recuperation aval en attente

{

        MESSAGE "### $FUNCNAME  Restauration phase 5/5: lever la recuperation aval en attente ${UXARCHIVE} ### "

        Command='db2 "rollforward db $base_cible complete"'
        eval ${Command}
        TEST_ERROR ${?} "Rollforward de la base $base_cible en erreur"
}

echo -e "\n\nFin du step2 restore sur SAU : "`date`

STEP3 ()

### objet: Activation de la base $base_cible
{

        MESSAGE "### $FUNCNAME Activation de la base $base_cible ${UXARCHIVE} ### "

        Command='db2 "activate db $base_cible"'
        eval ${Command}
        #TEST_ERROR ${?} "Activation impossible de la base $base_cible suite a sa restauration"
}

echo -e "\n\nFin du step3 restore sur SAU : "`date`

STEP4 ()

### objet: OPERATION DE POST restauration
### modification de la description de la base
### modification du logarmeth

{
        MESSAGE "### $FUNCNAME Operation de post restauration de la $base_cible ${UXARCHIVE} ### "

        db2 "change database $base_cible comment with 'Snapshot base $base_source source'"

	## Changer le logarchmeth1 (sinon, il conserve celui aui est embarqu‚?? dans la conf de la base source et cela g‚??n‚??re plein d'erreurs - inutiles - dans le db2diag)

	db2 connect to $base_cible

        TEST_ERROR ${?} "connexion impossible a la base $base_cible"

#        db2 update db cfg using logarchmeth1 DISK:$rep_logarch
	db2 terminate

	MESSAGE "Application des grants sur la base $base_cible"

	cd /db2data/db2itamp/shell/grants/
		./grant_uSUPERVISION_db2-9.x_v1.1.sh  SIRHEN racdb2 poledb2
		./grant_SIRHEN.sh
		./grant_specif_SIRHEN.sh
		./grant_user_base_db2-9.7.sh sirhen deciload C

	MESSAGE "Fin du passage des grants sur la base $base_cible"

}

echo -e "\n\nFin du step4 restore sur SAU : "`date`


STEPFIN ()

###  
### STEP DE FIN
### 

{
	MESSAGE ""
        MESSAGE "FIN des operations de restauration de la base $base_cible sur l'environnement SAU"
}

echo -e "\n\nFin du stepfin restore sur SAU : "`date`

### ----------------------------------------------------------------------------
### Mettre ici chaque bloc de step (au format STEPn ())


###======###
### MAIN ###
###======###

[ $ordo_exec -eq 0 ] && S_NUMJALON=0
CntStep=${S_NUMJALON}

let CntStep=${CntStep}

while  [[ ${CntStep} -lt ${NbStep} ]] 

do
	[ $ordo_exec -eq 1 ] && ${UXEXE}/uxset step ${CntStep}
        MESSAGE ""
	MESSAGE "====================================== "
	STEP${CntStep}	
	let CntStep=CntStep+1
done

if [ ${CntStep} = $NbStep ]; then
        MESSAGE ""
        MESSAGE "### Sortie OK du traitement complet de l'UPROC $(basename $0)"
        MESSAGE ""

        echo -e "\n\nFin de la restore OK de la base TAMPON PR3 sur SAU : "`date`
        
	## Recuperation de la derniere log
        trace=`ls -rt /mnt/applis_mid_sau/SIRHEN/logs/TAMPON_TLQTD_SIRHEN_6.3_SIRHEN-SAU_RESTORE_db203_db2itamp*|tail -1`
        /bin/mail -s "sau-sir-db203.sirhen.hp.in.phm.education.gouv.fr : Plateforme SAU : Fin de la restore OK de la base TAMPON PR3 sur TAMPON SAU : `date` " sirhen-itp@education.gouv.fr < $trace

echo "FIN"

fi

MESSAGE ""
MESSAGE "### Toutes les etapes sont terminees ### "
exit 0
