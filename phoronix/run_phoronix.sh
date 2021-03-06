#!/bin/bash
arguments="$@"

curdir=`pwd`
if [[ $0 == "./"* ]]; then
        chars=`echo $0 | awk -v RS='/' 'END{print NR-1}'`
        if [[ $chars == 1 ]]; then
                run_dir=`pwd`
        else
                run_dir=`echo $0 | cut -d'/' -f 1-${chars} | cut -d'.' -f2-`
                run_dir="${curdir}${run_dir}"
        fi
else
        chars=`echo $0 | awk -v RS='/' 'END{print NR-1}'`
        run_dir=`echo $0 | cut -d'/' -f 1-${chars}`
fi

test_name="phoronix"
GIT_VERSION="v10.8.1"
if [ ! -f "phoronix.out" ]; then
	command="${0} $@}"
	echo $command
	script -c "$command}" phoronix.out
	exit $?
fi


#
# Get the directory we are running out of.
#
tools_git=https://github.com/redhat-performance/test_tools-wrappers

usage()
{
        echo "Usage: $0"
	echo "--tools_git <value>: git repo to retrieve the required tools from, default is ${tools_git}"
	source test_tools/general_setup --usage
}

#
# Clone the repo that contains the common code and tools
#
show_usage=0
found=0
for arg in "$@"; do
	if [ $found -eq 1 ]; then
		tools_git=$arg
		break;
	fi
	if [[ $arg == "--tools_git" ]]; then
		found=1
	fi

	#
	# We do the usage check here, as we do not want to be calling
	# the common parsers then checking for usage here.  Doing so will
	# result in the script exiting with out giving the test options.
	#
	if [[ $arg == "--usage" ]]; then
		show_usage=1
	fi
done

#
# Check to see if the test tools directory exists.  If it does, we do not need to
# clone the repo.
#
if [ ! -d "test_tools" ]; then
        git clone $tools_git test_tools
        if [ $? -ne 0 ]; then
                echo pulling git $tools_git failed.
                exit 1
        fi
else
	echo Found an existing test_tools directory, using it.
fi

if [ $show_usage -eq 1 ]; then
	usage $0
fi

# Variables set by general setup.
#
# TOOLS_BIN: points to the tool directory
# to_home_root: home directory
# to_configuration: configuration information
# to_times_to_run: number of times to run the test
# to_pbench: Run the test via pbench
# to_puser: User running pbench
# to_run_label: Label for the run
# to_user: User on the test system running the test
# to_sys_type: for results info, basically aws, azure or local
# to_sysname: name of the system
# to_tuned_setting: tuned setting
#

source test_tools/general_setup "$@"

if [ $to_pbench -eq 1 ]; then
	source ~/.bashrc
	echo $TOOLS_BIN/execute_via_pbench --cmd_executing "$0" ${arguments} --test ${test_name} --spacing 11 --pbench_stats $to_pstats
	$TOOLS_BIN/execute_via_pbench --cmd_executing "$0" ${arguments} --test ${test_name} --spacing 11 --pbench_stats $to_pstats
else
	if [ $to_user == "ubuntu" ]; then
		DEBIAN_FRONTEND=noninteractive apt-get install -y -q php-cli
		DEBIAN_FRONTEND=noninteractive apt-get install -y -q php-xml
	fi
	cd $run_dir
	#
	# phoronix run parameters.
	#
	# Right now we only support stress-ng
	#
	if [ ! -d i"./phoronix-test-suite" ]; then
		git clone -b $GIT_VERSION --single-branch --depth 1 https://github.com/phoronix-test-suite/phoronix-test-suite
	fi
	echo 1 | ./phoronix-test-suite/phoronix-test-suite install stress-ng
	echo 23 > /tmp/ph_opts
	echo n >> /tmp/ph_opts
	
	#
	# Run phoronix test
	#
	for iterations  in 1 `seq 2 1 ${to_times_to_run}`
	do
		./phoronix-test-suite/phoronix-test-suite run stress-ng < /tmp/ph_opts  >> /tmp/results_${test_name}_${to_tuned_setting}.out
	done
	#
	# Archive up the results.
	#
	cd /tmp
	RESULTSDIR=results_${test_name}_${to_tuned_setting}$(date "+%Y.%m.%d-%H.%M.%S")
	mkdir -p ${RESULTSDIR}/${test_name}_results/results_phoronix
	rm results_${test_name}_${to_tuned_setting}
	ln -s ${RESULTSDIR} results_${test_name}_${to_tuned_setting}

	cp results_${test_name}_*.out results_${test_name}_${to_tuned_setting}/phoronix_results/results_phoronix
	cp ${curdir}/meta_data.yml results_${test_name}_${to_tuned_setting}/phoronix_results/results_phoronix
	cp ${curdir}/phoronix.out results_${test_name}_${to_tuned_setting}/phoronix_results/results_phoronix
	pushd /tmp/results_${test_name}_${to_tuned_setting}/phoronix_results/results_phoronix
	$run_dir/reduce_phoronix > results_phoronix.csv
	lines=`wc -l results_phoronix.csv | cut -d' ' -f 1`
	if [ $lines -eq 1 ]; then
		echo Failed >> test_results_report
	else
		echo Ran >> test_results_report
	fi
	popd
	tar hcf results_${test_name}_${to_tuned_setting}.tar results_${test_name}_${to_tuned_setting}
fi
exit 0
