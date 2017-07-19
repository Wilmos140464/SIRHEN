#!/bin/sh
###==========================================================================
#@(#) PROCEDURE: 	TR18
#@(#) OBJET: 		lancement des scenarios ODI SIRHEN pour AAF
#@(#)         		en mode ligne commande pour la 6.3...
#@(#)			Objectif : régler le pb de time-out en mode boucle
#@(#)			permettre une relance facilitée des scénarios
#@(#) AUTEUR: 		JCH
#@(#) DATE CREATION: 	2016/09/08--15H20
#@(#) MODIFICATIONS:    WMO - 09/05/2017 - Compression du repertoire save
#@(#)
###==========================================================================

### set -x est parametre si la variable S_DEBUG est vraie
[ "${S_DEBUG}" = "true" ] && set -x


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
        ###echo "getopts a trouvé l'option $opt"
        case $opt in
                l)
                        ordo_exec=0
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
### objet: Chargement des variables necessaire a l'execution du script	
###	varibales globales statique et dynamique / variable locales statiques
{
	MESSAGE "### $FUNCNAME chargement des variables globales et locale pour le script $0 de la chaine TR18 ${UXARCHIVE} ### "	

	Command="source /mnt/applis_mid_$env/TR18/conf/global_var_script_tr18"
	MESSAGE "Lancement de la commande : ${Command} "	
	eval ${Command}
	TEST_ERROR ${?} "Impossible de recuperer ou instancier les variables globales!"

	Command="source /mnt/applis_mid_$env/TR18/conf/local_var_script_tr18_odi_sirhen"
	MESSAGE "Lancement de la commande : ${Command} "	
	eval ${Command}
	TEST_ERROR ${?} "Impossible de recuperer ou instancier les variables locales!"
	
}

STEP1 ()
### objet: On fait le menage dans la table de traitement ODI SIRHEN
###     Connexion a la base TR18 et reinit de ex_odi.etattraitement
{
	MESSAGE "### $FUNCNAME Verification si un traitement ODI SIRHEN est en cours ${UXARCHIVE} ### "
#set -x
	MESSAGE " on source l'environnement db2"
	source ~/sqllib/db2profile
	TEST_ERROR ${?} "Sourcage de l'environnement DB2 impossible!"

	MESSAGE "on source les parametres de connexion a la base TR18"
	source /mnt/applis_mid_$env/TR18/conf/.db2_SIRHEN_TR18
	TEST_ERROR ${?} "Sourcage des parametres de connexion a la base TR18 impossible!"

	MESSAGE "Connexion a la base TR18"
	db2 connect to $base_TR18 user $usr_TR18 using $mdp_TR18 > /dev/null 2>&1
	TEST_ERROR ${?} "Probleme de connexion a la base TR18"

	declare -i nb_odi_encours=0

	db2 -x "update ex_odi.etattraitement set idetat= 'ATR' where idetat like 'A%' and idtypetraitement like '%_AAF'"
	db2 -x "update ex_odi.etattraitement set idetat= 'ETR' where idetat like 'E%' and idtypetraitement like '%_AAF'"
	
	nb_odi_encours=$(db2 -x "select count(idetat) from ex_odi.etattraitement where idetat like 'AEC%' and idtypetraitement like '%_AAF' ")

	MESSAGE "Verification des traitements ODI SIRHEN"
	[ $nb_odi_encours -eq 0 ]
	TEST_ERROR ${?} "Il y a un traitement ODI SIRHEN en cours => arret de l'execution"
	MESSAGE "Il n'y a pas de traitement ODI SIRHEN => on peut continuer"
}


STEP2 ()
### objet: Archivage des anciens fichiers generes et lancement des traitements ODI SIRHEN
### 
{
	MESSAGE "### $FUNCNAME Lancement des scenarios ODI ${UXARCHIVE} ### "	

	MESSAGE "Verification de l initialisation de la variable rep_sortie"	
	[ ! -z $rep_sortie ]
	TEST_ERROR ${?} "Variable non initialisee!"

	MESSAGE "Verification de l initialisation de la variable rep_declenchement_tr18"
	[ ! -z $rep_declenchement_tr18 ]
	TEST_ERROR ${?} "Variable non initialisee!"


	MESSAGE "Verification de l initialisation de la variable exec_scen_AAF"
	[ ! -z $exec_scen_AAF ]
	TEST_ERROR ${?} "Variable non initialisee!"

	## lancement des scenarios SIRHEN TR18 AAF

	if [ $exec_scen_AAF = "true" ]; then
	        MESSAGE "Suppression des anciens fichiers aaf archives ayant plus de 7 jours"
		cd $rep_sortie/save
		tar xzvf aaf.tar.gz
        	find $rep_sortie/save/aaf/ -type f -ctime +7 -exec rm -f {} \;

	        true
        	TEST_ERROR ${?} "Erreur impossible"

	        DATE=`date "+%Y%m%d%H%M"`

		MESSAGE "Archivage des fichiers du precedent traitement AAF"
		[ ! -d $rep_sortie/save/aaf/ ] && mkdir $rep_sortie/save/aaf/
		###mv $rep_sortie/annuaire-aaf/* $rep_sortie/save/aaf/ 2>/dev/null
		cp -r $rep_sortie/annuaire-af/* $rep_sortie/save/aaf/
		
		cd $rep_sortie/save
                tar czvf aaf.tar.gz aaf/*
                sleep 5
		find $rep_sortie/save/aaf/ -type f -name "*aaf*" -exec rm -f {} \;
		rm -rf $rep_sortie/save/aaf

		find $rep_sortie/annuaire-af/ -type f -name "*aaf*" -exec rm -f {} \;
		true
		TEST_ERROR ${?} "Erreur impossible"

		MESSAGE "Lancement scenario AAF"
		touch $rep_declenchement_tr18/AAF/Atraiter/sirhen_aaf_${DATE}.dsp
		TEST_ERROR ${?} "Creation du drapeau DSP pour le scenario AAF impossible"
	fi

}

STEP3 ()
### objet: Mise en place du timestamp
###
{
        MESSAGE "### $FUNCNAME  Mise en place du timestamp  ${UXARCHIVE} ### "

        ## Verification de la presence du fichier tmstmp_tr18_extr_ok. S'il n'y est pas, on le cree en y ajoutant un timestamp.
                date +'%Y-%m-%d-%H.%M.%S.000000' > $fic_tmstmp_tr18_extr_aaf_ok;
                chmod 664 $fic_tmstmp_tr18_extr_aaf_ok;
}

STEP4 ()
{
### objet: Lancement du scenario


        MESSAGE "scenario AAF"
        Command="$start_scen_AAF &  "
        MESSAGE "Lancement de la commande : ${Command} "
        eval ${Command}
        TEST_ERROR ${?} "Erreur sur AAF!"

#/appli/odi/oracledi/bin/startscen_QP3_TR18.sh TR18_ALM_AAF 001 GLOBAL -NAME=AGENT_QP3_TR18 

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
        MESSAGE "### Sortie OK du traitement complet de l'UPROC $(basename $0)"
        MESSAGE ""
fi

MESSAGE ""
MESSAGE "### Toutes les etapes sont terminees ### "
exit 0
