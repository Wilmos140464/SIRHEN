#!/bin/sh
###==========================================================================
#@(#) PROCEDURE: 	TR18
#@(#) OBJET: 		Maj table ODI.ETATTRAITEMENT
#@(#)         		...
#@(#) AUTEUR: 		WMO
#@(#) DATE CREATION: 	2017/02/21--10H00
#@(#) MODIFICATIONS:	 
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
		
	#	arreter_tr18
		exit 1
	else
		MESSAGE "\t### Fin valide de traitement."
	fi
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
### objet: Maj de la table ex_odi.etattraitement
###     
{

	 MESSAGE "on source l environnement db2"
        source ~/sqllib/db2profile
        TEST_ERROR ${?} "Sourcage de l environnement DB2 impossible!"

        MESSAGE "on source les parametres de connexion a la base TR18"
        source /mnt/applis_mid_$env/TR18/conf/.db2_SIRHEN_TR18
        TEST_ERROR ${?} "Sourcage des parametres de connexion a la base TR18 impossible!"

        MESSAGE "Connexion a la base TR18"
        db2 connect to $base_TR18 user $usr_TR18 using $mdp_TR18 > /dev/null
        TEST_ERROR ${?} "Probleme de connexion a la base TR18"

        MESSAGE "Maj de la table ex_odi.etattraitement"
        nb=$(db2 -x "update ex_odi.etattraitement SET IDETAT='ATR' where idtypetraitement like 'ALM_%' and idtypetraitement not like '%_LDAP' and idtypetraitement not like '%_AAF'";)
        nbcommit=$(db2 -x "commit")


        TEST_ERROR ${?} "Erreur lors de la recuperation du nb de traitement d extraction termine"
        MESSAGE "\t\t Le nombre de traitement d extraction termine est $nb"


        db2 terminate > /dev/null

        TEST_ERROR ${?} "Erreur lors de la deconnexion a la base $base_TR18"


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
