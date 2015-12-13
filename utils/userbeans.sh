#!/bin/bash

## This script obtained from http://amos.freeshell.org/userbeans.sh
## This util reads /proc/user_beancounters directly if run by root user.
## Unprivileged users may use beanc.c from http://www.labradordata.ca/home/35
## to pipe beancounter data into stdin.
## Primary reference: http://wiki.openvz.org/Proc/user_beancounters
## Also http://forum.swsoft.com/showthread.php?s=d03fd7e49b67dfb1f45f4f453e019a73&threadid=26770

## Default_args: for a full list run the script with --help.
##
## Command line args will override what is specified here.  If
## Default_Args is set to "" then options *must* be specified on the
## command line (i.e. no defaults).
##
## Uncomment one of the following examples, or create your own:
##
Default_Args=""         # no defaults, options to be specified at run time
#Default_Args="+m"      # show resource limits and usage for page memory only
#Default_Args="+mk"     # show resource limits and usage for all memory
#Default_Args="+l"      # show resource limits for all memory
#Default_Args="+u"      # show current usage for all memory
#Default_Args="+mu"     # show current usage for page memory
#Default_Args="+o"      # show limits and usage for non-memory resources
#Default_Args="+f"      # show fail counts
#Default_Args="+a -e"   # print everything except explanations

## Revisions:
##
## V0.02: - improve syntax checking for command line arguments, reject incorrect options.
##        - add 'B' option, for all beancounters
##        - general tarting up of the code
## V0.03: - incorporate direct reading of /proc/user_beancounters by root user
##        - incorporate Default_Args variable; set option defaults to 'n'
##        - fix MB reporting for kmemsize
## V1.00: - released 13 Nov 2006 by grummund and yager on irc.chatspike.net#RapidVPS
## V0.01: - improve handling of stdin requirement for non-root users

## TODO list, bugs, idea proposals...
##
## - improve quoting of variables, a good defensive measure otherwise
##   things break too easily.
## - demarcation lines printed even when not required with -H
## - add some example command line usage

## Output option defaults to everything off
option_date=n; option_datehost=n; option_uptime=n
option_limits=n; option_usage=n
option_memory=n; option_kernel=n
option_others=n; option_failcnts=n
option_demarcations=n; option_info=n
option_help=n; option_veid=n
exp0="******" # preceeds the information text

## Array field constants:
param_name=0; held=1; maxheld=2; barrier=3; limit=4; failcnt=5

declare -a FailCounts
FailCounts[0]=0
fails=0

print_usage () {
    cat <<EOF >&2
Usage: $0 [(+|-)(option)[option]...] ...]
[+|-] turns output options on or off
Options:
         a) for all options (use first)
         d) demarcation lines ------
H) Header Elements:
         v) VEID
         i) ID : date and hostname
         s) status : uptime
B) BeanCounters:
         l) limits set by host
         u) usage by VE
         m) memory pages
         k) kernel (low) memory
         o) other, non-memory, parameters
         f) fail counts
Informational:
         e) explanations
EOF
}

demarcate () {
    echo '-----------------------------------------------'
}

read_params () {
    case $# in
        2) UBC_version="$2"; return;;
        7) UBC_veid="${1%:}"; shift;;
        6) ;;
        *) print_usage; exit 1;;
    esac
    PARAM=$1
    let UBC_$PARAM[1]=$2
    let UBC_$PARAM[2]=$3
    let UBC_$PARAM[3]=$4
    let UBC_$PARAM[4]=$5
    let UBC_$PARAM[5]=$6
#    eval echo "debug: $PARAM= \${UBC_$PARAM[@]}"
    let fails=UBC_$PARAM[5]
    if [ $fails -gt 0 ] && [ $6 != "failcnt" ]; then
        let "FailCounts[0] += 1"
        FailCounts[${FailCounts[0]}]="$*"
    fi
}


## A couple handy functions:
Kilobytes=   # Global variable to hold oversize return value of function.
kilos () {
    Kilobytes=$(($1 / 1024))
    return
}

Megabytes=   # Global variable to hold oversize return value of function.
megas () {
    kilos $1
    Megabytes=$(($Kilobytes / 1024))
#    let "Megabytes /= 1024"
    return
}

print_bytes () {
    if [ "$2" -gt 1048576 ]; then
        printf "$1" "$(($2 / 1048576))" "MB"
    elif [ "$2" -gt 1024 ]; then
        printf "$1" "$(($2 / 1024))" "KB"
    else
        printf "$1" "$2" "B"
    fi
}


## Parse the option arguments:
parse_args () {
#echo debug-parse:"$@"
for arg in "$@"; do
#echo debug-arg:$arg
    case "${arg:0:1}" in
        +) option_state=y;;
        -) option_state=n;;
        *) print_usage; exit 1;;
    esac
    char=1
    while [ "$char" -lt "${#arg}" ]; do
        case "${arg:$char:1}" in
            v) option_veid=$option_state;;
            i) option_datehost=$option_state;;
            s) option_uptime=$option_state;;
            l) option_limits=$option_state;;
            u) option_usage=$option_state;;
            m) option_memory=$option_state;;
            k) option_kernel=$option_state;;
            o) option_others=$option_state;;
            f) option_failcnts=$option_state;;
            d) option_demarcations=$option_state;;
            e) option_info=$option_state;;
            B) option_limits=$option_state
               option_usage=$option_state
               option_memory=$option_state
               option_kernel=$option_state
               option_others=$option_state
               option_failcnts=$option_state;;
            H) option_veid=$option_state
               option_datehost=$option_state
               option_uptime=$option_state;;
            a) option_datehost=$option_state
               option_uptime=$option_state
               option_limits=$option_state
               option_usage=$option_state
               option_memory=$option_state
               option_kernel=$option_state
               option_others=$option_state
               option_failcnts=$option_state
               option_demarcations=$option_state
               option_info=$option_state
               option_veid=$option_state;;
            *) print_usage; exit 1;;
        esac
        char=$[$char+1]
    done # while
    case "$arg" in
        -h|+h|--h|--help)
        print_usage; exit 0;;
    esac
done
}


## Test for no options
if [ -z "$Default_Args" ] && [ -z "$*" ] ; then
        print_usage
        echo "You must edit $0 Default_Args variable and/or put option arguments on command line" >&2
        exit 1
fi
#echo "debug-options:$Default_Args:$*"
## Read the default arguments
[ "$Default_Args" ] && parse_args $Default_Args
## Read the command line arguments
[ "$*" ] && parse_args "$@"

## Sane usage of command line options
if [ "$option_memory" = y -o "$option_kernel" = y ] && \
    [ "$option_limits$option_usage" = "nn" ]; then
    option_limits=y
    option_usage=y
fi
if [ "$option_limits" = y -o "$option_usage" = y ] && \
    [ "$option_memory$option_kernel" = "nn" ]; then
    option_memory=y
    option_kernel=y
fi


## Read the UBC data:
if [ -O /proc/user_beancounters ] ; then
    while read LINE; do
#    echo "debug:$LINE:"
        read_params $LINE
    done < /proc/user_beancounters
else # read via stdin
	if tty -s; then 
		echo "for non-root users, /proc/user_beancounters required via stdin" >&2
		exit 1;
	fi
	while read LINE; do
	read_params $LINE
	done
fi



#printf "\r"

## Output whatever interests you:
[ $option_demarcations = y ] && demarcate
[ $option_veid = y ] && echo "Processing UBC version $UBC_version for VEID: $UBC_veid"
[ $option_datehost = y ] && echo "$(date)       $(hostname)"
[ $option_uptime = y ] && echo "$(uptime)"

if [ $option_memory = y ] ; then
    [ $option_demarcations = y ] && demarcate
    if [ $option_limits = y ] ; then
        [ $option_info = y ] && \
            echo "$exp0 vmguarpages and oomguarpages limits are unspecified"
        [ $option_info = y ] && \
            echo "$exp0 each VE privvmpages limit should be <= 0.6 * RAM (=1228 MB), probably [much] lower."
        printf "%4d MB Allocation Limit [privvmpages limit]\n" \
            $((${UBC_privvmpages[limit]} / 256))
        [ $option_info = y ] && \
            echo "$exp0 only high value processes have a chance in this range"
        [ $option_info = y ] && \
            echo "$exp0 having this safety range is important to permit critical processes"
        printf "%4d MB Allocation Barrier [privvmpages barrier]\n" \
            $((${UBC_privvmpages[barrier]} / 256))
        [ $option_info = y ] && \
            echo "$exp0 allocation requests in this range have a chance"
        printf "%4d MB Allocation Guarantee [vmguarpages barrier]\n" \
            $((${UBC_vmguarpages[barrier]} / 256))
        [ $option_info = y ] && \
            echo "$exp0 allocation will succeed in this range"
        printf "%4d MB Memory Guarantee [oomguarpages barrier]\n" \
            $((${UBC_oomguarpages[barrier]} / 256))
    fi # limits

    if [ $option_usage = y ] ; then
        printf "%4d MB" $((${UBC_privvmpages[held]} / 256))
        printf " (%4d MB Max) page memory allocated [privvmpages held]\n" \
            $((${UBC_privvmpages[$maxheld]} / 256))
        printf "%4d MB" $((${UBC_oomguarpages[held]} / 256))
        printf " (%4d MB Max) memory + swap used [oomguarpages held]\n" \
            $((${UBC_oomguarpages[$maxheld]} / 256))
        printf "%4d MB" $((${UBC_physpages[held]} / 256))
        printf " (%4d MB Max) page memory used [physpages held]\n" \
            $((${UBC_physpages[$maxheld]} / 256))
    fi # usage
fi # memory

#[ $option_info = y ] && \
#echo "$exp0 host system swap size should be double the physical RAM size"

if [ $option_kernel = y ] ; then

    if [ $option_limits = y ] ; then

        megas "${UBC_kmemsize[limit]}"
        kilos "${UBC_kmemsize[limit]}"
        printf "%4d MB (%6d KB) kernel memory limit [kmemsize limit]\n" \
            "$Megabytes" "$Kilobytes"

        [ $option_info = y ] && \
            echo "$exp0 a safety range here, between limit and barrier, is important"

        megas "${UBC_kmemsize[barrier]}"
        kilos "${UBC_kmemsize[barrier]}"
        printf "%4d MB (%6d KB) kernel memory barrier [kmemsize barrier]\n" \
            "$Megabytes" "$Kilobytes"

    fi # limits

    if [ $option_usage = y ] ; then

#       print_bytes "%4d %s kernel memory used [kmemsize held]\n" ${UBC_kmemsize[held]}
        megas "${UBC_kmemsize[$held]}"
        kilos "${UBC_kmemsize[$held]}"
#       printf "%4d MB kernel memory used [kmemsize held] (%6d KB)\n" \
        printf "%4d MB (%6d KB) kernel memory used [kmemsize held]\n" \
            "$Megabytes" "$Kilobytes"

        BUFMEM=$(( \
            ${UBC_tcpsndbuf[held]} + ${UBC_tcprcvbuf[held]} + \
            ${UBC_othersockbuf[held]} + ${UBC_dgramrcvbuf[held]}))

#       print_bytes "%4d %s buffer memory used [*buf held]\n" $BUFMEM
        megas "$BUFMEM"
        kilos "$BUFMEM"
#       printf "%4d MB buffer memory used [*buf held] (%6d KB)\n" \
        printf "%4d MB (%6d KB) buffer memory used [*buf held]\n" \
            "$Megabytes" "$Kilobytes"

    fi # usage

fi #kernel


if [ $option_others = y ] ; then
    [ $option_demarcations = y ] && demarcate
    echo ' Used : Max_Used : Limit    for Other Resources'
    for X in "${!UBC_num@}"; do
        eval printf '"%6d  %6d  %6d   %s\n"' \
            "\${$X[held]}" "\${$X[maxheld]}" "\${$X[limit]} ${X#*_}"
    done
fi # other

if [ $option_failcnts = y ] ; then
    [ $option_demarcations = y ] && demarcate

# look at failcnts ....
# declare -p FailCounts
    echo "Fail Count conditions: ${FailCounts[0]}"
    if [ ${FailCounts[0]} -gt 0 ]; then
                for ((  i = 1 ;  i <= ${FailCounts[0]};  i++  )); do
                    echo ${FailCounts[$i]}
                done
    fi
fi # failcnts
 
exit 0
