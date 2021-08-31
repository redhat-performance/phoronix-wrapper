#!/bin/bash
arguments="$@"
chars=`echo $0 | awk -v RS='/' 'END{print NR-1}'`
run_dir=`echo $0 | cut -d'/' -f 1-${chars}`
test_name="phoronix"

#
# Get the directory we are running out of.
#
numb_fields=`echo $0 | awk -F '/' '{print NF-1}'`
run_dir=`echo $0 | cut -d'/' -f1-${numb_fields}`
tools_git=https://github.com/dvalinrh/test_tools

#
# Clone the repo that contains the common code and tools
#
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
		usage $0
	fi
done

#
# Check to see if the test tools directory exists.  If it does, we do not need to
# clone the repo.
#
if [ ! -d "test_tools" ]; then
        git clone $tools_git
        if [ $? -ne 0 ]; then
                echo pulling git $tools_git failed.
                exit
        fi
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

usage()
{
        echo "Usage: $0"
	source test_tools/general_setup --usage
}

if [ $to_pbench -eq 1 ]; then
	source ~/.bashrc
	echo $TOOLS_BIN/execute_via_pbench_1 --cmd_executing "$0" ${arguments} --test ${test_name} --spacing 11
	$TOOLS_BIN/execute_via_pbench_1 --cmd_executing "$0" ${arguments} --test ${test_name} --spacing 11
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
	echo 1 | ./phoronix-test-suite/phoronix-test-suite install stress-ng
	echo 21 > /tmp/ph_opts
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
	pushd /tmp/results_${test_name}_${to_tuned_setting}/phoronix_results/results_phoronix
	$run_dir/reduce_phoronix > results_phoronix.csv
	popd
	tar hcf results_${test_name}_${to_tuned_setting}.tar results_${test_name}_${to_tuned_setting}
fi
