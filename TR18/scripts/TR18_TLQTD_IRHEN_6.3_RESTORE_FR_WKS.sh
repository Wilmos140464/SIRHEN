#!/bin/sh
###==========================================================================
#@(#) PROCEDURE: 	TR18
#@(#) OBJET: 		Restauration de la abse IRHEN a partir backup irhenwks
#@(#)         		...
#@(#) AUTEUR: 		LMU
#@(#) DATE CREATION: 	2015/03/10--14H20
#@(#) MODIFICATIONS:    JCH 2016/07/08 suppression des flags
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
timestamp_irhen=2015
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
### objet:  Chargement des variables globales et locale	
###
{
	MESSAGE "### $FUNCNAME Chargement des variables globales et locale pour le script de la chaine TR18 ${UXARCHIVE} ### "	
	Command='source /mnt/applis_mid_$env/TR18/conf/global_var_script_tr18'
	MESSAGE "Lancement de la commande : ${Command} "	
	eval ${Command}
	TEST_ERROR ${?} "Message d erreur!"

	Command='source /mnt/applis_mid_$env/TR18/conf/local_var_script_irhen_restore_from_irhenwks'
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
                MESSAGE "Pas de base IRHENWKS sur l'environnement => pas de restore"

                MESSAGE ""
                MESSAGE "### Sortie OK du traitement de l'UPROC $(basename $0)"
                exit 0
        fi	
}

STEP2 ()
### objet: Verification de la presence d un backup IRHENWKS sur le NFS
###        Afin d eviter que plusieurs scripts s executent en parralele
{
        MESSAGE "### $FUNCNAME Verification de la presence d un backup IRHENWKS sur le NFS  ${UXARCHIVE} ###"

	MESSAGE "Verification de l'initialisation des variables"
	[ ! -z $rep_bkp_irhenwks ]
        TEST_ERROR ${?} "Variable rep_bkp_irhenwks non definie!"
        [ ! -z $base_source ]
        TEST_ERROR ${?} "Variable base_source non definie!"
        [ ! -z $instance_source ]
        TEST_ERROR ${?} "Variable instance_source non definie!"

	MESSAGE "Verification de la presence de backup sur le NFS"
	ls $rep_bkp_irhenwks/$base_source.0.$instance_source* 2>/dev/null
	TEST_ERROR ${?} "aucun backup $base_source sur le NFS"

        MESSAGE "Recuperation du timestamp du backup $base_source le plus recent"
        timestamp_irhen=$(ls -rt $rep_bkp_irhenwks/$base_source.0.$instance_source* | tail -1 | cut -d'.' -f6)
        [ ${#timestamp_irhen} -gt 0 ]
        TEST_ERROR ${?} "Le timestamp du dernier backup $base_source est errone"
}

STEP3 ()
### objet : Verification si le backup de la base IRHENWKS a deja ete consome 
###
{
	MESSAGE "### $FUNCNAME  Verification si le backup de la base IRHENWKS a deja ete consomme ${UXARCHIVE} ###"

	MESSAGE "Verification de l'initialisation des variables"
	[ ! -z $rep_rest ]
	TEST_ERROR ${?} "Variable rep_rest non definie!"
	[ ! -z $base_source ]
        TEST_ERROR ${?} "Variable base_source non definie!"
        [ ! -z $instance_source ]
        TEST_ERROR ${?} "Variable instance_source non definie!"

	MESSAGE " Verification si le backup de la base IRHENWKS a deja ete consomme"
	ls $rep_rest/$base_source.0.$instance_source*$timestamp_irhen* 2> /dev/null 
	if [ $? -eq 0 ]; then
		false
		TEST_ERROR ${?} "Le dernier backup present sur le NFS a deja ete consome!!"
	else
		true
		TEST_ERROR ${?} "Erreur impossible"
	fi
		
	
}


STEP4 ()
### objet: Copie du backup IRHENWKS du NFS en local
###
{
	MESSAGE "### $FUNCNAME Copie du backup IRHENWKS du NFS en local ${UXARCHIVE} ### "

        MESSAGE "Verification de l'initialisation des variables"
        [ ! -z $rep_rest ]
        TEST_ERROR ${?} "Variable rep_rest non definie!"
	[ ! -z $rep_bkp_irhenwks ]
        TEST_ERROR ${?} "Variable rep_bkp_irhenwks non definie!"

	MESSAGE "Suppression des anciennes sauvegardes locales de IRHENWKS"
	Command='rm -f $rep_rest/$base_source.0.$instance_source*'
	eval ${Command}
        TEST_ERROR ${?} "Erreur lors de la suppression des anciens sauveagrdes lcoales"

	MESSAGE "Copie du backup  IRHENWKS du NFS en local"
	Command='cp $rep_bkp_irhenwks/$base_source.0.$instance_source* $rep_rest/'
	eval ${Command}
        TEST_ERROR ${?} "probleme lors de la copie du backup IRHENWKS" 
}

STEP5 ()
### objet: desactivation de la base IRHEN
###
{
	MESSAGE "### $FUNCNAME Desactivation de la base IRHEN  ${UXARCHIVE} ### "

        MESSAGE "Verification de l'initialisation des variables"
        [ ! -z $base_cible ]
        TEST_ERROR ${?} "Variable base_cible non definie!"

	MESSAGE "Coupure des connexions a la base $base_cible"
	db2 force application all
	TEST_ERROR ${?} "Coupure des connexions actives sur la base $base_cible impossible"

	MESSAGE "desactivation de la base $base_cible"
	db2 deactivate db $base_cible
	TEST_ERROR ${?} "Desactivation de la base $base_cible impossible!!"
}

STEP6 ()
### objet: suppression de la base irhen
###
{
	MESSAGE "### $FUNCNAME Suppression de la base irhen ${UXARCHIVE} ### "

	MESSAGE "Verification de l'initialisation des variables"
        [ ! -z $base_cible ]
        TEST_ERROR ${?} "Variable base_cible non definie!"

	MESSAGE "Suppression de la base $base_cible"
	db2 drop db $base_cible
	TEST_ERROR ${?} "Suppression de la base $base_cible impossible!!"	
}

STEP7 ()
### objet: restauration de la base IRHEN
###
{
	MESSAGE "### $FUNCNAME RESTAURATION DE LA BASE IRHEN  ${UXARCHIVE} ### "

        MESSAGE "Verification de l'initialisation des variables"
        [ ! -z $rep_base ]
        TEST_ERROR ${?} "Variable rep_base non definie!"
        [ ! -z $base_source ]
        TEST_ERROR ${?} "Variable base_source non definie!"
        [ ! -z $instance_source ]
        TEST_ERROR ${?} "Variable instance_source non definie!"
	
        [ ! -z $rep_rest ]
        TEST_ERROR ${?} "Variable rep_rest non definie!"
        [ ! -z $timestamp_irhen ]
        TEST_ERROR ${?} "Variable timestamp_irhen non definie!"
        [ ! -z $base_cible ]
        TEST_ERROR ${?} "Variable base_cible non definie!"
        [ ! -z $instance_cible ]
        TEST_ERROR ${?} "Variable instance_cible non definie!"

	MESSAGE "Restauration phase 1: redirect generate script"
	db2 "restore db $base_source from $rep_rest taken at $timestamp_irhen dbpath on $rep_base into $base_cible replace history file replace existing redirect generate script $rep_rest/redirect_$base_cible.clp  without rolling forward without prompting"
	TEST_ERROR ${?} "Restauration PHASE1 en erreur"
	### sleep 60

	MESSAGE "Restauration phase 2 : modification du fichier clp cree en phase1"
	sed '29,$ s/'"$instance_source\/$base_source\/$instance_source"'/'"$instance_cible\/$base_cible\/$instance_cible"'/g' < $rep_rest/redirect_$base_cible.clp > $rep_rest/redirect.clp
	TEST_ERROR ${?} "Restauration PHASE2 en erreur"

	MESSAGE "Restauration phase 3: restauration a partir du fichier redirect.clp"
	db2 -tvf $rep_rest/redirect.clp
        ## il faut gerer le code retour qui n'est pas de 0 mais 2 car la base est en rollforward pending
        ## cf return sqlcode sur site ibm
        true

	TEST_ERROR ${?} "Restauration PHASE3 en erreur"
}

STEP8 ()
### Activation de la base
{
        MESSAGE "### $FUNCNAME  activation de la base IRHEN  ${UXARCHIVE} ### "

        MESSAGE "Verification de l'initialisation des variables"
        [ ! -z $base_cible ]
        TEST_ERROR ${?} "Variable base_cible non definie!"

        MESSAGE "Activation de la base $base_cible"
        db2 activate db $base_cible
        TEST_ERROR ${?} "Erreur d activation de la base $base_cible!!"
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
