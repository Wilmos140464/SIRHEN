#!/bin/sh
###==========================================================================
#@(#) PROCEDURE: 	TR18 TOUCH INFO
#@(#) OBJET: 		lancement des scenarios ODI SIRHEN INFOAGENT 
#@(#)         		en mode ligne commande pour la 6.3...
#@(#)			Objectif : régler le pb de time-out en mode boucle
#@(#)			permettre une relance facilitée des scénarios
#@(#) AUTEUR: 		JCH/MOM
#@(#) DATE CREATION: 	2016/03/06--15H20
#@(#) MODIFICATIONS: 	JCH 2016/07/08 suppression des flags
#@(#)			JCH 2016/08/17 Forcer la mise a jour du timestamp.
#@(#)                   WMO 2017/05/05 Compression du repertoire save
#@(#)
###==========================================================================

### set -x est parametre si la variable S_DEBUG est vraie
[ "${S_DEBUG}" = "true" ] && set -x

###===========###
### Variables ###
###===========###

### Definition des variables locales ( Lettres capitales pour le debut de chaque syllabes)

NbStep=$(egrep "^STEP[0-9]" $0|wc -l)
Pid="[${$}]"
echo " Le PID du script est : ${Pid} "
ordo_exec=1

#DATE_TAR=`date "+%Y%m%d"`

DATE_DEMARRAGE=`date "+DATE: %Y-%m-%d%nTIME: : %H%M%S"`
echo "le demarrage est fait a :" $DATE_DEMARRAGE

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

#set -x

STEP1 ()
### objet: On fait le menage dans la table de traitement ODI SIRHEN
###     Connexion a la base TR18 et reinit de ex_odi.etattraitement
{
	#set -x
	MESSAGE "### $FUNCNAME Verification si un traitement ODI SIRHEN est en cours ${UXARCHIVE} ### "

	MESSAGE " on source l'environnement db2"
	source ~/sqllib/db2profile
	TEST_ERROR ${?} "Sourcage de l'environnement DB2 impossible!"

	MESSAGE "on source les parametres de connexion a la base TR18"
	source /mnt/applis_mid_$env/TR18/conf/.db2_SIRHEN_TR18
	TEST_ERROR ${?} "Source des parametres de connexion a la base TR18 impossible!"

	echo $LOGNAME

	MESSAGE "Connexion a la base TR18"
	db2 connect to $base_TR18 user $usr_TR18 using $mdp_TR18 > /dev/null 2>&1
	TEST_ERROR ${?} "Probleme de connexion a la base TR18"
	declare -i nb_odi_encours=0
	db2 -x "update ex_odi.etattraitement set idetat= 'ATR' where idetat like 'A%' and  idtypetraitement not like '%_LDAP' and idtypetraitement not like '%_AAF'"
	
	db2 -x "update ex_odi.etattraitement set idetat= 'ETR' where idetat like 'E%' and  idtypetraitement not like '%_LDAP' and idtypetraitement not like '%_AAF'"
	
	nb_odi_encours=$(db2 -x "select count(idetat) from ex_odi.etattraitement where idetat like 'AEC%' and  idtypetraitement not like '%_LDAP' and idtypetraitement not like '%_AAF' ")

	echo "la variable nb_odi_encours vaut: "$nb_odi_encours

	MESSAGE "Verification des traitements ODI SIRHEN"
	[ $nb_odi_encours -eq 0 ]
	TEST_ERROR ${?} "Il y a un traitement ODI SIRHEN en cours => arret de l'execution"
	MESSAGE "Il n'y a pas de traitement ODI SIRHEN => on peut continuer"

	MESSAGE "On fait le message et on initialise la plateforme"
	Command="/appli/sunopsis/TRAITEMENTS/shell/script_save_fichiers_tr18.sh"
	eval ${Command}
        TEST_ERROR ${?} "Impossible de initializer la plateforme"


}

STEP2 ()
### objet: Mise en place du timestamp
###
{
        MESSAGE "### $FUNCNAME  Mise en place du timestamp  ${UXARCHIVE} ### "

        ## Mise a jour du timestamp en debut de traitement pour TR18
	Command="date +'%Y-%m-%d-%H.%M.%S.000000' > $fic_tmstmp_tr18_extr_ok; chmod 664 $fic_tmstmp_tr18_extr_ok"
        eval ${Command}
        TEST_ERROR ${?} "Impossible de creer le temoin TR18"
	echo "Verification de la creation du $fic_tmstmp_tr18_extr_ok;"
	Command="ls -lrt"
	eval ${Command}
	
}

STEP3 ()
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

	if [ $exec_scen_CDM_INFOAGT_REFE = "false" ]; then
	#if [ $exec_scen_CDM_INFOAGT_REFE = "true" ]; then
		MESSAGE "Archivage des fichiers du precedent traitement CDM INFOAGENT REFE"
		[ ! -d $rep_sortie/save ] && mkdir $rep_sortie/save
                Command="cd $rep_sortie/infocentre-affe; mv $rep_sortie/infocentre-affe/*.tar.gz $rep_sortie/save"
		eval ${Command}
		TEST_ERROR ${?} "Vidage repertoire infocentre-affe" 

                Command="cd $rep_sortie/infocentre-car; mv $rep_sortie/infocentre-car/*.tar.gz $rep_sortie/save"
                eval ${Command}
		TEST_ERROR ${?} "Vidage repertoire infocentre-car"
                
		Command="cd $rep_sortie/infocentre-fina; mv $rep_sortie/infocentre-fina/*.tar.gz $rep_sortie/save"
		eval ${Command}
		TEST_ERROR ${?} "Vidage repertoire infocentre-fina"

                Command="cd $rep_sortie/infocentre-gda; mv $rep_sortie/infocentre-gda/*.tar.gz $rep_sortie/save"
		eval ${Command}
		TEST_ERROR ${?} "Vidage repertoire infocentre-gda"

                Command="cd $rep_sortie/infocentre-moye; mv $rep_sortie/infocentre-moye/*.tar.gz $rep_sortie/save"
		eval ${Command}
		TEST_ERROR ${?} "Vidage repertoire infocentre-moye"

                Command="cd $rep_sortie/infocentre-papr; mv $rep_sortie/infocentre-papr/*.tar.gz $rep_sortie/save"
		eval ${Command}
		TEST_ERROR ${?} "Vidage repertoire infocentre-papr"

                Command="cd $rep_sortie/infocentre-info; mv $rep_sortie/infocentre-info/*.tar.gz $rep_sortie/save"
		eval ${Command}
		TEST_ERROR ${?} "Vidage repertoire infocentre-info"

                Command="cd $rep_sortie/infocentre-ref; mv $rep_sortie/infocentre-ref/*.tar.gz $rep_sortie/save"
		eval ${Command}
		TEST_ERROR ${?} "Vidage repertoire infocentre-ref"

                Command="cd $rep_sortie/infocentre-sit; mv $rep_sortie/infocentre-sit/*.tar.gz $rep_sortie/save"
		eval ${Command}
		TEST_ERROR ${?} "Vidage repertoire infocentre-sit"

		MESSAGE "Lancement scenario CDM"
		rm -f $rep_declenchement_tr18/CDM/*/*
		touch $rep_declenchement_tr18/CDM/Atraiter/sirhen_moye_${DATE}.dsp
		TEST_ERROR ${?} "Creation du drapeau DSP pour le scenario CDM impossible"

		MESSAGE "Lancement scenario GDA"
		rm -f $rep_declenchement_tr18/GDA/*/*
                touch $rep_declenchement_tr18/GDA/Atraiter/sirhen_gda_${DATE}.dsp
                TEST_ERROR ${?} "Creation du drapeau DSP pour le scenario GDA impossible"

		MESSAGE "Lancement scenario INFOAGENT"
		rm -f $rep_declenchement_tr18/INFOAGENT/*/*
		touch $rep_declenchement_tr18/INFOAGENT/Atraiter/sirhen_infoagent_${DATE}.dsp
		TEST_ERROR ${?} "Creation du drapeau DSP pour le scenario INFOAGENT impossible"
		
		MESSAGE "Lancement scenario REFE"
		rm -f $rep_declenchement_tr18/REFE/*/*
		touch $rep_declenchement_tr18/REFE/Atraiter/sirhen_refe_${DATE}.dsp
		TEST_ERROR ${?} "Creation du drapeau DSP pour le scenario REFE impossible"

	fi

}

STEP4 ()
### objet: Lancement des scenarios                
###
{
        MESSAGE "### $FUNCNAME  Lancement des scenarios  ${UXARCHIVE} ### "

	MESSAGE "scenario infoagent"

 	Command="$start_scen_INFOAGENT & "
        MESSAGE "Lancement de la commande : ${Command} "
        eval ${Command}
	TEST_ERROR ${?} "Erreur sur INFOAGENT!"


	MESSAGE "scenario gda"
	Command="$start_scen_GDA & "
        MESSAGE "Lancement de la commande : ${Command} "
        eval ${Command}
        TEST_ERROR ${?} "Erreur sur GDA!"

	MESSAGE "scenario referentiel"
        Command="$start_scen_REFERENTIEL &  "
        MESSAGE "Lancement de la commande : ${Command} "
        eval ${Command}
        TEST_ERROR ${?} "Erreur sur REFERENTIEL!"

	MESSAGE "scenario calibrage des moyens"
        Command="$start_scen_CALIBRAGE & "
        MESSAGE "Lancement de la commande : ${Command} "
        eval ${Command}
	TEST_ERROR ${?} "Erreur sur CALIBRAGE!"


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
