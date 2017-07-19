#!/bin/bash
###==========================================================================
#@(#) PROCEDURE: 	TR18-SIRHEN
#@(#) OBJET: 		Restauration de la base SNAPSIRH avec le backup SIRHEN
#@(#)         		...
#@(#) AUTEUR: 		LMU
#@(#) DATE CREATION: 	2015/03/06--09H20
#@(#) MODIFICATIONS: 	JCH 2016/06/20 menage dans les connexions avant la restau SNAPSIRH
#@(#)        		JCH 2016/07/08 suppression des flags
#@(#)
###==========================================================================

### set -x est parametre si la variable S_DEBUG est vraie
[ "${S_DEBUG}" = "true" ] && set -x


###===========###
### Variables ###
###===========###

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

### objet: Chargement des variables necessaire a l'execution du script	
###	varibales globales statique et dynamique / variable locales statiques

{
	MESSAGE "### $FUNCNAME chargement des variables globales et locale pour le script $0 de la chaine TR18 ${UXARCHIVE} ### "	
	Command="source /mnt/applis_mid_$env/TR18/conf/global_var_script_tr18"
	MESSAGE "Lancement de la commande : ${Command} "	
	eval ${Command}
	TEST_ERROR ${?} "Impossible de recuperer ou instancier les variables globales!"
	Command="source /mnt/applis_mid_$env/TR18/conf/local_var_script_snapsirh_restore"
	MESSAGE "Lancement de la commande : ${Command} "	
	eval ${Command}
	TEST_ERROR ${?} "Impossible de recuperer ou instancier les variables locales!"
	
}

STEP1 ()

### objet: Verification du besoin de restauration du backup sirhen vers snapsirh
###     Il y a t il une base SNAPSIRH : variable $exist_snapsirh == true

{
	MESSAGE "### $FUNCNAME   Verification du besoin de restauration du backup sirhen vers snapsirh ${UXARCHIVE} ### "
	MESSAGE "Verification de l'initialisation de la variable exist_snapsirh"

	Command=' [ ! -z $exist_snapsirh ] '
	eval ${Command}

	TEST_ERROR ${?} "Variable exist_snapsirh non definie!"
	if [ "$exist_snapsirh" == false ]; then
		MESSAGE "Pas de base SNAPSIRH sur l'environnement => pas de backup"
		true
		TEST_ERROR ${?} "Erreur improbable"

		MESSAGE ""
        	MESSAGE "### Sortie OK du traitement de l'UPROC $(basename $0)"
       		exit 0
	fi 
}

STEP2 ()

### objet: On verifie la presence de backup SIRHEN sur le montage NFS
###     Commentaire de l etape

{ 
	MESSAGE "### $FUNCNAME On recupere le backup les plus recent et on verifie si on l'a deja consomme ${UXARCHIVE} ### "
	MESSAGE "Verification de l'initialisation de la variable rep_bkp_sirhen"

	Command='[ ! -z $rep_bkp_sirhen ]'
	eval ${Command}
	TEST_ERROR ${?} "Variable rep_bkp_sirhen non definie!"

	Command="ls $rep_bkp_sirhen/$base_source.0.$instance_source*"
	MESSAGE "Verification de la presence de backup SIRHEN"
	eval ${Command}
	TEST_ERROR ${?} "Aucun abcjkup SIRHEN sur le montage nfs"
}

STEP3 ()

### objet: On verifie si le dernier backup SIRHEN a deja ete consomme
###     Commentaire de l etape

{
        MESSAGE "### $FUNCNAME Verification de la consommation eventuelle du dernier backup SIRHEN ${UXARCHIVE} ### "
	MESSAGE "Verification de l'initialisation de la variable rep_bkp_sirhen"

        Command="[ ! -z $rep_bkp_sirhen ]"
        eval ${Command}
        TEST_ERROR ${?} "Variable rep_bkp_sirhen non definie!"

        MESSAGE "Verification de l'initialisation de la variable rep_rest"
        Command="[ ! -z $rep_rest ]"
        eval ${Command}
        TEST_ERROR ${?} "Variable rep_rest non definie!"

        timestamp=$(ls -rt $rep_bkp_sirhen/$base_source.0.$instance_source* | tail -1 | cut -d'.' -f6)
        Command="[ ! -f $rep_rest/$base_source.0.$instance_source*$timestamp* ]"
        MESSAGE "Lancement de la commande : ${Command} "
#       eval ${Command}
#       TEST_ERROR ${?} "Le backup SIRHEN le plus recent a deja servi a restaurer SNAPSIRH"
}


STEP4 ()

### objet: suppression des sauvegardes de SIRHEN archivees en locale
###     stockees sous $rep_rest

{
	MESSAGE "### $FUNCNAME  Suppression des sauvegardes de SIRHEN archivees en locale ${UXARCHIVE}  ### "

        Command="[ ! -z $rep_rest ]"
        eval ${Command}
        TEST_ERROR ${?} "Variable rep_rest non definie!"

        Command="rm -f $rep_rest/$base_source.0.$instance_source*"
        eval ${Command}
        TEST_ERROR ${?} "Variable rep_rest non definie!"
}

STEP5 ()

### objet: Suppression des logs de restauration anterieurs de la base SNAPSIRH
###
     
{
        MESSAGE "### $FUNCNAME  Suppression des logs de restauration anterieurs de la base $base_cible ${UXARCHIVE} ### "

        Command="[ ! -z $rep_rest ]"
        eval ${Command}
        TEST_ERROR ${?} "Variable rep_rest non definie!"

        Command='rm -f $rep_log/*.LOG'
        eval ${Command}
}

STEP6 ()

### objet: recuperation du backup SIRHEN
###

{
        MESSAGE "### $FUNCNAME  Recuperation du backup $base_source ${UXARCHIVE}  ### "

        Command="[ ! -z $rep_bkp_sirhen ]"
        eval ${Command}
        TEST_ERROR ${?} "Variable rep_bkp_sirhen non definie!"

        Command="[ ! -z $rep_rest ]"
        eval ${Command}
        TEST_ERROR ${?} "Variable rep_rest non definie!"

        Command="cp $rep_bkp_sirhen/$base_source.0.$instance_source* $rep_rest"
        eval ${Command}
        TEST_ERROR ${?} "Copie impossible du backup SIRHEN de $rep_bkp_sirhen vers $rep_rest"
}

STEP7 ()

### objet: Sourcage de l'environnement db2
###

{
        MESSAGE "### $FUNCNAME   Sourcage de l'environnement db2 ${UXARCHIVE}  ### "
	Command='source ~/sqllib/db2profile'
        eval ${Command}
        TEST_ERROR ${?} "impossible de sourcer l'environnement db2"
}

STEP8 ()

### objet: Desactivation de la base SNAPSIRH pour restauration
###

{
        MESSAGE "### $FUNCNAME  Desactivation de la base SNAPSIRH pour restauration ${UXARCHIVE}  ### "

	Command=' [ ! -z $base_cible ] '
	eval ${Command}
	TEST_ERROR ${?} "Variable base_cible non definie!"

        db2 deactivate db $base_cible

	## bouchon pour continuer meme si erreur
	true
        TEST_ERROR ${?} "Desactivation impossible de la base $base_cible"
        
        db2 connect to $base_cible
        TEST_ERROR ${?} "Connexion impossible a la base $base_cible"
        
	true

        db2 force application all
        MESSAGE "### force application all ... ***"
        sleep 10

        
}

STEP9 ()

### objet: Restauration phase 1: redirect generate script
###

{
        MESSAGE "### $FUNCNAME  Restauration phase 1/5: redirect generate script ${UXARCHIVE} ### "
        db2 "restore db $base_source from $rep_rest taken at $timestamp dbpath on $rep_base into $base_cible logtarget '$rep_log' replace existing redirect generate script $rep_rest/redirect_$base_cible.clp without prompting"
        TEST_ERROR ${?} "Suppression impossible de la base $base_cible"
}

STEP10 ()

### objet: Restauration phase 2: remplacement instance source et base source par instance cible et base cible dans le fichier redirect_SNAPSIRH.clp
###

{
        MESSAGE "### $FUNCNAME  Restauration phase 2/5: Modification du generate script ${UXARCHIVE} ### "
        MESSAGE "remplacement instance source et base source par instance cible et base cible"
        sed '29,$ s/'"$instance_source\/$base_source\/$instance_source"'/'"$instance_cible\/$base_cible\/$instance_cible"'/g' < $rep_rest/redirect_$base_cible.clp > $rep_rest/redirect.clp
        TEST_ERROR ${?} "Modification du script de generation de la base $base_cible impossible"
}

STEP11 ()

### objet: Restauration phase 3: restauration a partir du fichier redirect.clp
{

        MESSAGE "### $FUNCNAME  Restauration phase 3/5: restauration a partir du fichier redirect.clp ${UXARCHIVE} ### "
        Command='db2 -tvf $rep_rest/redirect.clp'
        eval ${Command}
	## il faut gerer le code retour qui n'est pas de 0 mais 2 car la base est en rollforward pending
	## cf return sqlcode sur site ibm
	true
        TEST_ERROR ${?} "restauration croisee de la base $base_cible en erreur"
}

STEP12 ()

### objet: Restauration phase 4: recuperation aval

{

        MESSAGE "### $FUNCNAME  Restauration phase 4/5: recuperation aval ${UXARCHIVE} ### "
	Command='db2 "rollforward db $base_cible to end of logs and stop overflow log path ($rep_log) noretrieve"'
        eval ${Command}
        TEST_ERROR ${?} "Rollforward de la base $base_cible en erreur"
}

STEP13 ()

### objet: Activation de la base $base_cible

{

        MESSAGE "### $FUNCNAME Activation de la base $base_cible ${UXARCHIVE} ### "
        Command='db2 "activate db $base_cible"'
        eval ${Command}
        TEST_ERROR ${?} "Activation impossible de la base $base_cible suite a sa restauration"
}

STEP14 ()

### objet: OPERATION DE POST resaturation
### modification de la description de la base
### modification du logarmeth

{
        MESSAGE "### $FUNCNAME Operation de post restauration de la $base_cible ${UXARCHIVE} ### "
        db2 "change database $base_cible comment with 'Snapshot base $base_source source'"
	db2 connect to $base_cible
        TEST_ERROR ${?} "connexion impossible a la base $base_cible"

	MESSAGE "Application des grants sur la base $base_cible"
	cd /mnt/applis_mid_$env/shell_commun/db2/tr18/
	/mnt/applis_mid_$env/shell_commun/db2/tr18/snapsirh_grant.sh
	MESSAGE "Fin du passage des grants sur la base $base_cible"
	MESSAGE ""
        MESSAGE "FIN des operations de post restauration de la base $base_cible"
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

#####################################################################################
        echo -e "\n\nFin OK de la restore de SNAPSIRH RU3 sur db2itr18 : "`date`
	## Recuperation de la derniere log
        trace=`ls -rt /mnt/applis_mid_ru3/TR18/logs/TR18_TLQTD_SIRHEN_6.3_SNAPSIRH_RESTORE_db203_db2itr18*|tail -1`
        /bin/mail -s "ru3-sir-db203.sirhen.hp.in.phm.education.gouv.fr : Plateforme RU3 : Fin de la restore OK de la base SNAPSIRH RU3 sur db2itr18 : `date` " sirhen-itp@education.gouv.fr < $trace

        #/bin/mail -s "$(hostname) : Fin OK de la restore de SNAPSIRH RU3 sur db2itr18 : `date` " sirhen-itp@education.gouv.fr
#####################################################################################

fi

MESSAGE ""
MESSAGE "### Toutes les etapes sont terminees ### "
exit 0
