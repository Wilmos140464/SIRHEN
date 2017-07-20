!/bin/bash
###==========================================================================
#@(#) PROCEDURE: 	TRG_FDAS-TRG_FDAS
#@(#) OBJET: 		Restauration de la base TRG_FDAS de SAU avec le backup TRG_FDAS de PR3
#@(#) AUTEUR: 		BG
#@(#) DATE CREATION: 	2017/01/09
#@(#)
###==========================================================================

### set -x est parametre si la variable S_DEBUG est vraie
[ "${S_DEBUG}" = "true" ] && set -x

echo -e "\n\nD�but de la restore de TRG_FDAS PR3 sur TRG_FDAS de $env : "`date`

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
		### envoi mail avec message d'erreur
		## Recuperation de la derniere log
	        trace=`ls -rt /mnt/applis_mid_sau/SIRHEN/logs/TRG_FDAS_TLQTD_SIRHEN_6.3_TRG_FDAS-SAU_RESTORE_db203_db2itr18*|tail -1`
       		/bin/mail -s "sau-sir-db203.sirhen.hp.in.phm.education.gouv.fr : Plateforme SAU : Restore KO de la base Echange PR3 sur Echange SAU : `date` " sirhen-itp@education.gouv.fr < $trace


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
	
	Command="source /mnt/applis_mid_$env/SIRHEN/conf/global_var_script_trg_fdas"
	MESSAGE "Lancement de la commande : ${Command} "	
	eval ${Command}
	TEST_ERROR ${?} "Impossible de recuperer ou instancier les variables globales!"

	Command="source /mnt/applis_mid_$env/SIRHEN/conf/local_var_script_trg_fdas_restore"
	MESSAGE "Lancement de la commande : ${Command} "	
	eval ${Command}
	TEST_ERROR ${?} "Impossible de recuperer ou instancier les variables locales!"
	
}

echo -e "\n\nFin du step0 restore sur $env : "`date`

STEP1 ()

### objet: Verification du besoin de restauration du backup TRG_FDAS vers TRG_FDAS $env
###     Y-a-t-il une base ECHANGE : variable $exist_trg_fdas == true

{
	MESSAGE "### $FUNCNAME   Verification du besoin de restauration du backup TRG_FDAS vers TRG_FDAS de $env ${UXARCHIVE} ### "
	MESSAGE "Verification de l'initialisation de la variable exist_trg_fdas"

	Command=' [ ! -z $exist_trg_fdas ] '
	eval ${Command}
	TEST_ERROR ${?} "Variable exist_trg_fdas non definie!"

	if [ "$exist_trg_fdas" == false ]; then
		MESSAGE "Pas de base TRG_FDAS sur l'environnement $env => pas de backup"
		true
		TEST_ERROR ${?} "Erreur improbable"

		MESSAGE ""
        	MESSAGE "### Sortie OK du traitement de l'UPROC $(basename $0)"
       		exit 0
	fi 
}

echo -e "\n\nFin du step1 restore sur $env : "`date`

STEP2 ()

### objet: On verifie la presence de backup  TRG_FDAS sur le montage NFS /mnt/backup/GENERE_SUR_PR3
###     Commentaire de l etape

{ 
	MESSAGE "### $FUNCNAME On recupere le backup les plus recent et on verifie si on l'a deja consomme ${UXARCHIVE} ### "
	MESSAGE "Verification de l'initialisation de la variable rep_bkp_sirhen"

	Command='[ ! -z $rep_bkp_sirhen ]'
	eval ${Command}
	TEST_ERROR ${?} "Variable rep_bkp_sirhen non definie!"

	Command="ls $rep_bkp_sirhen/$base_source.0.$instance_source*"
	MESSAGE "Verification de la presence de backup TRG_FDAS"
	eval ${Command}
	TEST_ERROR ${?} "Aucun abcjkup TRG_FDAS sur le montage nfs"
}

echo -e "\n\nFin du step2 restore sur $env : "`date`

STEP3 ()

### objet: On verifie si le dernier backup TRG_FDAS a deja ete consomme
###     Commentaire de l etape

{
        MESSAGE "### $FUNCNAME Verification de la consommation eventuelle du dernier backup TRG_FDAS ${UXARCHIVE} ### "
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
#        eval ${Command}
#        TEST_ERROR ${?} "Le backup TRG_FDAS le plus recent a deja servi a restaurer TRG_FDAS de $env"

}

echo -e "\n\nFin du step3 restore sur $env : "`date`

STEP4 ()

### objet: suppression des sauvegardes de TRG_FDAS archives en local
###     stockees sous $rep_rest

{
	MESSAGE "### $FUNCNAME  Suppression des sauvegardes de TRG_FDAS archivees en locale ${UXARCHIVE}  ### "

        Command="[ ! -z $rep_rest ]"
        eval ${Command}
        TEST_ERROR ${?} "Variable rep_rest non definie!"

        Command="rm -f $rep_rest/$base_source.0.$instance_source*"
        eval ${Command}
        TEST_ERROR ${?} "Variable rep_rest non definie!"
}

echo -e "\n\nFin du step4 restore sur $env : "`date`

STEP5 ()

### objet: Suppression des logs de restauration anterieurs de la base TRG_FDAS
###
     
{
        MESSAGE "### $FUNCNAME  Suppression des logs de restauration anterieurs de la base $base_cible ${UXARCHIVE} ### "

        Command="[ ! -z $rep_rest ]"
        eval ${Command}
        TEST_ERROR ${?} "Variable rep_rest non definie!"

        Command='rm -f $rep_log/*.LOG'
        eval ${Command}
}

echo -e "\n\nFin du step5 restore sur $env : "`date`

STEP6 ()

### objet: recuperation du backup TRG_FDAS
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
        TEST_ERROR ${?} "Copie impossible du backup TRG_FDAS de $rep_bkp_sirhen vers $rep_rest"
}

echo -e "\n\nFin du step6 sur $env : "`date`

STEP7 ()

### objet: Sourcage de l'environnement db2
###

{
        MESSAGE "### $FUNCNAME   Sourcage de l'environnement db2 ${UXARCHIVE}  ### "
	Command='source ~/sqllib/db2profile'
        eval ${Command}
        TEST_ERROR ${?} "impossible de sourcer l'environnement db2"
}

echo -e "\n\nFin du step7 restore sur $env : "`date`

STEP8 ()

### objet: Desactivation de la base TRG_FDAS pour restauration
###

{
        MESSAGE "### $FUNCNAME  Desactivation de la base TRG_FDAS $env pour restauration ${UXARCHIVE}  ### "

	Command=' [ ! -z $base_cible ] '
	eval ${Command}
	TEST_ERROR ${?} "Variable base_cible non definie!"

        db2 deactivate db $base_cible
	## bouchon pour continuer meme si erreur
	true
        TEST_ERROR ${?} "Desactivation impossible de la base $base_cible"
        
        db2 connect to $base_cible
	true
        TEST_ERROR ${?} "Connexion impossible a la base $base_cible"
        
        db2 force application all
        MESSAGE "### force application all ... ***"
        sleep 10
        
}

echo -e "\n\nFin du step8 restore sur $env : "`date`

STEP9 ()

### objet: Restauration phase 1: redirect generate script
###

{

        MESSAGE "### $FUNCNAME  Restauration phase 1/5: redirect generate script ${UXARCHIVE} ### "

        db2 "restore db $base_source from $rep_rest taken at $timestamp dbpath on $rep_base into $base_cible replace existing redirect generate script $rep_rest/redirect_$base_cible.clp without prompting"

        TEST_ERROR ${?} "Suppression impossible de la base $base_cible"
}

echo -e "\n\nFin du step9 restore sur $env : "`date`

STEP10 ()

### objet: Restauration phase 2: remplacement instance source et base source par instance cible et base cible dans le fichier redirect_SIRHEN.clp
###

{
        MESSAGE "### $FUNCNAME  Restauration phase 2/5: Modification du generate script ${UXARCHIVE} ### "
        MESSAGE "remplacement instance source et base source par instance cible et base cible"

        sed '29,$ s/'"$instance_source\/$base_source\/$instance_source"'/'"$instance_cible\/$base_cible\/$instance_cible"'/g' < $rep_rest/redirect_$base_cible.clp > $rep_rest/redirect.clp

        TEST_ERROR ${?} "Modification du script de generation de la base $base_cible impossible"
}

echo -e "\n\nFin du step10 restore sur $env : "`date`


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

echo -e "\n\nFin du step11 restore sur SAU : "`date`

STEP12 ()

### objet: Restauration phase 4: Sauvegarde à froid, donc pas de logs en attente
{

        MESSAGE "### $FUNCNAME  Restauration phase 4/5: lever la recuperation aval en attente ${UXARCHIVE} ### "
        Command='db2 "rollforward db $base_cible complete"'
        eval ${Command}
        TEST_ERROR ${?} "Rollforward de la base $base_cible en erreur"
}

echo -e "\n\nFin du step12 restore sur $env : "`date`


STEP13 ()

### objet: Activation de la base $base_cible

{

        MESSAGE "### $FUNCNAME Activation de la base $base_cible ${UXARCHIVE} ### "

        Command='db2 "activate db $base_cible"'

        eval ${Command}
        TEST_ERROR ${?} "Activation impossible de la base $base_cible suite a sa restauration"
}

echo -e "\n\nFin du step13 restore sur $env : "`date`

STEP14 ()

### objet: OPERATION DE POST restauration
### modification de la description de la base
### modification du logarmeth

{
        MESSAGE "### $FUNCNAME Operation de post restauration de la $base_cible ${UXARCHIVE} ### "

        db2 "change database $base_cible comment with 'Snapshot base $base_source source'"

	MESSAGE "Application des grants sur la base $base_cible"
	echo "========================================================"
	cd /db2data/$instance_cible/shell/grants
        echo "exceution du script grant_uSUPERVISION_db2-9.x_v1.1.sh"
	echo "========================================================"
	./grant_uSUPERVISION_db2-9.x_v1.1.sh TRG_FDAS racdb2 poledb2 
	echo "========================================================"
	echo "exceution du script grant_specif_ECHANGE.sh"
	echo "========================================================"
	./grant_specif_ECHANGE.sh 
	echo "========================================================"
	echo "exceution du script grant_group_v5_SIRHEN.sh"
	echo "========================================================"
	./grant_group_v5_SIRHEN.sh TRG_FDAS setlsirh C
	echo "========================================================"
	echo "exceution du script CreateGrantsETL_v1.2.1.sh"
	echo "========================================================"
	./CreateGrantsETL_v1.2.1.sh -b trg_fdas
	echo "========================================================"
	db2 connect to $base_cible
	db2 "grant CREATETAB on database to group setlsirh"  
	db2 terminate
	
	MESSAGE "Fin du passage des grants sur la base $base_cible"

}

echo -e "\n\nFin du step12 restore sur $env : "`date`


STEPFIN ()

###  
### STEP DE FIN
### 

{
	MESSAGE ""
        MESSAGE "FIN des operations de restauration de la base $base_cible sur l'environnement $env"
}

echo -e "\n\nFin du stepfin restore sur $env : "`date`

### ----------------------------------------------------------------------------
### Mettre ici chaque bloc de step (au format STEPn ())

#set -x

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

        echo -e "\n\nFin de la restore OK de la base Echange  PR3 sur Echange de SAU : "`date`

        ## Recuperation de la derniere log
	trace=`ls -rt /mnt/applis_mid_sau/SIRHEN/logs/TRG_FDAS_TLQTD_SIRHEN_6.3_TRG_FDAS-SAU_RESTORE_db203_db2itr18*|tail -1`
        /bin/mail -s "sau-sir-db203.sirhen.hp.in.phm.education.gouv.fr : Plateforme SAU : Fin de la restore OK de la base Echange PR3 sur Echange SAU : `date` " sirhen-itp@education.gouv.fr < $trace

echo "FIN"

fi

MESSAGE ""
MESSAGE "### Toutes les etapes sont terminees ### "

exit 0
