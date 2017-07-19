#!/bin/sh
###==========================================================================
#@(#) PROCEDURE: 	TR18
#@(#) OBJET: 		Controle des traitement AAF
#@(#)         		...
#@(#) AUTEUR: 		LMU
#@(#) DATE CREATION: 	2015/03/09--10H00
#@(#) MODIFICATIONS: 
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

# Verification de l'initialisation de la variable env
if [ -z $env ]; then
        echo "Erreur grave : Variable env non initialisee"
        exit 1
fi

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

#		arret_aaf
		exit 1
	else
		MESSAGE "\t### Fin valide de traitement."
	fi
}

arret_aaf ()
### objet: Arret des scénarios potentiellement en cours
{
        MESSAGE "Arret scenario AAF"
        DATE=$(date "+%Y%m%d%H%M")
	rm -f $rep_declenchement_tr18/AAF/*/*
        touch $rep_declenchement_tr18/AAF/Atraiter/sirhen_aaf_${DATE}.stop
        TEST_ERROR ${?} "Creation du drapeau STOP pour le scenario AAF impossible"

}

verify_end_AAF ()
{
        declare -i nb=0

        MESSAGE "on source l environnement db2"
        source ~/sqllib/db2profile
        TEST_ERROR ${?} "Sourcage de l environnement DB2 impossible!"

        MESSAGE "on source les parametres de connexion a la base TR18"
        source /mnt/applis_mid_$env/TR18/conf/.db2_SIRHEN_TR18
        TEST_ERROR ${?} "Sourcage des parametres de connexion a la base TR18 impossible!"

        MESSAGE "Connexion a la base TR18"
        db2 connect to $base_TR18 user $usr_TR18 using $mdp_TR18 > /dev/null
        TEST_ERROR ${?} "Probleme de connexion a la base TR18"

	MESSAGE "\tAttente du flag RUN_AAF"
        while [ ! -f $fic_tmstmp_tr18_extr_aaf_ok ]; do
                MESSAGE "\tOn attend 5 minutes avant de retester la mise en place du flag RUN_AAF"
                sleep 300

        done

	DATE_TMSTMP=`date +%Y-%m-%d:%Hh%m`
        echo "Pilotage a trouve le tmstmp a "$DATE_TMSTMP
        
	tmstmp=$(cat $fic_tmstmp_tr18_extr_aaf_ok )
	TEST_ERROR ${?} "Erreur lors de la creation du tmstmp"
	MESSAGE "tmstmp : $tmstmp"
	
	MESSAGE "Requete pour compter les idetat ETR"

        nb=$(db2 -x "select count(idetat) from ex_odi.etattraitement where idetat like '%TR%' and ts_update>'$tmstmp' and IDTYPETRAITEMENT like '%_AAF%'")
        MESSAGE "\t\t Le nombre de traitement d extraction termine est $nb"

	MESSAGE "Requete pour detecter un traitement en erreur les idetat: AST AKO EKO"
        nbko=$(db2 -x "select count(idetat) from ex_odi.etattraitement where ( idetat like '%KO' or idetat = 'AST')  and ts_update>'$tmstmp'  and idtypetraitement like '%_AAF'")
        MESSAGE "\t\t Le nombre de traitements en erreur est $nbko"

        db2 terminate > /dev/null

        TEST_ERROR ${?} "Erreur lors de la deconnexion a la base $base_TR18"
        if [ $nbko -gt 0 ]; then
	#	arret_aaf
                exit 1
        fi


        return $nb
}


STEP0 ()
### objet: Chargement des variables necessaire a l'execution du script	
###	varibales globales statique et dynamique / variable locales statiques
{
	MESSAGE "### $FUNCNAME Chargement des variables globales et locale pour le script $0 de la chaine TR18 ${UXARCHIVE} ### "	

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
### objet: Verification que le traitement d'extraction AAF est completement termine
### Connexion a la base TR18 et verification du nombre de traitements AAF a l etat ETR
{
	MESSAGE "### $FUNCNAME Verification que le traitement d'extraction AAF est completement termine ${UXARCHIVE} ### "	
        MESSAGE "calcul du nombre d extraction OK attendu en fonction des scenarios lances"
        declare -i wait_extr_aaf_ok=0
        echo "exec_scen_AAF = $exec_scen_AAF"
        [ $exec_scen_AAF = "true" ] && wait_extr_aaf_ok=$((wait_extr_aaf_ok + 2))

	declare -i nb_extr_aaf_ok=0
	
	# Calcul du timestamp
	# tmstmp=$(date +'%Y-%m-%d-%H.%M.%S.000000)
	# attendre que les scenarios soient lances
        sleep 300

	verify_end_AAF
	nb_extr_aaf_ok=$?
	MESSAGE "Debut d attente fin execution aaf (environ 15 mn)"
	MESSAGE "\tHoraire  fin estimee : $(date +%Y-%m-%d:%Hh%m.%S -d +15minutes)"
	while [ $nb_extr_aaf_ok -ne $wait_extr_aaf_ok ]; do
		MESSAGE "\tOn attend 5 minutes avant de retester la fin du chargement AAF"
		sleep 300
	
		verify_end_AAF
		nb_extr_aaf_ok=$?
		MESSAGE "\t\t $nb_extr_aaf_ok termines / $wait_extr_aaf_ok attendus"
	done

	arret_aaf

	MESSAGE "\tHoraire de fin reelle : $(date +%Y-%m-%d:%Hh%m)"
	true
	TEST_ERROR ${?} "Erreur impossible"
}

STEP2 ()
### objet: Suppression des PDIR des extractions AAF
### Connexion a la base TR18 et verification du nombre de traitements AAF a l etat ETR
{
        MESSAGE "### $FUNCNAME Suppression des PDIR des extractions AAF ### "
        ###MESSAGE "Verification de la presence du script suppPDIR.sh"
	###[ -x $rep_sortie/annuaire-aaf/suppPDIR.sh ]
	###TEST_ERROR ${?} "Script suppPDIR.sh non trouvédans le repertoire $rep_sortie/annuaire_aaf/"

	MESSAGE "Suppression des PDIR des extractions AAF desactive�"
	###cd $rep_sortie/annuaire-aaf/
	###$rep_sortie/annuaire-aaf/suppPDIR.sh AAF
	###TEST_ERROR ${?} "Erreur lors de la suppression des PDIR des extractions AAF"
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
