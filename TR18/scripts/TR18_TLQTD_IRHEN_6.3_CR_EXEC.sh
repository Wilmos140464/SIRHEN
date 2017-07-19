#!/bin/sh
###==========================================================================
#@(#) PROCEDURE:        TR18
#@(#) OBJET:            Compte rendu d'execution du chargement national et acad√©mique
#@(#)                   Script qui s'appuie sur un fichier sql formatant le r‚??sultat en html
#@(#) AUTEUR:           LMU
#@(#) DATE CREATION:    2015/04/07--11H20
#@(#) MODIFICATIONS:    JCH 2016/05/13 pour la 6.3
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
horodatage=$(date +%Y%m%d%H%M%S)
ordo_exec=1

###===========###
### Parametre ###
###===========###
while getopts ":lane::" opt; do
        ###echo "getopts a trouv√© l'option $opt"
        case $opt in
                l)
                        ordo_exec=0
			env=""
			scenario=""
                ;;
                e)
                        env=$( echo ${OPTARG} | tr [A-Z] [a-z])
                ;;
		a)
			scenario=IGD
		;;
		n)
			scenario=ISN
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

STEP0 ()
### objet:  V√©rification des options de lancement
###
{
        MESSAGE "### $FUNCNAME Verification des options de lancement ${UXARCHIVE} ### "
        if [ -z $scenario ]; then
		MESSAGE "Le scenario a valider n est pas connu : on executera pour ISN et IGD"
	else
		MESSAGE "Le scenario a valider est $scenario"
	fi
	true
        TEST_ERROR ${?} "Le scenario n'est pas connu : Vous devez definir la variable <scenario>"
exit 0
}

STEP1 ()
### objet:  Chargement des variables globales et locale
###
{
        MESSAGE "### $FUNCNAME Chargement des variables globales et locale pour le script de la chaine TR18 ${UXARCHIVE} ### "
        Command='source /mnt/applis_mid_$env/TR18/conf/global_var_script_tr18'
        MESSAGE "Lancement de la commande : ${Command} "
        eval ${Command}
        TEST_ERROR ${?} "Message d erreur!"

        Command='source /mnt/applis_mid_$env/TR18/conf/local_var_script_irhen_cr_exec'
        MESSAGE "Lancement de la commande : ${Command} "
        eval ${Command}
        TEST_ERROR ${?} "Message d erreur!"

}

STEP2 ()
### objet: Construction de la requete
###     
{
        MESSAGE "### $FUNCNAME Construction de la requete sql de verifciation de l'execution du scenario ${UXARCHIVE} ### "

        MESSAGE "Verification des variables necessaire a l execution du step"
        [ ! -z $rep_sql ]
        TEST_ERROR ${?} "La variable <rep_sql> n'est pas definie!"

        MESSAGE "Verification de la pr√©sence de la requete sql modele"
        Command='[ -f  $rep_sql/irhen_exec.sql ]'
        eval ${Command}
        TEST_ERROR ${?} "la requete sql de modele est introuvable!"

	MESSAGE "Construction de la requete"


	timestamp_ref=$(cat /mnt/applis_mid_${env}/TR18/ordonnanceur/040_irhen_cp_ok_timestamp)
	echo "DEBUG TIMEREF= $timestamp_ref"

	if [ -z $scenario ]; then
		sed 's/traitement/IGD/g' < $rep_sql/irhen_exec.sql > $rep_sql/${ENV}_irhen_IGD_exec.sql
		sed -i 's/schema/'"$schema"'/g' $rep_sql/${ENV}_irhen_IGD_exec.sql
		sed -i 's/TIME_REFERENCE/'"$timestamp_ref"'/g' $rep_sql/${ENV}_irhen_IGD_exec.sql

		sed 's/traitement/ISN/g' < $rep_sql/irhen_exec.sql > $rep_sql/${ENV}_irhen_ISN_exec.sql
		echo "DEBUG schema = $schema"
		sed -i 's/schema/'"$schema"'/g' $rep_sql/${ENV}_irhen_ISN_exec.sql
		sed -i 's/TIME_REFERENCE/'"$timestamp_ref"'/g' $rep_sql/${ENV}_irhen_ISN_exec.sql
	else
		sed 's/traitement/'"$scenario"'/g' < $rep_sql/irhen_exec.sql > $rep_sql/${ENV}_irhen_${scenario}_exec.sql
		sed -i 's/schema/'"$schema"'/g' $rep_sql/${ENV}_irhen_${scenario}_exec.sql
		sed -i 's/TIME_REFERENCE/'"$timestamp_ref"'/g' $rep_sql/${ENV}_irhen_${scenario}_exec.sql
	fi
}


STEP3 ()
### objet: Execution de la requete et generation du corps du mail
###
{
	MESSAGE "### $FUNCNAME 	Execution de la requete de verification ${UXARCHIVE} ### "
	
	if [ -z $scenario ]; then
        	MESSAGE "Verification de la presence des fichiers de requete"
	        [ -f $rep_sql/${ENV}_irhen_ISN_exec.sql -a -f $rep_sql/${ENV}_irhen_IGD_exec.sql ]
        	TEST_ERROR ${?} "La requete sql a executee est introuvable"

	        MESSAGE "Chargement de l'environnement db2"
        	[ -r ~/sqllib/db2profile ] && source ~/sqllib/db2profile
	        TEST_ERROR ${?} "Le profil db2 n a pu etre source"

	        MESSAGE "Connexion a la base"
	        db2 connect to $base
	        TEST_ERROR ${?} "Connexion a la base <$base> impossible"

		MESSAGE "\tExecution de la requete et generation du html pour IGD"
		db2 -txf $rep_sql/${ENV}_irhen_IGD_exec.sql -r /tmp/$horodatage.${ENV}_irhen_IGD_exec.html
		TEST_ERROR ${?} "Probleme d'execution lors de l'execution de la requete" 

		MESSAGE "\tExecution de la requete et generation du html pour ISN"
		db2 -txf $rep_sql/${ENV}_irhen_ISN_exec.sql -r /tmp/$horodatage.${ENV}_irhen_ISN_exec.html
		TEST_ERROR ${?} "Probleme d'execution lors de l'execution de la requete" 
	
	else
	        MESSAGE "Verification de la presence du fichier de requete"
        	[ -f $rep_sql/${ENV}_irhen_${scenario}_exec.sql ]
	        TEST_ERROR ${?} "La requete sql a executee est introuvable"

        	MESSAGE "Chargement de l'environnement db2"
	        [ -r ~/sqllib/db2profile ] && source ~/sqllib/db2profile
        	TEST_ERROR ${?} "Le profil db2 n a pu etre source"

	        MESSAGE "Connexion a la base"
        	db2 connect to $base
	        TEST_ERROR ${?} "Connexion a la base <$base> impossible"

		MESSAGE "\tExecution de la requete et generation du html pour $scenario"
		db2 -txf $rep_sql/${ENV}_irhen_${scenario}_exec.sql -r /tmp/$horodatage.${ENV}_irhen_${scenario}_exec.html
		TEST_ERROR ${?} "Probleme d'execution lors de l'execution de la requete" 
	fi
	db2 terminate
}


STEP4 ()
### objet: Envoi du mail de compte rendu
###
{
	MESSAGE "### $FUNCNAME Envoi du mail de compte rendu ${UXARCHIVE} ### "

	if [ -z $scenario ]; then
		MESSAGE "Verification du corps du mail pour ISN"
		MESSAGE "Verification du corps du mail"
                [ -r /tmp/$horodatage.${ENV}_irhen_ISN_exec.html ]
                TEST_ERROR ${?} "le fichier contenant le corps du message est introuvable"

                MESSAGE "Envoi du mail de compte rendu"
                (echo "From: IRHEN_ISN-$ENV";
                 echo "To: $mail_dest";
                 echo "Subject: [IRHEN-ISN][$ENV] CR ExÈcution scÈnarios IRHEN ISN";
                 echo "MIME-Version: 1.0";
                 echo "Content-Type: text/html";
                 echo "Content-Disposition: inline'";
                cat /tmp/$horodatage.${ENV}_irhen_ISN_exec.html) | /usr/sbin/sendmail $mail_dest
                TEST_ERROR ${?} "Probleme lors de l'envoi du mail : verifier les destinataires"

		 MESSAGE "Verification du corps du mail pour IGD"
                MESSAGE "Verification du corps du mail"
                [ -r /tmp/$horodatage.${ENV}_irhen_IGD_exec.html ]
                TEST_ERROR ${?} "le fichier contenant le corps du message est introuvable"

                MESSAGE "Envoi du mail de compte rendu"
                (echo "From: IRHEN_IGD-$ENV";
                 echo "To: $mail_dest";
                 echo "Subject: [IRHEN-IGD][$ENV] CR ExÈcution scÈnarios IRHEN IGD";
                 echo "MIME-Version: 1.0";
                 echo "Content-Type: text/html";
                 echo "Content-Disposition: inline'";
                cat /tmp/$horodatage.${ENV}_irhen_IGD_exec.html) | /usr/sbin/sendmail $mail_dest
                TEST_ERROR ${?} "Probleme lors de l'envoi du mail : verifier les destinataires"
	
	else

		MESSAGE "Verification du corps du mail pour $scenario"
		[ -r /tmp/$horodatage.${ENV}_irhen_${scenario}_exec.html ]
		TEST_ERROR ${?} "le fichier contenant le corps du message est introuvable"

		MESSAGE "Envoi du mail de compte rendu"
		(echo "From: IRHEN_$scenario-$ENV";
		 echo "To: $mail_dest";
		 echo "Subject: [IRHEN][$ENV] CR ExÈcution scÈnarios IRHEN $scenario";
		 echo "MIME-Version: 1.0";
		 echo "Content-Type: text/html";
		 echo "Content-Disposition: inline'";
		cat /tmp/$horodatage.${ENV}_irhen_${scenario}_exec.html) | /usr/sbin/sendmail $mail_dest
	
		TEST_ERROR ${?} "Probleme lors de l'envoi du mail : verifier les destinataires"
	fi

}

STEP5 ()
### objet: Menage dans les fichiers temporaires
###

{
	MESSAGE "### $FUNCNAME Menage dans les fichiers temporaires ${UXARCHIVE} ### "
	MESSAGE "Suppression sous /tmp des corps de messages de plus de 7 jours"
	find /tmp -name *.$ENV_irhen_IR*__exec.html -ctime +7 -exec rm {} \; 2>/dev/null
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
