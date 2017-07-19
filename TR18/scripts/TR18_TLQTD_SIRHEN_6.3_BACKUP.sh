#!/bin/sh
###==========================================================================
#@(#) PROCEDURE: 	...
#@(#) OBJET: 		...
#@(#)         		...
#@(#) AUTEUR: 		LMU
#@(#) DATE CREATION: 	2015/03/05--17H20
#@(#) MODIFICATIONS:    JCH 2016/07/08 supression des flags
#@(#)
###==========================================================================

### set -x est parametre si la variable S_DEBUG est vraie
[ "${S_DEBUG}" = "true" ] && set -x


###===========###
### Variables ###
###===========###

# set -x

### Definition des variables locales ( Lettres capitales pour le debut de chaque syllabes)

#NbStep=$(egrep "STEP[0-9]" $0|wc -l)
NbStep=$(egrep "^STEP[0-9]" $0|wc -l)
echo " Le nb de step est: "$NbStep
DATE_DEM=`date +%Y-%m-%d:%Hh%m`
echo "La date de demarrage est :"$DATE_DEM

Pid="[${$}]"
echo " Le PID du script est : ${Pid} "
ordo_exec=1

###===========###
### Parametre ###
###===========###
while getopts ":le::" opt; do
        ###echo "getopts a trouvé l'option $opt"
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
		exit 1
	else
		MESSAGE "\t### Fin valide de traitement."
	fi
}


STEP0 ()
### objet: Chargement des variables globales et locale pour le script
###	Commentaire de l etape
{
	MESSAGE "### $FUNCNAME chargement des variables globales et locale pour le script ${UXARCHIVE} ### "	
	Command="source /mnt/applis_mid_$env/TR18/conf/global_var_script_tr18"
	MESSAGE "Lancement de la commande : ${Command} "	
	eval ${Command}
	TEST_ERROR ${?} "Message d erreur!"

	Command="source /mnt/applis_mid_$env/TR18/conf/local_var_script_sirhen_backup"
	MESSAGE "Lancement de la commande : ${Command} "
	eval ${Command}
	TEST_ERROR ${?} "Message d erreur!"
	
}

STEP1 ()
### objet: Suppression des anciens backup SIRHEN sur le NFS dedie a TR18
###     Commentaire de l etape
{
	MESSAGE "### $FUNCNAME Suppression des anciens backup SIRHEN sur le NFS dedie a TR18 ${UXARCHIVE} ### "	

	MESSAGE "Verification de l'instanciation des variables"
	Command=" [ ! -z $rep_bkp_sirhen ] "
	eval ${Command}
	TEST_ERROR ${?} "Variable rep_bkp_sirhen non definie!"

        Command="rm -f $rep_bkp_sirhen/SIRHEN.0.db2isirh*"
        MESSAGE "Lancement de la commande : ${Command} "
        eval ${Command}
	true
        TEST_ERROR ${?} "Message d erreur!"
}



STEP2 ()
### objet: Creation d'un backup online de la base sirhen pour TR18
###     Commentaire de l etape
{
        MESSAGE "### $FUNCNAME Creation d'un backup de la base sirhen pour TR18"
	if [ "$exist_snapsirh" == false ]; then
		MESSAGE "BackUp non necessaire car pas de base SNAPSIRH"
		echo > /dev/null
		TEST_ERROR ${?} "Erreur inattendue"
		return 0
	else
		## Backup online de la base sirhen
		MESSAGE "Backup de la base SIRHEN"
		db2 "backup db sirhen online to $rep_bkp_sirhen compress include logs without prompting"
        	TEST_ERROR ${?} "Message d erreur!"
		bkp=$(ls -rt $rep_bkp_sirhen/SIRHEN.0.db2isirh* | tail -1);
		chmod 644 $bkp;
	fi
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
