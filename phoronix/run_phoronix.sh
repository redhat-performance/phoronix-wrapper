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
rtc=0

arguments="$@"
pcpdir=""

error_out()
{
	echo $1
	exit $2

}

usage()
{
	echo "Usage:"
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

ARGUMENT_LIST=(
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
# Right now we only support stress-ng
#
if [ ! -d "./phoronix-test-suite" ]; then
	git clone -b $GIT_VERSION --single-branch --depth 1 https://github.com/phoronix-test-suite/phoronix-test-suite
fi
echo 1 | ./phoronix-test-suite/phoronix-test-suite install stress-ng
echo $test_index > /tmp/ph_opts
echo n >> /tmp/ph_opts

#
# Run phoronix test
#
if [[ -f /tmp/results_${test_name}_${to_tuned_setting}.out ]]; then
	rm /tmp/results_${test_name}_${to_tuned_setting}.out
fi

# If we're using PCP set things up and start logging
if [[ $to_use_pcp -eq 1 ]]; then
	# Get PCP setup if we're using it
	source $TOOLS_BIN/pcp/pcp_commands.inc
	setup_pcp
	pcp_cfg=$TOOLS_BIN/pcp/default.cfg
	pcpdir=/tmp/pcp_`date "+%Y.%m.%d-%H.%M.%S"`

	echo "Start PCP"
	start_pcp ${pcpdir}/ ${test_name} $pcp_cfg
fi

for iterations  in 1 `seq 2 1 ${to_times_to_run}`
do
	# If we're using PCP, snap a chalk line at the start of the iteration
	if [[ $to_use_pcp -eq 1 ]]; then
		start_pcp_subset
	fi
	./phoronix-test-suite/phoronix-test-suite run stress-ng < /tmp/ph_opts  >> /tmp/results_${test_name}_${to_tuned_setting}.out
	# If we're using PCP, snap the chalk line at the end of the iteration
	# and log the iteration's result

	if [[ $to_use_pcp -eq 1 ]]; then
		echo "Send result to PCP archive"
		result2pcp iterations ${iterations}
		stop_pcp_subset
	fi
done
# If we're using PCP, stop logging
if [[ $to_use_pcp -eq 1 ]]; then
	echo "Stop PCP"
	stop_pcp
fi
#
# Archive up the results.
#
cd /tmp
RESULTSDIR=/tmp/results_${test_name}_${to_tuned_setting}$(date "+%Y.%m.%d-%H.%M.%S")
mkdir -p ${RESULTSDIR}/results_phoronix
if [[ -f results_${test_name}_${to_tuned_setting} ]]; then
	rm results_${test_name}_${to_tuned_setting}
fi
ln -s ${RESULTSDIR} results_${test_name}_${to_tuned_setting}

cp results_${test_name}_*.out $RESULTSDIR/results_phoronix
${curdir}/test_tools/move_data $curdir  $RESULTS_DIR/results_phoronix
cp /tmp/results_${test_name}_${to_tuned_setting}.out $RESULTSDIR/results_phoronix
pushd $RESULTSDIR/results_phoronix > /dev/null
$TOOLS_BIN/test_header_info --front_matter --results_file results.csv --host $to_configuration --sys_type $to_sys_type --tuned $to_tuned_setting --results_version $GIT_VERSION --test_name $test_name
#
# We place the results first in results_check.csv so we can check to make sure
# the tests actually ran.  After the check, we will add the run info to results.csv.
#
$run_dir/reduce_phoronix > results_check.csv
lines=`wc -l results_check.csv | cut -d' ' -f 1`
if [[ $lines == "1" ]]; then
	#
	# We failed, report and do not remove the results_check.csv file.
	#
	echo Failed >> test_results_report
	rtc=1
else
	echo Ran >> test_results_report
	cat results_check.csv >> results.csv
	rm results_check.csv
fi
popd > /dev/null
${curdir}/test_tools/save_results --curdir $curdir --home_root $to_home_root --copy_dir "$RESULTSDIR ${pcpdir}" --test_name $test_name --tuned_setting $to_tuned_setting --version none --user $to_user
exit $rtc
