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

test_index="Test All Options"
test_index1="Test All Options"
#sub_test="stress-ng"
sub_test="redis"
rtc=0

arguments="$@"
pcpdir=""

error_out()
{
	echo $1
	stop_pcp
	shutdown_pcp
	exit $2

}

usage()
{
	echo "Usage:"
	echo "  --sub_test <name>: What phoronix subtest to run(stress-ng....)"
	echo "  --test_index: test index to run.  Default is $test_index"
	echo "  --tools_git: Location to pick up the required tools git, default"
	echo "    https://github.com/redhat-performance/test_tools-wrappers"
	echo "  --usage: this usage message"
	source test_tools/general_setup --usage
}

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

test_name="phoronix"
GIT_VERSION="v10.8.1"
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
# Get the directory we are running out of.
#
tools_git=https://github.com/redhat-performance/test_tools-wrappers


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
                error_out "Error pulling git $tools_git" 1
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
# to_user: User on the test system running the test
# to_sys_type: for results info, basically aws, azure or local
# to_sysname: name of the system
# to_tuned_setting: tuned setting
#

${curdir}/test_tools/gather_data ${curdir}
source test_tools/general_setup "$@"

#
# Install required packaging.
#
${TOOLS_BIN}/package_tool --wrapper_config ${run_dir}/phoronix.json --no_packages $to_no_pkg_install
if [[ $? -ne 0 ]]; then
	error_out "package tool returned failure" 1
fi

ARGUMENT_LIST=(
	"sub_test"
	"test_index"
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
        exit
fi

eval set --$opts

while [[ $# -gt 0 ]]; do
        case "$1" in
		--sub_test)
			sub_test=$2
			shift 2
		;;
		--test_index)
			test_index=$2
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


if [ $to_user == "ubuntu" ]; then
	DEBIAN_FRONTEND=noninteractive apt-get install -y -q php-cli
	DEBIAN_FRONTEND=noninteractive apt-get install -y -q php-xml
fi
cd $run_dir
#
# phoronix run parameters.
#
if [ ! -d "./phoronix-test-suite" ]; then
	git clone -b $GIT_VERSION --single-branch --depth 1 https://github.com/phoronix-test-suite/phoronix-test-suite
fi

echo 1 | ./phoronix-test-suite/phoronix-test-suite install $sub_test
#
# phoronix-test-suite does not return an error on failure.
#
./phoronix-test-suite/phoronix-test-suite list-installed-tests | grep -q $sub_test
if [[ $? -ne 0 ]]; then
	error_out "Unable to install $sub_test" 1
fi

if [[ "$sub_test" != "cassandra" ]] && [[ $sub_test != "phpbench" ]]; then
        echo $test_index > /tmp/ph_opts
        if [[ "$sub_test" == "redis" ]] || [[ "$sub_test" == "cockroach" ]]; then
                echo $test_index1 >> /tmp/ph_opts
        fi
        if [[ "$sub_test" == "apache-iotdb" ]]; then
                echo $test_index >> /tmp/ph_opts
                echo $test_index >> /tmp/ph_opts
                echo $test_index >> /tmp/ph_opts
        fi
fi
echo n >> /tmp/ph_opts

#
# Run phoronix test
#
if [[ -f /tmp/results_${test_name}_${to_tuned_setting}.out ]]; then
	rm /tmp/results_${test_name}_${to_tuned_setting}.out
fi

convert_metric=""
convert_metric_name()
{
	convert_metric=`echo "$1" | sed "s/;/_/g" | awk '{print $1}'| sed "s/-//g"`
}

create_phoronix_openmetric()
{
	rm ${run_dir}/openmetrics_phoronix_reset.txt
	while IFS= read -r line
	do
		convert_metric_name "$line"
		def=`echo $line | awk '{print $2}'`
		echo $convert_metric $def >> ${run_dir}/openmetrics_phoronix_reset.txt
	done < "${run_dir}/openmetrics_${test_name}_${sub_test}.txt"
}

# If we're using PCP set things up and start logging
if [[ $to_use_pcp -eq 1 ]]; then
	source $TOOLS_BIN/pcp/pcp_commands.inc
	# Get PCP setup if we're using it
	rm -f /tmp/openmetrics_workload*
	create_phoronix_openmetric
	setup_pcp
	pcp_cfg=$TOOLS_BIN/pcp/default.cfg
	pcpdir=/tmp/pcp_`date "+%Y.%m.%d-%H.%M.%S"`
	echo "Start PCP"
	start_pcp ${pcpdir}/ ${test_name}_${sub_test} $pcp_cfg
fi

pcp_common()
{
	while IFS= read -r line
	do
		convert_metric_name "$line"
		name=`echo "$line" | awk '{print $1}' | sed "s/;/ /g"`
		#
		# openssl has a duplicate test name in the run, RSA4096, simply picking the last one
		# to prevent issues in data reduction.
		#
		value=`grep "^$name", results_${sub_test}.csv  | tail -1 | cut -d',' -f 2`
		if [[ $value != "" ]]; then
			results2pcp_add_value "$convert_metric:${value}"
		fi
	done < "${run_dir}/openmetrics_${test_name}_${sub_test}.txt"
	results2pcp_add_value_commit
	reset_pcp_om
}

pcp_cockroach()
{
	tfile=$(mktemp /tmp/phoronix.XXXXXX)
	grep Reads results_${sub_test}.csv  > $tfile
	while IFS= read -r line
	do
		concurrency=`echo $line | cut -d, -f 2`
		average=`echo $line | cut -d, -f 3 | sed "s///g"`
		results2pcp_multiple "concurrency:${concurrency},average:${average}"
	done < "$tfile"
	rm $tfile
	reset_pcp_om
}

pcp_redis()
{
	tfile=$(mktemp /tmp/phoronix.XXXXXX)
	connections=`grep -v "#" results_${sub_test}.csv | grep -v "^Test," | cut -d, -f 2 | sort -un`
	for i in $connections; do
		grep ",${i}," results_${sub_test}.csv  > $tfile
		results2pcp_add_value "ParallelConnections:${i}"
		while IFS= read -r line
		do
			test=`echo $line | cut -d',' -f 1`
			value=`echo $line | cut -d',' -f 3`
			results2pcp_add_value  "$test:$value"
		done < "$tfile"
		results2pcp_add_value_commit
		reset_pcp_om
	done
	reset_pcp_om
	rm $tfile
}

pcp_nginx()
{
	tfile=$(mktemp /tmp/phoronix.XXXXXX)
	grep '^[0-9]' results_${sub_test}.csv  > $tfile
	while IFS= read -r line
	do
		connections=`echo $line | cut -d, -f 1`
		rps=`echo $line | cut -d, -f 2`
		results2pcp_multiple "connections:${connections},RPS:${RPS}"
	done < "$tfile"
	reset_pcp_om
	rm $tfile
}

pcp_sqlite()
{
	tfile=$(mktemp /tmp/phoronix.XXXXXX)
	grep '^[0-9]' results_${sub_test}.csv  > $tfile
	while IFS= read -r line
	do
		threads=`echo "$line" | cut -d, -f 1`
		average=`echo "$line" | cut -d, -f 2`
		results2pcp_multiple "Threads:${threads},Average:${average}"
	done < "$tfile"
	reset_pcp_om
	rm $tfile
}

pcp_phpbench()
{
	value=`grep '^[0-9]' results_phpbench.csv | tail -1 | cut -d',' -f 1,2`
	avg=`echo $value | cut -d',' -f 1`
	dev=`echo $value | cut -d',' -f 2`
	results2pcp_multiple "average:${avg},deviation:${dev}"
	reset_pcp_om

}

for iterations  in 1 `seq 2 1 ${to_times_to_run}`
do
	# If we're using PCP, snap a chalk line at the start of the iteration
	if [[ $to_use_pcp -eq 1 ]]; then
		start_pcp_subset
		results2pcp_multiple "iteration:${iterations}"
	fi
	ran=1
	rm  -f /tmp/results_${test_name}_${to_tuned_setting}_iterations_${iterations}.out
	start_time=$(retrieve_time_stamp)
	./phoronix-test-suite/phoronix-test-suite run $sub_test < /tmp/ph_opts  >> /tmp/results_${test_name}_${to_tuned_setting}_iterations_${iterations}.out
	end_time=$(retrieve_time_stamp)
	export end_time
	export start_time
	# If we're using PCP, snap the chalk line at the end of the iteration
	# and log the iteration's result

	if [[ $to_use_pcp -eq 1 ]]; then
		rm -f results_${sub_test}.csv
		$TOOLS_BIN/test_header_info --front_matter --results_file results_${sub_test}.csv --host $to_configuration --sys_type $to_sys_type --tuned $to_tuned_setting --results_version $GIT_VERSION --test_name $test_name
		$run_dir/reduce_phoronix --sub_test $sub_test --out_file results_${sub_test}.csv --in_file /tmp/results_${test_name}_${to_tuned_setting}_iterations_${iterations}.out
		cp results_${sub_test}.csv  /tmp
		if [[ $sub_test == "cassandra" ]]; then
			echo FILL
		elif [[ $sub_test == "stress-ng" ]] || [[ $sub_test == "openssl" ]]; then
			pcp_common
		elif [[ $sub_test == "cockroach" ]]; then
			pcp_cockroach
		elif [[ $sub_test == "nginx" ]]; then
			pcp_nginx
		elif [[ $sub_test == "redis" ]]; then
			pcp_redis
		elif [[ $sub_test == "phpbench" ]]; then
			pcp_phpbench
		elif [[ $sub_test == "sqlite" ]]; then
			pcp_sqlite
		fi
		stop_pcp_subset
	fi
done
rm /tmp/ph_opts
# If we're using PCP, stop logging
if [[ $to_use_pcp -eq 1 ]]; then
	echo "Stop PCP"
	stop_pcp
	shutdown_pcp
fi
#
# Archive up the results.
#
cd /tmp
RESULTSDIR=/tmp/results_${test_name}_${to_tuned_setting}$(date "+%Y.%m.%d-%H.%M.%S")
rdir=${RESULTSDIR}/results_phoronix_${sub_test}
mkdir -p $rdir
if [[ -f results_${test_name}_${to_tuned_setting} ]]; then
	rm results_${test_name}_${to_tuned_setting}
fi
ln -s ${RESULTSDIR} results_${test_name}_${to_tuned_setting}

cp results_${test_name}_*.out $rdir
${curdir}/test_tools/move_data $curdir  $rdir
cp /tmp/results_${test_name}_${to_tuned_setting}*.out $rdir

#
# If pcp, we have already built the csv file.
#
pushd $rdir > /dev/null
if [[ $to_use_pcp -eq 0 ]]; then
	$TOOLS_BIN/test_header_info --front_matter --results_file results_${sub_test}.csv --host $to_configuration --sys_type $to_sys_type --tuned $to_tuned_setting --results_version $GIT_VERSION --test_name $test_name
	$run_dir/reduce_phoronix --sub_test $sub_test --out_file results_${sub_test}.csv --in_file /tmp/results_${test_name}_${to_tuned_setting}_iterations_${iterations}.out
else
	mv /tmp/results_${sub_test}.csv .
fi

popd > /dev/null
#
# For now just use the first run.
#

${curdir}/test_tools/save_results --curdir $curdir --home_root $to_home_root --copy_dir "$RESULTSDIR ${pcpdir}" --test_name phoronix_${sub_test} --tuned_setting $to_tuned_setting --version none --user $to_user
exit $rtc
