#!/bin/bash
#
# Copyright (C) 2022  David Valin dvalin@redhat.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

test_name="phoronix"
GIT_VERSION="v10.8.1"
test_index="Test All Options"
rtc=0

arguments="$@"

#
# Get the directory we are running out of.
#
curdir=`pwd`
if [[ $0 == "./"* ]]; then
	chars=`echo $0 | awk -v RS='/' 'END{print NR-1}'`
	if [[ $chars == 1 ]]; then
		run_dir=`pwd`
	else
		run_dir=`echo $0 | cut -d'/' -f 1-${chars} | cut -d'.' -f2-`
		run_dir="${curdir}${run_dir}"
	fi
elif [[ $0 != "/"* ]]; then
	dir=`echo $0 | rev | cut -d'/' -f2- | rev`
	run_dir="${curdir}/${dir}"
else
	chars=`echo $0 | awk -v RS='/' 'END{print NR-1}'`
	run_dir=`echo $0 | cut -d'/' -f 1-${chars}`
	if [[ $run_dir != "/"* ]]; then
		run_dir=${curdir}/${run_dir}
	fi
fi


if [ ! -f "/tmp/${test_name}.out" ]; then
	command="${0} $@"
	echo $command
	$command &> /tmp/${test_name}.out
	rtc=$?
	if [[ -f /tmp/${test_name}.out ]]; then
		cat /tmp/${test_name}.out
		rm /tmp/${test_name}.out
	fi
	exit $rtc
fi

#
# Clone the repo that contains the common code and tools
#
tools_git=https://github.com/redhat-performance/test_tools-wrappers


error_out()
{
	echo $1
	exit $2

}

usage()
{
	echo "  Usage:"
	echo "  --test_index: test index to run.  Default is $test_index"
	echo "  --sub_test test running: Test we are to run. Supported tests are"
	echo "    cockroach, cassandra, couchdb and hbase"
	echo "  --tools_git: Location to pick up the required tools git, default"
	echo "    https://github.com/redhat-performance/test_tools-wrappers"
	echo "  --usage: this usage message"
	test_tools/general_setup --usage
	exit 1
}

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
                error_out "Error pulling git $tools_git" 1
                exit
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

${curdir}/test_tools/gather_data ${curdir}
source test_tools/general_setup "$@"

ARGUMENT_LIST=(
	"test_index"
	"sub_test"
)

NO_ARGUMENTS=(
        "usage"
)


# read arguments
opts=$(getopt \
    --longoptions "$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --longoptions "$(printf "%s," "${NO_ARGUMENTS[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Report any errors
#
if [ $? -ne 0 ]; then
	error_out "Error with option parsing" 1
fi

eval set --$opts

while [[ $# -gt 0 ]]; do
        case "$1" in
		--test_index)
			test_index=$2
			shift 2
		;;
    --sub_test)
      sub_test=${2}
      shift 2
    ;;
    -h)
			usage
		;;
	  --usage)
			usage
      exit
    ;;
		--)
			break;
		;;
		*)
			echo option not found $1
			usage
			exit
		;;
        esac
done

index_cockroach(){
  echo $test_index > /tmp/ph_opts
  echo $test_index >> /tmp/ph_opts
  echo n >> /tmp/ph_opts
}

index_redis(){
  echo $test_index > /tmp/ph_opts
  echo $test_index >> /tmp/ph_opts
  echo n >> /tmp/ph_opts
}

index_stress_ng(){
  echo $test_index > /tmp/ph_opts
  echo n >> /tmp/ph_opts
}

index_phpbench(){
  echo n >> /tmp/ph_opts
}

index_cassandra(){
  echo n >> /tmp/ph_opts
}

index_apache_iotdb(){
  echo $test_index > /tmp/ph_opts
  echo $test_index >> /tmp/ph_opts
  echo $test_index >> /tmp/ph_opts
  echo $test_index >> /tmp/ph_opts
  echo n >> /tmp/ph_opts
}

index_nginx(){
  echo $test_index > /tmp/ph_opts
  echo n >> /tmp/ph_opts
}

index_sqlite(){
  echo $test_index > /tmp/ph_opts
  echo n >> /tmp/ph_opts
}

if [[ $sub_test == "none" ]]; then
	echo You must designate a test.
	usage $0
fi

if [ $to_pbench -eq 1 ]; then
	source ~/.bashrc
	move_back=0
	move_this=`ls /var/lib/pbench-agent/tools-*-default/*/perf`
	if [ $? -eq 0 ]; then
		move_back=1
		mv $move_this /tmp/perf
	fi
	echo $TOOLS_BIN/execute_via_pbench --cmd_executing "$0" $arguments --test $test_name_sub_test --spacing 11 --pbench_stats $to_pstats
	$TOOLS_BIN/execute_via_pbench --cmd_executing "$0" $arguments --test $test_name_sub_test --spacing 11 --pbench_stats $to_pstats
	if [ $move_back -eq 1 ]; then
		mv /tmp/perf $move_this
	fi
	exit
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
	if [ ! -d "./phoronix-test-suite" ]; then
		git clone -b $GIT_VERSION --single-branch --depth 1 https://github.com/phoronix-test-suite/phoronix-test-suite
	fi
	echo 1 | ./phoronix-test-suite/phoronix-test-suite install ${sub_test}

	  if [[ ${sub_test} == "cockroach" ]]; then
      index_cockroach
	  elif [[ ${sub_test} == "redis" ]]; then
      index_redis
	  elif [[ ${sub_test} == "stress-ng" ]]; then
      index_stress_ng
	  elif [[ ${sub_test} == "phpbench" ]]; then
      index_phpbench
	  elif [[ ${sub_test} == "cassandra" ]]; then
      index_cassandra
	  elif [[ ${sub_test} == "apache-iotdb" ]]; then
      index_apache_iotdb
    elif [[ ${sub_test} == "nginx" ]]; then
      index_nginx
    elif [[ ${sub_test} == "sqlite" ]]; then
      index_sqlite
	  else
	    echo "Unsupported test: ${sub_test}"
      exit 1
		fi


	#
	# Run phoronix test
	#
	if [[ -f /tmp/results_${test_name}_${sub_test}_${to_tuned_setting}.out ]]; then
		rm /tmp/results_${test_name}_${sub_test}_${to_tuned_setting}.out
	fi
	for iterations  in 1 `seq 2 1 ${to_times_to_run}`
	do
		./phoronix-test-suite/phoronix-test-suite run ${sub_test} < /tmp/ph_opts  >> /tmp/results_${test_name}_${sub_test}_${to_tuned_setting}.out
	done
	#
	# Archive up the results.
	#
	results_file=results_phoronix_${sub_test}.csv

	cd /tmp
	RESULTSDIR=results_${test_name}_${sub_test}_${to_tuned_setting}$(date "+%Y.%m.%d-%H.%M.%S")
	mkdir -p ${RESULTSDIR}/${test_name}_${sub_test}_results/results_phoronix
	if [[ -f results_${test_name}_${sub_test}_${to_tuned_setting} ]]; then
		rm results_${test_name}_${sub_test}_${to_tuned_setting}
	fi
	ln -s ${RESULTSDIR} results_${test_name}_${sub_test}_${to_tuned_setting}

	cp results_${test_name}_${sub_test}_*.out results_${test_name}_${sub_test}_${to_tuned_setting}/phoronix_results/results_phoronix
	${curdir}/test_tools/move_data $curdir  results_${test_name}_${sub_test}_${to_tuned_setting}/phoronix_results/results_phoronix
	cp /tmp/results_${test_name}_${sub_test}_${to_tuned_setting}.out results_${test_name}_${sub_test}_${to_tuned_setting}/phoronix_results/results_phoronix
	pushd /tmp/results_${test_name}_${sub_test}_${to_tuned_setting}/phoronix_results/results_phoronix > /dev/null
	$TOOLS_BIN/test_header_info --front_matter --results_file ${results_file} --host $to_configuration --sys_type $to_sys_type --tuned $to_tuned_setting --results_version $GIT_VERSION --test_name phoronix_${sub_test}
	#
	# We place the results first in results_check.csv so we can check to make sure
	# the tests actually ran.  After the check, we will add the run info to results.csv.
	#
	$run_dir/reduce_phoronix --sub_test ${sub_test} --tmp_file results_${sub_test}_check.csv
	lines=`wc -l results_${sub_test}_check.csv | cut -d' ' -f 1`
	if [[ $lines == "1" ]]; then
		#
		# We failed, report and do not remove the results_{sub_test}_check.csv file.
		#
		echo Failed >> test_results_report
		rtc=1
	else
		echo Ran >> test_results_report
		cat results_${sub_test}_check.csv >> ${results_file}
		rm results_${sub_test}_check.csv
	fi
	popd > /dev/null
	find -L $RESULTSDIR  -type f | tar --transform 's/.*\///g' -cf results_pbench.tar --files-from=/dev/stdin
	${curdir}/test_tools/save_results --curdir $curdir --home_root $to_home_root --copy_dir $RESULTSDIR --test_name $test_name --tuned_setting=$to_tuned_setting --version $version none --user $to_user

fi
exit $rtc
