#!/bin/sh
###==========================================================================
#@(#) PROCEDURE:        ECHANGE
#@(#) OBJET:            Compte rendu d'execution des scénariosSIRHEN-TR18
#@(#)                   
#@(#) AUTEUR:           LMU
#@(#) DATE CREATION:    2015/04/02--11h06
#@(#) MODIFICATIONS:	JCH 2016/05/13 pour la 6.3
#@(#)			JCH 2016/07/08 supression des flags
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
horodatage=$(date +%Y%m%d%H%M%S)
ordo_exec=1

###===========###
### Parametre ###
###===========###
while getopts ":lane::" opt; do
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
###     Affiche un message dans la log du job et la trace automate
### Requiert:
###     - $1: Message texte
{
        echo -e ${1}
        [ $ordo_exec -eq 1 ] && ${UXEXE}/uxset msg "${1}"
}

TEST_ERROR ()
### objet:
###     Test si il y a une erreur
### Requiert:
###     - $1: Code Retour
###     - $2: Message d'erreur (optionel)
{
        if [ ${1} != 0 ] ; then
                MESSAGE "### Fin anormale de traitement dans STEP${CntStep}"
                MESSAGE "### Code Retour        =${1}"
                MESSAGE "### Msg  Erreur        =${2}"
                exit 1
        else
                MESSAGE "\t### Fin valide de traitement."
        fi
}


MESSAGE "le script est lance par l utilisateur `whoami`"

STEP0 ()
### objet:  Vérification des options de lancement
###
{
        MESSAGE "### $FUNCNAME Verification des options de lancement ${UXARCHIVE} ### "
        ! [ -z $env ]
        TEST_ERROR ${?} "L environnement d execution n est pas connu : Vous devez definir la variable <env>"
}

STEP1 ()
### objet:  Chargement des variables globales et locale
###
{
        MESSAGE "### $FUNCNAME Chargement des variables globales et locale pour le script de la chaine ECHANGE ${UXARCHIVE} ### "
        Command='source /mnt/applis_mid_$env/TR18/conf/global_var_script_tr18'
        MESSAGE "Lancement de la commande : ${Command} "
        eval ${Command}
        TEST_ERROR ${?} "Probleme lors du chargement des variables globales!"

        Command='source /mnt/applis_mid_$env/TR18/conf/local_var_script_tr18_cr_exec'
        MESSAGE "Lancement de la commande : ${Command} "
        eval ${Command}
        TEST_ERROR ${?} "Probleme lors du chargement des variables locales!"

}

STEP2 ()
### objet: Construction de la requete
###
{
        MESSAGE "### $FUNCNAME Construction de la requete sql de verifciation de l'execution des scenarios echanges ${UXARCHIVE} ### "

        MESSAGE "Verification des variables necessaire a l execution du step"
        [ ! -z $rep_sql ]
        TEST_ERROR ${?} "La variable <rep_sql> n'est pas definie!"

        MESSAGE "Verification de la présence de la requete sql modele"
        Command='[ -f  $rep_sql/irhen_exec.sql ]'
        eval ${Command}
        TEST_ERROR ${?} "la requete sql de modele est introuvable!"

        MESSAGE "Construction de la requete"
	sed 's/'"schema_todiwork"'/'"$schema_oditr18"'/g' < $rep_sql/tr18_exec.sql > $rep_sql/${ENV}_tr18_exec.sql

}


STEP3 ()
### objet: Execution de la requete et generation du corps du mail
###
{
        MESSAGE "### $FUNCNAME  Execution de la requete de verification ${UXARCHIVE} ### "

	MESSAGE "Verification de la presence du fichier de requete"
        [ -r $rep_sql/${ENV}_tr18_exec.sql ]
        TEST_ERROR ${?} "La requete sql a executee est introuvable ou non lisible"

        MESSAGE "Chargement de l'environnement db2"
        [ -r ~/sqllib/db2profile ] && source ~/sqllib/db2profile
        TEST_ERROR ${?} "Le profil db2 n a pu etre source"

        MESSAGE "Connexion a la base"
        db2 connect to $base_oditr18
        TEST_ERROR ${?} "Connexion a la base <$base_oditr18> impossible"
set -x
        MESSAGE "\tExecution de la requete et generation du html"
        db2 -txf $rep_sql/${ENV}_tr18_exec.sql -r /tmp/$horodatage.${ENV}_tr18_exec.html
        TEST_ERROR ${?} "Probleme d'execution lors de l'execution de la requete"

        db2 terminate
}


STEP4 ()
### objet: Envoi du mail de compte rendu
###
{
        MESSAGE "### $FUNCNAME Envoi du mail de compte rendu ${UXARCHIVE} ### "

	MESSAGE "Verification du corps du mail pour $scenario"
        [ -r /tmp/$horodatage.${ENV}_tr18_exec.html ]
        TEST_ERROR ${?} "le fichier contenant le corps du message est introuvable"

	(echo "From: TR18-$ENV";
 		echo "To: $mail_dest";
		echo "Subject: [TR18][$ENV] CR Execution scenarios TR18";
		echo "MIME-Version: 1.0";
		echo "Content-Type: text/html";
		echo "Content-Disposition: inline'";
	cat /tmp/$horodatage.${ENV}_tr18_exec.html) | /usr/sbin/sendmail $mail_dest
}

STEP5 ()
### objet: Menage dans les fichiers temporaires
###

{
        MESSAGE "### $FUNCNAME Menage dans les fichiers temporaires ${UXARCHIVE} ### "
        MESSAGE "Suppression sous /tmp des corps de messages de plus de 7 jours"
        find /tmp -name *.${ENV}_tr18_exec.html -ctime +7 -exec rm {} \; 2>/dev/null
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
