incorrect_usage()
{
	echo "Usage: $0: [-map] <apps password> <system password> <WLS Admin PW> <file system> <New SYSADMIN Password> <Clone Source SID> <New Apps PW Number>"
	echo m - Run Middle Tier Clone only
	echo a - Run CM Tier Clone only
	echo p - Run Change apps password only
	exit
}

usage()
{
        params=$#
        if [ $params != 7 ] && [ $params != 8 ]
        then
		incorrect_usage
        fi
        if [ $params = 8 ]
        then
                options=$1
		correct_usage=0
                if [ `expr "$options" : '^-'` != 1 ]
                then
			incorrect_usage
                fi
                if [ `expr "$options" : '-[a-z]*[m]'` != 0 ]
                then
                	g_appl=0
                	g_middle=1
                	g_changeappspw=0
                        echo "Will not run APPL Clone Part"
			correct_usage=1
		fi
                if [ `expr "$options" : '-[a-z]*[a]'` != 0 ]
                then
                	g_appl=1
                	g_middle=0
                	g_changeappspw=0
                        echo "Will not run Middle Tier Clone Part"
			correct_usage=1
		fi
                if [ `expr "$options" : '-[a-z]*[p]'` != 0 ]
                then
                	g_appl=0
                	g_middle=0
                	g_changeappspw=1
                        echo "Will just Change the apps password"
			correct_usage=1
		fi
		if [ correct_usage = 0 ]
		then
			incorrect_usage
                fi
                g_appspw=$2
                g_syspw=$3
		g_wls_admin=$4
		g_fs=$5
                g_sysadminpw=$6
                g_sourcesid=$7
                g_new_appspw_number=$8
        fi
        if [ $params = 7 ]
        then
                options=$1
                if [ `expr "$options" : '^-'` = 1 ]
		then
			incorrect_usage
		fi
                g_appl=1
                g_middle=1
                g_changeappspw=1
                g_appspw=$1
                g_syspw=$2
		g_wls_admin=$3
		g_fs=$4
                g_sysadminpw=$5
                g_sourcesid=$6
                g_new_appspw_number=$7
                echo "Will run APPL Clone Part and Middle Tier Clone"
        fi
}

check_lockfile()
{
	if [ -f $g_lockfile ]
	then
		echo "Cannot Run process as it may be running already, found lockfile $g_lockfile"
		exit
	else
		touch $g_lockfile
	fi
}

remove_lockfile()
{
	if [ -f $g_lockfile ]
	then
		rm $g_lockfile
	fi
}

user_type()
{
        user=`id`
        found_user=0
        case $user in
        (*ap*test*)
                echo "Clone Process for for TEST Appl Instance"
                found_user=1
                g_pp=`id|cut -d'(' -f2|cut -d')' -f1|sed 's/appltest//g'`
                g_user_type=TEST;;
        (*ap*trn*)
                echo "Clone Process for for TRN Appl Instance"
                found_user=1
                g_pp=`id|cut -d'(' -f2|cut -d')' -f1|sed 's/appltrn//g'`
                g_user_type=TRN;;
        (*ap*ple*)
                echo "Clone Process for for PLE Appl Instance"
                found_user=1
                g_pp=`id|cut -d'(' -f2|cut -d')' -f1|sed 's/apple//g'`
                g_user_type=PLE;;
        (*ap*pte*)
                echo "Clone Process for for PTE Appl Instance"
                g_pp=`id|cut -d'(' -f2|cut -d')' -f1|sed 's/applpte//g'`
                found_user=1
                g_user_type=PTE;;
        (*ora*)
                echo "Run this script as the Appl User"
                found_user=1
                exit 1;;
        esac
        if [ $found_user = 0 ]
        then
                echo "Invalid User to run this script from"
                exit 1
        fi
}

kill_processes_before_start()
{
	for proc in `ps -fu $LOGNAME|grep -vi 'clone'|grep 'apps'|cut -c1-50|awk '{print $2}'`
	do
		kill -9 $proc
	done
}

determine_base()
{
        if [ ${#g_pp} = 2 ]
        then
                ppnz=`echo $g_pp|cut -c2`
        else
                ppnz=$g_pp
        fi
        echo DEBUG: g_pp=$g_pp ppnz=$ppnz

	if [ $g_user_type = 'TEST' ]
        then
                g_base=/test$g_pp/apps/RMTEST$g_pp
        fi
        if [ $g_user_type = 'TRN' ]
        then
                g_base=/trn$g_pp/apps/RMTRN$g_pp
        fi
        if [ $g_user_type = 'PLE' ]
        then
                g_base=/ora/ple$g_pp/apps/RMPLE$ppnz
        fi
        if [ $g_user_type = 'PTE' ]
        then
                if [ $ORACLE_SID = 'PTE2' ]
                then
                        g_base=/ora/pte2/apps/RMPTE2
                else
                        g_base=/ora/pte/apps/RMPTE
                fi
        fi
}

check_status()
{
	status=$1
	stage=$2
	if [ $status = 0 ]
	then
		echo "****Stage $stage completed Successfully ****"
	else
		echo "****Stage $stage completed but had errors, it completed with status $status.  Exiting...... ****"
		remove_lockfile
		exit $status
	fi
}

check_file_exists()
{
	file_to_check=$1
	if [ ! -f $file_to_check ]
	then
		echo "Cannot find $file_to_check"
		remove_lockfile
		exit
	else
		echo "Found file $file_to_check"
	fi
}

check_files()
{
	check_file_exists $g_contextfile
}

repair_symbolic_links()
{		
	cd $g_base/fs1/EBSapps/appl/xxsop/12.0.0
	rm out dmig in installs tmp
	ln -s $g_base/fs_ne/EBSapps/appl/xxsop/12.0.0/out out
	ln -s $g_base/fs_ne/EBSapps/appl/xxsop/12.0.0/dmig dmig
	ln -s $g_base/fs_ne/EBSapps/appl/xxsop/12.0.0/in in
	ln -s $g_base/fs_ne/EBSapps/appl/xxsop/12.0.0/installs installs
	ln -s $g_base/fs_ne/EBSapps/appl/xxsop/12.0.0/tmp tmp
	cd $g_base/fs1/EBSapps/appl/xxdwp/12.0.0
	rm fj in installs interface migration out
	ln -s $g_base/fs_ne/EBSapps/appl/xxdwp/12.0.0/fj fj
	ln -s $g_base/fs_ne/EBSapps/appl/xxdwp/12.0.0/in in
	ln -s $g_base/fs_ne/EBSapps/appl/xxdwp/12.0.0/installs installs
	ln -s $g_base/fs_ne/EBSapps/appl/xxdwp/12.0.0/interface interface
	ln -s $g_base/fs_ne/EBSapps/appl/xxdwp/12.0.0/migration migration
	ln -s $g_base/fs_ne/EBSapps/appl/xxdwp/12.0.0/out out
	cd $g_base/fs2/EBSapps/appl/xxsop/12.0.0
	rm out dmig in installs tmp
	ln -s $g_base/fs_ne/EBSapps/appl/xxsop/12.0.0/out out
	ln -s $g_base/fs_ne/EBSapps/appl/xxsop/12.0.0/dmig dmig
	ln -s $g_base/fs_ne/EBSapps/appl/xxsop/12.0.0/in in
	ln -s $g_base/fs_ne/EBSapps/appl/xxsop/12.0.0/installs installs
	ln -s $g_base/fs_ne/EBSapps/appl/xxsop/12.0.0/tmp tmp
	cd $g_base/fs2/EBSapps/appl/xxdwp/12.0.0
	rm fj in installs interface migration out
	ln -s $g_base/fs_ne/EBSapps/appl/xxdwp/12.0.0/fj fj
	ln -s $g_base/fs_ne/EBSapps/appl/xxdwp/12.0.0/in in
	ln -s $g_base/fs_ne/EBSapps/appl/xxdwp/12.0.0/installs installs
	ln -s $g_base/fs_ne/EBSapps/appl/xxdwp/12.0.0/interface interface
	ln -s $g_base/fs_ne/EBSapps/appl/xxdwp/12.0.0/migration migration
	ln -s $g_base/fs_ne/EBSapps/appl/xxdwp/12.0.0/out out
	cd $g_base/fs_ne/EBSapps/appl/xxsop/12.0.0
	rm bin
	ln -s $g_base/fs1/EBSapps/appl/xxsop/12.0.0/bin bin
}

point_inventory()
{
        inventory=$1
        if [ ${#g_pp} = 2 ]
        then
                ppnz=`echo $g_pp|cut -c2`
        else
                ppnz=$g_pp
        fi
        echo DEBUG: g_pp=$g_pp ppnz=$ppnz
        if [ $g_user_type = 'TEST' ]
        then
                if [ $inventory = 'O' ]
                then
                        echo "inventory_loc=/test"$g_pp"/data/rmtest"$g_pp"db/oraInventory11204" > /var/opt/oracle/oraInst.loc
                fi
                if [ $inventory = 'A' ]
                then
			mv /test"$g_pp"/apps/RMTEST"$g_pp"/oraInventory /test"$g_pp"/apps/RMTEST"$g_pp"/oraInventory.$dt
			mkdir /test"$g_pp"/apps/RMTEST"$g_pp"/oraInventory 
                        echo "inventory_loc=/test"$g_pp"/apps/RMTEST"$g_pp"/oraInventory" > /test"$g_pp"/apps/RMTEST"$g_pp"/oraInventory/oraInst.loc
                fi
        fi
        if [ $g_user_type = 'TRN' ]
        then
                if [ $inventory = 'O' ]
                then
                        echo "inventory_loc=/trn"$g_pp"/data/rmtrn"$g_pp"db/oraInventory11204" > /var/opt/oracle/oraInst.loc
                fi
                if [ $inventory = 'A' ]
                then
                        mv /trn"$g_pp"/apps/RMTRN"$g_pp"/oraInventory /trn"$g_pp"/apps/RMTRN"$g_pp"/oraInventory.$dt
                        mkdir /trn"$g_pp"/apps/RMTRN"$g_pp"/oraInventory 
                        echo "inventory_loc=/trn"$g_pp"/apps/RMTRN"$g_pp"/oraInventory" > /trn"$g_pp"/apps/RMTRN"$g_pp"/oraInventory/oraInst.loc
                fi
        fi
        if [ $g_user_type = 'PLE' ]
        then
                if [ $inventory = 'O' ]
                then
                        echo "inventory_loc=/ora/ple"$g_pp"/data/rmple"$ppnz"db/oraInventory11204" > /var/opt/oracle/oraInst.loc
                fi
                if [ $inventory = 'A' ]
                then
                        mv /ora/ple"$g_pp"/apps/RMPLE"$ppnz"/oraInventory /ora/ple"$g_pp"/apps/RMPLE"$ppnz"/oraInventory.$dt
                        mkdir /ora/ple"$g_pp"/apps/RMPLE"$ppnz"/oraInventory
                        echo "inventory_loc=/ora/ple"$g_pp"/apps/RMPLE"$ppnz"/oraInventory" > /ora/ple"$g_pp"/apps/RMPLE"$ppnz"/oraInventory/oraInst.loc
                        echo DEBUG: "inventory_loc=/ora/ple"$g_pp"/apps/RMPLE"$ppnz"/oraInventory"
                fi

        fi
        if [ $g_user_type = 'PTE' ]
        then
                if [ $inventory = 'O' ]
                then
                        echo "inventory_loc=/pte"$g_pp"/data/rmpte"$g_pp"db/oraInventory11204" > /var/opt/oracle/oraInst.loc
                fi
                if [ $inventory = 'A' ]
                then
                        mv /pte"$g_pp"/apps/oraInventory /pte"$g_pp"/apps/oraInventory.$dt
                        mkdir /pte"$g_pp"/apps/oraInventory 
                        echo "inventory_loc=/pte"$g_pp"/apps/oraInventory" > /pte"$g_pp"/apps/oraInventory/oraInst.loc
                fi
        fi
}

empty_fmw_home()
{
	echo Moving Aside FMW_HOME
        if [ $g_user_type = 'TEST' ]
	then
		fmw_home1=/test$g_pp/apps/RMTEST$g_pp/fs1/FMW_Home
		fmw_home2=/test$g_pp/apps/RMTEST$g_pp/fs2/FMW_Home
	fi
        if [ $g_user_type = 'TRN' ]
	then
		fmw_home1=/trn$g_pp/apps/RMTRN$g_pp/fs1/FMW_Home
		fmw_home2=/trn$g_pp/apps/RMTRN$g_pp/fs2/FMW_Home
	fi
        if [ $g_user_type = 'PLE' ]
	then
		fmw_home1=/ora/ple"$g_pp"/apps/RMPLE"$ppnz"/fs1/FMW_Home
		fmw_home2=/ora/ple"$g_pp"/apps/RMPLE"$ppnz"/fs2/FMW_Home
	fi
	mv $fmw_home1 ${fmw_home1}_$dt	
	mv $fmw_home2 ${fmw_home2}_$dt	
}

run_clone_run()
{
set +
	oraclesid=$ORACLE_SID
	echo Pairsfile is "$exe_home/pairs/${oraclesid}_addnode_pairsfile_adminnode.txt"
        export TEMP=/var/tmp
        export PATH=$PATH:/usr/ucb:/usr/ccs/bin
	export TIMEDPROCESS_TIMEOUT=-1
        export CONFIG_JVM_ARGS="-Xms1024m -Xmx2048m -XX:-UseGCOverheadLimit"
	cd $g_base/fs1/EBSapps/comn/clone/bin
	{ echo $g_appspw; echo $g_wls_admin; }|perl adcfgclone.pl component=appsTier pairsfile=$exe_home/pairs/${oraclesid}_addnode_pairsfile_adminnode.txt addnode=no 
	check_status $? "Admin Node Clone Run"
}

run_clone_patch()
{
        #Copy Inst Top to fs2
        backup_contextfile=$g_backupdir/$ORACLE_SID"_"$g_server.xml
        echo "Copying $g_base/fs1/inst to $g_base/fs2/inst"
        cp -r $g_base/fs1/inst $g_base/fs2/inst
        #Copy Backup Context File to fs2
        g_fs2_context_file=`echo $CONTEXT_FILE|sed "s%$RUN_BASE%$PATCH_BASE%g"`
        check_file_exists ${backup_contextfile}_fs2
        echo "Copying ${backup_contextfile}_fs2 to $g_fs2_context_file"
        cp ${backup_contextfile}_fs2 $g_fs2_context_file
        check_file_exists $g_fs2_context_file
        #Register Context File
        echo $g_appspw | $ADJVAPRG oracle.apps.ad.autoconfig.oam.CtxSynchronizer action=upload contextfile=$g_fs2_context_file logfile=/tmp/${oraclesid}_patchctxupload.log
        export TEMP=/var/tmp
        export PATH=$PATH:/usr/ucb:/usr/ccs/bin
        export TIMEDPROCESS_TIMEOUT=-1
        { echo $g_appspw; echo $g_syspw; echo $g_wls_admin; }|adop phase=fs_clone force=yes
        check_status $? "Admin Node Clone Patch"
}

restore_files()
{
	backup_contextfile=$g_backupdir/$ORACLE_SID"_"$g_server.xml
	check_file_exists $backup_contextfile
	cp $CONTEXT_FILE ${CONTEXT_FILE}.backup_after_clone_process
##	cp $backup_contextfile $CONTEXT_FILE
        backup_adadmindefs=$g_backupdir/adadmindefs.txt
        [[ -f $backup_adadmindefs ]] && cp -p $backup_adadmindefs ${g_appl_top}/admin/${TWO_TASK}
}

install_templates()
{
	cd /stage/Cloning_templates/dwp_templates_R122
	/stage/Cloning_templates/dwp_templates_R122/installat.sh 
}

stop_services()
{
	cd $ADMIN_SCRIPTS_HOME
	adstpall.sh apps/$g_appspw << EOF
apps
$g_appspw
$g_wls_admin
EOF
	#check_status $? "Stopping Services"
}

run_pre_clone()
{
	echo Running Preclone....
	$exe_home/run_preclone_appl_r122.sh $g_appspw $g_wls_admin
	check_status $? "Running Pre-clone"
}

run_postclone()
{
	echo Running Postclone Script....
	$XXDWP_TOP/bin/xxdwp_postclone.sh $g_appspw $g_syspw $g_sysadminpw $g_sourcesid
	check_status $? "Running Post clone"
}

run_autoconfig()
{
	cd $ADMIN_SCRIPTS_HOME
	adautocfg.sh appspass=$g_appspw
	check_status $? "Running Autoconfig"
}

add_middle_tier_test()
{
        oraclesid=$ORACLE_SID
        contextfile=$CONTEXT_FILE
        if [ $oraclesid = 'RMTEST19' ] || [ $oraclesid = 'RMTEST18' ] || [ $oraclesid = 'RMTEST24' ] || [ $oraclesid = 'RMTEST26' ]
        then
                ssh $LOGNAME@sop-ps-dsapp5 ". /home/$LOGNAME/.profile;$exe_home/appl_mt_clone_r122.sh $g_appspw $g_wls_admin $g_fs $g_appl_top $contextfile $exe_home/pairs/$oraclesid"_addnode_pairsfile_node1.txt" $oraclesid $g_base"
                check_status $? "Add Node 1"
                ssh $LOGNAME@sop-ps-dsapp6 ". /home/$LOGNAME/.profile;$exe_home/appl_mt_clone_r122.sh $g_appspw $g_wls_admin $g_fs $g_appl_top $contextfile $exe_home/pairs/$oraclesid"_addnode_pairsfile_node2.txt" $oraclesid $g_base"
                check_status $? "Add Node 2"
        else
                ssh $LOGNAME@dwp-ps-dapp1 ". /home/$LOGNAME/.profile;$exe_home/appl_mt_clone_r122.sh $g_appspw $g_wls_admin $g_fs $g_appl_top $contextfile $exe_home/pairs/$oraclesid"_addnode_pairsfile_node1.txt" $oraclesid $g_base"
                check_status $? "Add Node 1"
                ssh $LOGNAME@dwp-ps-dapp2 ". /home/$LOGNAME/.profile;$exe_home/appl_mt_clone_r122.sh $g_appspw $g_wls_admin $g_fs $g_appl_top $contextfile $exe_home/pairs/$oraclesid"_addnode_pairsfile_node2.txt" $oraclesid $g_base"
                check_status $? "Add Node 2"
        fi
}

add_middle_tier_trn()
{
	oraclesid=$ORACLE_SID
	contextfile=$CONTEXT_FILE
	if [ $oraclesid = 'RMTRN1' ]
	then
		mt_appserver=dwp-dr-nrap1
	elif [ $oraclesid = 'RMTRN2' ]
	then
		mt_appserver=dwp-dr-ndis2
	elif [ $oraclesid = 'RMTRN3' ]
	then
		mt_appserver=dwp-dr-nrap2
	fi
	ssh $LOGNAME@${mt_appserver} ". /home/$LOGNAME/.profile;$exe_home/appl_mt_clone_r122.sh $g_appspw $g_wls_admin $g_fs $g_appl_top $contextfile $exe_home/pairs/$oraclesid"_addnode_pairsfile_node1.txt" $oraclesid $g_base"
	check_status $? "Add Node 1"
}

add_middle_tier_ple()
{
	oraclesid=$ORACLE_SID
	contextfile=$CONTEXT_FILE
	ssh $LOGNAME@sop-pl-dsapp3 ". /home/$LOGNAME/.profile;$exe_home/appl_mt_clone_r122.sh $g_appspw $g_wls_admin $g_fs $g_appl_top $contextfile $exe_home/pairs/$oraclesid"_addnode_pairsfile_node1.txt" $oraclesid $g_base"
	check_status $? "Add Node 1"
	ssh $LOGNAME@sop-pl-dsapp4 ". /home/$LOGNAME/.profile;$exe_home/appl_mt_clone_r122.sh $g_appspw $g_wls_admin $g_fs $g_appl_top $contextfile $exe_home/pairs/$oraclesid"_addnode_pairsfile_node2.txt" $oraclesid $g_base"
	check_status $? "Add Node 2"
}

add_middle_tier_pte2()
{
	oraclesid=$ORACLE_SID
	contextfile=$CONTEXT_FILE
	ssh $LOGNAME@dwp-pt-dapp1 ". /home/$LOGNAME/.profile;$exe_home/appl_mt_clone_r122.sh $g_appspw $g_wls_admin $g_fs $g_appl_top $contextfile $exe_home/pairs/$oraclesid"_addnode_pairsfile_node1.txt" $oraclesid $g_base"
	check_status $? "Add Node 1"
	ssh $LOGNAME@dwp-pt-dapp2 ". /home/$LOGNAME/.profile;$exe_home/appl_mt_clone_r122.sh $g_appspw $g_wls_admin $g_fs $g_appl_top $contextfile $exe_home/pairs/$oraclesid"_addnode_pairsfile_node2.txt" $oraclesid $g_base"
	check_status $? "Add Node 2"
	ssh $LOGNAME@dwp-pt-dapp3 ". /home/$LOGNAME/.profile;$exe_home/appl_mt_clone_r122.sh $g_appspw $g_wls_admin $g_fs $g_appl_top $contextfile $exe_home/pairs/$oraclesid"_addnode_pairsfile_node3.txt" $oraclesid $g_base"
	check_status $? "Add Node 3"
	ssh $LOGNAME@dwp-pt-dapp4 ". /home/$LOGNAME/.profile;$exe_home/appl_mt_clone_r122.sh $g_appspw $g_wls_admin $g_fs $g_appl_top $contextfile $exe_home/pairs/$oraclesid"_addnode_pairsfile_node4.txt" $oraclesid $g_base"
	check_status $? "Add Node 4"
}

add_middle_tier_pte()
{
	oraclesid=$ORACLE_SID
	contextfile=$CONTEXT_FILE
	ssh $LOGNAME@dwp-dr-napp1 ". /home/$LOGNAME/.profile;$exe_home/appl_mt_clone_r122.sh $g_appspw $g_wls_admin $g_fs $g_appl_top $contextfile $exe_home/pairs/$oraclesid"_addnode_pairsfile_node1.txt" $oraclesid $g_base"
	check_status $? "Add Node 1"
	ssh $LOGNAME@dwp-dr-napp2 ". /home/$LOGNAME/.profile;$exe_home/appl_mt_clone_r122.sh $g_appspw $g_wls_admin $g_fs $g_appl_top $contextfile $exe_home/pairs/$oraclesid"_addnode_pairsfile_node2.txt" $oraclesid $g_base"
	check_status $? "Add Node 2"
	ssh $LOGNAME@dwp-dr-napp3 ". /home/$LOGNAME/.profile;$exe_home/appl_mt_clone_r122.sh $g_appspw $g_wls_admin $g_fs $g_appl_top $contextfile $exe_home/pairs/$oraclesid"_addnode_pairsfile_node3.txt" $oraclesid $g_base"
	check_status $? "Add Node 3"
	ssh $LOGNAME@dwp-dr-napp4 ". /home/$LOGNAME/.profile;$exe_home/appl_mt_clone_r122.sh $g_appspw $g_wls_admin $g_fs $g_appl_top $contextfile $exe_home/pairs/$oraclesid"_addnode_pairsfile_node4.txt" $oraclesid $g_base"
	check_status $? "Add Node 4"
}

add_middle_tier()
{
        if [ $g_user_type = 'TEST' ]
        then
		add_middle_tier_test
        fi
        if [ $g_user_type = 'TRN' ]
        then
		add_middle_tier_trn
        fi
        if [ $g_user_type = 'PLE' ]
        then
		add_middle_tier_ple
        fi
        if [ $g_user_type = 'PTE' ]
        then
        	if [ $ORACLE_SID = 'PTE2' ]
        	then
			add_middle_tier_pte2
		else
			add_middle_tier_pte
		fi
	fi
}

test_apps()
{
        testsql=`sqlplus -s -L apps/$1<<EOF
exit;
EOF`
        if [ "$testsql" = "" ]
        then
		check_status 0 "Change APPS Password"
        else
		check_status 1 "Change APPS Password"
        fi
}

change_apps_pw()
{
	echo "Running change_apps_passwords " $ORACLE_SID $g_appspw $g_syspw $g_wls_admin $g_new_appspw_number
	$exe_home/change_apps_pw.sh $ORACLE_SID $g_appspw $g_syspw $g_wls_admin $g_new_appspw_number
	test_apps $g_new_appspw
}

start_admin_servers()
{
	. $g_env
	admin_directory=$ADMIN_SCRIPTS_HOME
	cd $admin_directory
	$admin_directory/adadminsrvctl.sh start <<EOF
$g_wls_admin
$g_appspw
EOF
	admin_directory=`echo $ADMIN_SCRIPTS_HOME | sed "s%$RUN_BASE%$PATCH_BASE%g"`
	cd $admin_directory
	$admin_directory/adadminsrvctl.sh start forcepatchfs <<EOF
$g_wls_admin
$g_appspw
EOF
}

run_appl_clone()
{
	if [ $g_appl = 1 ]
	then
		check_files
		repair_symbolic_links
		empty_fmw_home
		point_inventory A
		run_clone_run
		. $g_env
		run_clone_patch
		restore_files
		install_templates
		stop_services
		run_autoconfig
		run_postclone
		run_autoconfig
		run_pre_clone
	fi
        if [ $g_middle = 1 ]
	then
		start_admin_servers
		add_middle_tier
	fi
        if [ $g_changeappspw = 1 ]
	then
		change_apps_pw
	fi
}

usage $@
exe_home=<set home location>
g_user_type=
g_pp=
user_type
kill_processes_before_start
determine_base
g_appl_top=$g_base/$g_fs/EBSapps/appl
g_server=`uname -a|awk '{print $2}'`
g_script=`basename $0`
g_lockfile=$exe_home/logs/.${g_script}_${ORACLE_SID}_${g_server}.lok
check_lockfile
g_new_appspw="apps"$g_new_appspw_number
echo New Apps Password will be $g_new_appspw
g_context=$ORACLE_SID"_"$g_server
g_backupdir=/home/$LOGNAME/AppClone
g_contextfile=$g_backupdir/$ORACLE_SID"_"$g_server.xml
g_env="$g_base/EBSapps.env run"
dt=`date -u +%d%m%y%H%M%S`
g_log="$exe_home/logs/"$ORACLE_SID"_clone_admin_"$dt.log
echo Running Admin Clone Process, check log $g_log for progress...
run_appl_clone > $g_log 2>&1
remove_lockfile
exit 0
