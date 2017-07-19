#!/bin/sh
###==========================================================================
#@(#) PROCEDURE: 	TR18
#@(#) OBJET: 		Creation d un dump de la base IRHENWKS pour restauration future sur IRHEN
#@(#)         		...
#@(#) AUTEUR: 		LMU
#@(#) DATE CREATION: 	2015/03/10--13H20
#@(#) MODIFICATIONS:    JCH 2016/07/08 suppression des flags
#@(#)
###==========================================================================

ordo_exec=1

while getopts ":le::" opt; do
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

### set -x est parametre si la variable S_DEBUG est vraie
[ "${S_DEBUG}" = "true" ] && set -x


###===========###
### Variables ###
###===========###

### Definition des variables locales ( Lettres capitales pour le debut de chaque syllabes)

NbStep=$(egrep "STEP[0-9]" $0|wc -l)
Pid="[${$}]"
echo " Le PID du script est : ${Pid} "

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
		exit 1
	else
		MESSAGE "\t### Fin valide de traitement."
	fi
}


STEP0 ()
### objet:  Chargement des variables globales et locale	
###
{
	MESSAGE "### $FUNCNAME Chargement des variables globales et locale pour le script de la chaine TR18 ${UXARCHIVE} ### "	
	Command='source /mnt/applis_mid_$env/TR18/conf/global_var_script_tr18'
	MESSAGE "Lancement de la commande : ${Command} "	
	eval ${Command}
	TEST_ERROR ${?} "Message d erreur!"

	Command='source /mnt/applis_mid_$env/TR18/conf/local_var_script_irhenwks_backup_pour_irhen'
	MESSAGE "Lancement de la commande : ${Command} "	
	eval ${Command}
	TEST_ERROR ${?} "Message d erreur!"
}



STEP1 ()
### objet: Verification du besoin de backup de la base irhenwks
###    Il y a t il une base SNAPSIRH : variable $exist_irenwks == true
{
        MESSAGE "### $FUNCNAME   Verification de l existence du une base SNAPSIRH sur l environnement ${UXARCHIVE} ### "
        MESSAGE "Verification de l'initialisation de la variable exist_irenwks"
        Command=' [ ! -z $exist_irhenwks ] '
        eval ${Command}
        TEST_ERROR ${?} "Variable exist_irenwks non definie!"
        if [ "$exist_irhenwks" == false ]; then
                MESSAGE "Pas de base IRHENWKS sur l'environnement => pas de backup"

                MESSAGE ""
                MESSAGE "### Sortie OK du traitement de l'UPROC $(basename $0)"
                exit 0
        fi	
}


STEP2 ()
### objet: Suppression du backup precedent
###
{
	MESSAGE "### $FUNCNAME Suppression du backup precedent sur le NFS ${UXARCHIVE} ### "
	MESSAGE "Verification de l'initialisation des variables"
	[ ! -z $rep_bkp_irhenwks ]
        TEST_ERROR ${?} "Variable rep_bkp_irhenwks non definie!"
	[ ! -z $base_irhenwks ]
        TEST_ERROR ${?} "Variable base_irhenwks non definie!"
	[ ! -z $instance_irhenwks ]
        TEST_ERROR ${?} "Variable instance_irhenwks non definie!"

	MESSAGE "Suppression du backup precedent sur le NFS"
	Command='rm -f $rep_bkp_irhenwks/$base_irhenwks.0.$instance_irhenwks*'
	true
	eval ${Command}
        TEST_ERROR ${?} "Suppression des backup $base sur le NFS impossible"
}

STEP3 ()
### objet: Backup offline de la base IRHENWKS
###
{
	MESSAGE "### $FUNCNAME  Backup de la base IRHENWKS  ${UXARCHIVE} ### "

        MESSAGE "Verification de l'initialisation des variables"
        [ ! -z $rep_bkp_irhenwks ]
        TEST_ERROR ${?} "Variable rep_bkp_irhenwks non definie!"
        [ ! -z $base_irhenwks ]
        TEST_ERROR ${?} "Variable base_irhenwks non definie!"
        [ ! -z $instance_irhenwks ]
        TEST_ERROR ${?} "Variable instance_irhenwks non definie!"


	MESSAGE "Backup Offline via script MEN"
	date_backup=$(date +"%y%m%d");
	/mnt/applis_mid_$env/shell_commun/db2/backup/backup_v1.4.3.sh $instance_irhenwks $base_irhenwks F
	TEST_ERROR ${?} "Backup $base_irhenwks en erreur : script MEN"

	MESSAGE "Verification de l ecriture du backup en local"
	ls -rt /db2backup/$instance_irhenwks/$base_irhenwks/$base_irhenwks.0.$instance_irhenwks.*$date_backup* 2> /dev/null;
	TEST_ERROR ${?} "Aucun backup en local sous /db2backup/$instance_irhenwks/$base_irhenwks/"
	bkp=$(ls -rt /db2backup/$instance_irhenwks/$base_irhenwks/$base_irhenwks.0.$instance_irhenwks.*$date_backup* |tail -1) ;

	## Deplacement du backup
	MESSAGE "Copie du backup sur le NFS"
	cp $bkp $rep_bkp_irhenwks;
	#JCH s'assurer que le groupe 500 a les acc√s
	chmod 644 $rep_bkp_irhenwks/*db2irhen*
	TEST_ERROR ${?} "Erreur lors de la copie du backup $base_irhenwks sur le NFS"
}


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
        MESSAGE "### Sortie OK du traitement complet de l'UPROC $(basename $0)."
        MESSAGE ""
fi

MESSAGE "### Toutes les etapes sont terminees ### "
exit 0
