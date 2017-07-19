#!/bin/sh
###==========================================================================
#@(#) PROCEDURE: 	TR18
#@(#) OBJET: 		lancement des scenarios ODI SIRHEN
#@(#)         		...
#@(#) AUTEUR: 		LMU
#@(#) DATE CREATION: 	2015/03/06--15H20
#@(#) MODIFICATIONS: 	JCH 2016/07/08 suppression des flags
#@(#)			JCH 2016/08/17 Forcer la mise a jour du timestamp.
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
### objet: Verification d'un traitement ODI SIRHEN en cours
###     Connexion a la base TR18 et verification de ex_odi.etattraitement
{
	MESSAGE "### $FUNCNAME Verification si un traitement ODI SIRHEN est en cours ${UXARCHIVE} ### "

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
	nb_odi_encours=$(db2 -x "select count(idetat) from ex_odi.etattraitement where idetat like 'AEC%' and  idtypetraitement not like '%_LDAP' and idtypetraitement not like '%_AAF' ")

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

        MESSAGE "Verification de l initialisation des variables du script"
	MESSAGE "Verification de l initialisation de la variable rep_sortie"	
	[ ! -z $rep_sortie ]
	TEST_ERROR ${?} "Variable non initialisee!"

	MESSAGE "Verification de l initialisation de la variable rep_declenchement_tr18"
	[ ! -z $rep_declenchement_tr18 ]
	TEST_ERROR ${?} "Variable non initialisee!"

	MESSAGE "Verification de l initialisation de la variable exec_scen_AAF"
	[ ! -z $exec_scen_AAF ]
	TEST_ERROR ${?} "Variable non initialisee!"

	MESSAGE "Verification de l initialisation de la variable exec_scen_CDM_INFOAGT_REFE"
	[ ! -z $exec_scen_CDM_INFOAGT_REFE ]
	TEST_ERROR ${?} "Variable non initialisee!"

	## lancement des scenarios SIRHEN TR18
	MESSAGE "Suppression des anciens fichiers generes et archives"
	[ -d $rep_sortie/save ] && rm -f $rep_sortie/save/* 2>/dev/null
	true
	TEST_ERROR ${?} "Erreur impossible"

	DATE=`date "+%Y%m%d%H%M"`

	if [ $exec_scen_CDM_INFOAGT_REFE = "true" ]; then
		MESSAGE "Archivage des fichiers du precedent traitement CDM INFOAGENT REFE"
		[ ! -d $rep_sortie/save ] && mkdir $rep_sortie/save
		mv $rep_sortie/infocentre-affe/* $rep_sortie/save/ 2>/dev/null
		mv $rep_sortie/infocentre-car/* $rep_sortie/save/ 2>/dev/null
		mv $rep_sortie/infocentre-fina/* $rep_sortie/save/ 2>/dev/null
		mv $rep_sortie/infocentre-gda/* $rep_sortie/save/ 2>/dev/null
		mv $rep_sortie/infocentre-moye/* $rep_sortie/save/ 2>/dev/null
		mv $rep_sortie/infocentre-papr/* $rep_sortie/save/ 2>/dev/null
		mv $rep_sortie/infocentre-info/* $rep_sortie/save/ 2>/dev/null
		mv $rep_sortie/infocentre-ref/* $rep_sortie/save/ 2>/dev/null
		mv $rep_sortie/infocentre-sit/* $rep_sortie/save/ 2>/dev/null
		true
		TEST_ERROR ${?} "Erreur impossible"

		MESSAGE "Lancement scenario CDM"
		touch $rep_declenchement_tr18/CDM/Atraiter/sirhen_moye_${DATE}.dsp
		TEST_ERROR ${?} "Creation du drapeau DSP pour le scenario CDM impossible"

		MESSAGE "Lancement scenario GDA desactive"
                touch $rep_declenchement_tr18/GDA/Atraiter/sirhen_gda_${DATE}.dsp
                TEST_ERROR ${?} "Creation du drapeau DSP pour le scenario GDA impossible"

		MESSAGE "Lancement scenario INFOAGENT"
		touch $rep_declenchement_tr18/INFOAGENT/Atraiter/sirhen_infoagent_${DATE}.dsp
		TEST_ERROR ${?} "Creation du drapeau DSP pour le scenario INFOAGENT impossible"
		
		MESSAGE "Lancement scenario REFE"
		touch $rep_declenchement_tr18/REFE/Atraiter/sirhen_refe_${DATE}.dsp
		TEST_ERROR ${?} "Creation du drapeau DSP pour le scenario REFE impossible"
	fi

}

STEP3 ()
### objet: Mise en place du timestamp                
###
{
        MESSAGE "### $FUNCNAME  Mise en place du timestamp  ${UXARCHIVE} ### "

        ## Mise a jour du timestamp en debut de traitement pour TR18
        date +'%Y-%m-%d-%H.%M.%S.000000' > $fic_tmstmp_tr18_extr_ok;
        chmod 664 $fic_tmstmp_tr18_extr_ok;
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
