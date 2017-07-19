#!/bin/sh
###==========================================================================
#@(#) PROCEDURE: 	TR18
#@(#) OBJET: 		Copie des fichiers extrait par ODI de SIRHEN sur le NFS
#@(#)         		...
#@(#) AUTEUR: 		LMU
#@(#) DATE CREATION: 	2015/03/09--10H00
#@(#) MODIFICATIONS:	JCH 2016/05/13 pour la 6.3 
#@(#)			JCH 2016/07/08 suppression des flags
#@(#)			JCH 2016/09/09 ajout de la recopie sur le nfs irhen
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
		
	#	arreter_tr18
		exit 1
	else
		MESSAGE "\t### Fin valide de traitement."
	fi
}


arreter_tr18 ()
### objet: Arret des scénarios potentiellement en cours
{
	DATE=`date "+%Y%m%d%H%M"`
        MESSAGE "Arret des scenario CDM $DATE"
	rm -f $rep_declenchement_tr18/CDM/Atraiter/*
        touch $rep_declenchement_tr18/CDM/Atraiter/sirhen_moye_${DATE}.stop
        TEST_ERROR ${?} "Creation du drapeau STOP pour le scenario CDM impossible"

        MESSAGE "Arret scenario GDA "
	rm -f $rep_declenchement_tr18/GDA/Atraiter/*
        touch $rep_declenchement_tr18/GDA/Atraiter/sirhen_gda_${DATE}.stop
        TEST_ERROR ${?} "Creation du drapeau STOP pour le scenario GDA impossible"

        MESSAGE "Arret scenario INFOAGENT"
	rm -f $rep_declenchement_tr18/INFOAGENT/Atraiter/*
        touch $rep_declenchement_tr18/INFOAGENT/Atraiter/sirhen_infoagent_${DATE}.stop
        TEST_ERROR ${?} "Creation du drapeau STOP pour le scenario INFOAGENT impossible"

        MESSAGE "Arret scenario REFE"
	rm -f $rep_declenchement_tr18/REFE/Atraiter/*
        touch $rep_declenchement_tr18/REFE/Atraiter/sirhen_refe_${DATE}.stop
        TEST_ERROR ${?} "Creation du drapeau STOP pour le scenario REFE impossible"

}

verif_debut ()
{
	#Tant que les scenarios TR18_ALM n'ont pas demarres, on attend.
	MESSAGE "on source l environnement db2"
        source ~/sqllib/db2profile
        TEST_ERROR ${?} "Sourcage de l environnement DB2 impossible!"

        MESSAGE "on source les parametres de connexion a la base TR18"
        source /mnt/applis_mid_$env/TR18/conf/.db2_SIRHEN_TR18
        TEST_ERROR ${?} "Sourcage des parametres de connexion a la base TR18 impossible!"

        MESSAGE "Connexion a la base TR18"
        db2 connect to $base_TR18 user $usr_TR18 using $mdp_TR18 > /dev/null
        TEST_ERROR ${?} "Probleme de connexion a la base TR18"

	tmstmp=$(cat $fic_tmstmp_tr18_extr_ok)
	MESSAGE "tmstmp : $tmstmp"

	declare -i nb_debut=0
	while [ $nb_debut -eq 0 ]
  	do
    		sleep 10
        	nb_debut=$(db2 -x "select count (IDETAT) from ex_odi.etattraitement where  IDETAT not like '%TR' and ts_update > '$tmstmp' and idtypetraitement not like '%_LDAP' and idtypetraitement not like '%_AAF'")
    		let "cpt_agi = $cpt_agi + 1"
		MESSAGE "Test : $cpt_agi / 10"
    		if [ $cpt_agi -eq 10 ]; then
			 TEST_ERROR $cpt_agi "*** Aucun scenario ALM demarre "
  	  	fi
  	done
db2 terminate > /dev/null
MESSAGE "Au moins $nb_debut traitements en cours pour $tmstmp, traitement bien demarre"

}
verify_end_TR18 ()
{
        declare -i nb=0
	declare -i nbko=0

        MESSAGE "on source l environnement db2"
        source ~/sqllib/db2profile
        TEST_ERROR ${?} "Sourcage de l environnement DB2 impossible!"

        MESSAGE "on source les parametres de connexion a la base TR18"
        source /mnt/applis_mid_$env/TR18/conf/.db2_SIRHEN_TR18
        TEST_ERROR ${?} "Sourcage des parametres de connexion a la base TR18 impossible!"

        MESSAGE "Connexion a la base TR18"
        db2 connect to $base_TR18 user $usr_TR18 using $mdp_TR18 > /dev/null
        TEST_ERROR ${?} "Probleme de connexion a la base TR18"

        MESSAGE "Requete pour compter les idetat ETR"
        tmstmp=$(cat $fic_tmstmp_tr18_extr_ok)
        nb=$(db2 -x "select count(idetat) from ex_odi.etattraitement where idetat like '%TR%' and ts_update>'$tmstmp' and idtypetraitement not like '%_LDAP' and idtypetraitement not like '%_AAF'")
	TEST_ERROR ${?} "Erreur lors de la recuperation du nb de traitement d extraction termine"
        MESSAGE "\t\t Le nombre de traitement d extraction termine est $nb"

	MESSAGE "Requete pour detecter un traitement en erreur les idetat: AST AKO EKO"
	nbko=$(db2 -x "select count(idetat) from ex_odi.etattraitement where ( idetat like '%KO' or idetat = 'AST')  and ts_update>'$tmstmp' and idtypetraitement not like '%_LDAP' and idtypetraitement not like '%_AAF'")
	TEST_ERROR ${?} "Erreur lors de la recuperation du nb de traitement en erreur"
	MESSAGE "\t\t Le nombre de traitements en erreur est $nbko"


        db2 terminate > /dev/null

        TEST_ERROR ${?} "Erreur lors de la deconnexion a la base $base_TR18"
	if [ $nbko -gt 0 ]; then
		#arreter_tr18
		exit 1
	fi

        return $nb
}
#### Redresser mvtdif
#redresser_mvtdif ()
#{
#	MESSAGE "Redresser mvt diff : $1"
#	awk -F "|" '{print $1 "|" $2 "|" $3 "|" $4 "|" $5 "|" $6 "|" $9 "|" $7 "|" $8}'	$1 > $1.corr
#	mv  -f $1.corr $1

#}

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
### objet: Copie des fichiers de TR18 du local vers le NFS
###
{
        MESSAGE "### $FUNCNAME  Copie des fichiers du local vers le NFS TR18 ${UXARCHIVE} ### "
        MESSAGE "Verification de la declaration de la variable rep_tr18_nfs"
        Command=" [ ! -z $rep_tr18_nfs ]"
        eval ${Command}
        TEST_ERROR ${?} "Variable rep_tr18_nfs non definie"
        MESSAGE "rep irhen : $rep_tr18_nfs"


        MESSAGE "Verification de la declaration de la variable rep_sortie"
        Command=" [ ! -z $rep_sortie ]"
        eval ${Command}
        TEST_ERROR ${?} "Variable rep_sortie non definie"

        # supprimer les anciens fichiers
        MESSAGE "Suppression des fichiers extr odi SIRHEN archives"
        Command="rm -f ${rep_tr18_nfs}/save/*"
        eval ${Command}
        TEST_ERROR ${?} "Probleme lors de la suppression des archives des fichiers odi SIRHEN"

        # deplacer les fichiers de la veille dans le repertoire save
        MESSAGE "Archivage des fichiers extr odi SIRHEN utilise par la precedente execution"
        #mkdir ${rep_tr18_nfs}/save
        Command="mv ${rep_tr18_nfs}/sirhen* ${rep_tr18_nfs}/save/ 2>/dev/null"
        eval ${Command}
        if [ $? -ne 0 ]; then
                MESSAGE "\t Warning : aucun fichier a archiver sur le nfs"
        else
                true
                TEST_ERROR ${?} "Probleme lors de l archivage des fichiers extr odi SIRHEN"
        fi

        # copier les fichiers de rep_sortie sur le partage nfs
        MESSAGE "Copie des fichiers odi infocentre-affe sur le NFS"
        Command="cp ${rep_sortie}/infocentre-affe/* ${rep_tr18_nfs} 2>/dev/null"
        eval ${Command}
        if [ $? -ne 0 ]; then
                MESSAGE "\t Warning : aucun fichier a copier"
        else
                true
                TEST_ERROR ${?} "Probleme de copie des fichiers sur le NFS"
        fi

        MESSAGE "Copie des fichiers odi infocentre-car sur le NFS"
        Command="cp ${rep_sortie}/infocentre-car/* ${rep_tr18_nfs} 2>/dev/null"
        eval ${Command}
        if [ $? -ne 0 ]; then
                MESSAGE "\t Warning : aucun fichier a copier"
        else
                true
                TEST_ERROR ${?} "Probleme de copie des fichiers sur le NFS"
        fi

        MESSAGE "Copie des fichiers odi infocentre-fina sur le NFS"
        Command="cp ${rep_sortie}/infocentre-fina/* ${rep_tr18_nfs} 2>/dev/null"
        eval ${Command}
        if [ $? -ne 0 ]; then
                MESSAGE "\t Warning : aucun fichier a copier"
        else
                true
                TEST_ERROR ${?} "Probleme de copie des fichiers sur le NFS"
        fi

        MESSAGE "Copie des fichiers odi infocentre-moye sur le NFS"
        Command="cp ${rep_sortie}/infocentre-moye/* ${rep_tr18_nfs} 2>/dev/null"
        eval ${Command}
        if [ $? -ne 0 ]; then
                MESSAGE "\t Warning : aucun fichier a copier"
        else
                true
                TEST_ERROR ${?} "Probleme de copie des fichiers sur le NFS"
        fi

        MESSAGE "Copie des fichiers odi infocentre-papr sur le NFS"
        Command="cp ${rep_sortie}/infocentre-papr/* ${rep_tr18_nfs} 2>/dev/null"
        eval ${Command}
	 if [ $? -ne 0 ]; then
                MESSAGE "\t Warning : aucun fichier a copier"
        else
                true
                TEST_ERROR ${?} "Probleme de copie des fichiers sur le NFS"
        fi

        MESSAGE "Copie des fichiers odi infocentre-info sur le NFS"
        Command="cp ${rep_sortie}/infocentre-info/* ${rep_tr18_nfs} 2>/dev/null"
        eval ${Command}
        if [ $? -ne 0 ]; then
                MESSAGE "\t Warning : aucun fichier a copier"
        else
                true
                TEST_ERROR ${?} "Probleme de copie des fichiers sur le NFS"
        fi

        MESSAGE "Copie des fichiers odi infocentre-ref sur le NFS"
        Command="cp ${rep_sortie}/infocentre-ref/* ${rep_tr18_nfs} 2>/dev/null"
        eval ${Command}
        if [ $? -ne 0 ]; then
                MESSAGE "\t Warning : aucun fichier a copier"
        else
                true
                TEST_ERROR ${?} "Probleme de copie des fichiers sur le NFS"
        fi

        MESSAGE "Copie des fichiers odi infocentre-sit sur le NFS"
        Command="cp ${rep_sortie}/infocentre-sit/* ${rep_tr18_nfs} 2>/dev/null"
        eval ${Command}
        if [ $? -ne 0 ]; then
                MESSAGE "\t Warning : aucun fichier a copier"
        else
                true
                TEST_ERROR ${?} "Probleme de copie des fichiers sur le NFS"
        fi

        MESSAGE "Copie des fichiers odi infocentre-gda sur le NFS"
        Command="cp ${rep_sortie}/infocentre-gda/* ${rep_tr18_nfs} 2>/dev/null"
        eval ${Command}
        if [ $? -ne 0 ]; then
                MESSAGE "\t Warning : aucun fichier a copier"
        else
                true
                TEST_ERROR ${?} "Probleme de copie des fichiers sur le NFS"
        fi

}

STEP2 ()
### objet: Copie des fichiers de TR18 du local vers le NFS Irhen
###	Ajout temporaire en attendant que les scripts irhen utilisent le meme nfs
{
        DATE_TAR=`date "+%Y%m%d"`
        MESSAGE "### $FUNCNAME  Copie des fichiers du local vers le serveur de transfert ### "
        MESSAGE "Verification de la declaration de la variable rep_irhen_nfs"
        Command=' [ ! -z $rep_irhen_nfs ]'
        eval ${Command}
        TEST_ERROR ${?} "Variable rep_irhen_nfs non definie"
        MESSAGE "rep irhen : $rep_irhen_nfs"

        MESSAGE "Verification de la declaration de la variable rep_sortie"
        MESSAGE "rep sortie : $rep_sortie"
        Command=' [ ! -z $rep_sortie ]'
        eval ${Command}
        TEST_ERROR ${?} "Variable rep_sortie non definie"

        # tar l'arbo  les fichies de rep_sortie
        MESSAGE "tar des fichiers odi infocentre, debut "
        Command="date"
        eval ${Command}
        Command="cd $rep_sortie"
        eval ${Command}

        Command="pwd"
        eval ${Command}

        Command="mkdir ${rep_tar_odi}/tar_a_livrer"
        eval ${Command}

        Command="find info*/  \( -name '*.dat' -o -name '*.ctl' -o -name '*.ctr' \) -exec cp {} ${rep_tar_odi}/tar_a_livrer/ \;"
        eval ${Command}
        TEST_ERROR ${?} "Erreur: remplissage repertoire tar_a_livrer"

        Command="cd ${rep_tar_odi}/tar_a_livrer"
        eval ${Command}

        MESSAGE "Generation du tar"
        Command="pwd"
        eval ${Command}

        #Command="tar czvf ${rep_tar_odi}/${nom_tar_odi}_${DATE_TAR}.tar.gz . --exclude save --exclude annuaire-af --exclude annuaire-ldap --exclude ${nom_tar_odi}_${DATE_TAR}.tar.gz"
        #eval ${Command}
        #TEST_ERROR ${?} "Erreur: creation du tar"

        MESSAGE ${?} "Erreur non trappee : retournée par la commande tar"

        Command="cd .. ; rm -rf ${rep_tar_odi}/tar_a_livrer"
        eval ${Command}

        MESSAGE "tar créé, debut envoi : "
        Command="date"
        eval ${Command}

        MESSAGE "Copie vers le serveur SFTP"
        #Command=" echo 'put ${rep_tar_odi}/${nom_tar_odi}_${DATE_TAR}.tar.gz ${rep_upload_odi}/depot_racine/' | sftp ${compte_upload_odi}@transfert.in.phm.education.gouv.fr "
        #eval ${Command}
        #TEST_ERROR ${?} "Erreur: retournée par la commande put"
        MESSAGE "Fin copie vers le serveur SFTP :"
        Command="date"
        eval ${Command}

        MESSAGE "Copie vers le serveur SFTP du temoin"
        touch $mnt_irhen/TR18/ordonnanceur/tar_sirhen_irhen_ok_`date "+%Y%m%d"`
        Command=" ls -lrt $mnt_irhen/TR18/ordonnanceur"
        eval ${Command}
        MESSAGE "Envoi du flag de la Copie vers le serveur SFTP"
        Command=" echo 'put $mnt_irhen/TR18/ordonnanceur/tar_sirhen_irhen_ok_`date "+%Y%m%d"` ${rep_upload_odi}/depot_racine/' | sftp ${compte_upload_odi}@transfert.in.phm.education.gouv.fr "
        eval ${Command}
        TEST_ERROR ${?} "Erreur: retournée par la commande put apres lenvoi du flag"
	cd $rep_sortie/infocentre-affe*
        tar czvf infocentre-affe.tar.gz .
        sleep 5

        cd $rep_sortie/infocentre-car
        tar czvf infocentre-car.tar.gz .
        sleep 5

        cd $rep_sortie/infocentre-fina
        tar czvf infocentre-fina.tar.gz .
        sleep 5

        cd $rep_sortie/infocentre-gda
        tar czvf infocentre-gda.tar.gz .
        sleep 5

        cd $rep_sortie/infocentre-moye
        tar czvf infocentre-moye.tar.gz .
        sleep 5

        cd $rep_sortie/infocentre-papr
        tar czvf infocentre-papr.tar.gz .
        sleep 5

        cd $rep_sortie/infocentre-info
        tar czvf infocentre-info.tar.gz .
        sleep 5

        cd $rep_sortie/infocentre-ref
        tar czvf infocentre-ref.tar.gz .
        sleep 5

        cd $rep_sortie/infocentre-sit
        tar czvf infocentre-sit.tar.gz .
        sleep 5
		
	Command="cd  $rep_sortie; rm -f infocentre*/*.dat infocentre*/*.ctl infocentre*/*.ctr"
	eval ${Command}

        true
        TEST_ERROR ${?} "Erreur impossible"


}

STEP3 ()
### objet: Verification que le traitement d'extraction TR18 est completement termine
### Connexion a la base TR18 et verification du nombre de traitements TR18_EXTR a l etat ETR
{
        MESSAGE "### $FUNCNAME Mettre a jour les drapeaux pour IRHEN ${UXARCHIVE} ### "
	#assurer la compatibilitéavec la 6.2
	rm -rf $mnt_irhen/TR18/ordonnanceur/*
	touch $mnt_irhen/TR18/ordonnanceur/033_tr18_cp_ok
	touch $mnt_irhen/TR18/ordonnanceur/01_sirhen_bkp_ok

	arreter_tr18

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
