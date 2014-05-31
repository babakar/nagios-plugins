#!/usr/bin/perl -T
# nagios: -epn
#
#  Author: Hari Sekhon
#  Date: 2014-04-22 21:40:03 +0100 (Tue, 22 Apr 2014)
#
#  http://github.com/harisekhon
#
#  License: see accompanying LICENSE file
#

$DESCRIPTION = "Nagios Plugin to check IBM BigInsights HDFS Space Used % via BigInsights Console REST API

Raises critical on any blocks with Corrupt replicas or Missing replicas.

Warning/Critical thresholds are applied to Under-replicated blocks.

Tested on IBM BigInsights Console 2.1.2.0";

$VERSION = "0.1";

use strict;
use warnings;
BEGIN {
    use File::Basename;
    use lib dirname(__FILE__) . "/lib";
}
use HariSekhonUtils;
use HariSekhon::IBM::BigInsights;

$ua->agent("Hari Sekhon $progname version $main::VERSION");

set_threshold_defaults(10000, 100000);

%options = (
    %hostoptions,
    %useroptions,
    %tlsoptions,
    %thresholdoptions,
);
@usage_order = qw/host port user password tls ssl-CA-path tls-noverify warning critical/;

get_options();

$host       = validate_host($host);
$port       = validate_port($port);
$user       = validate_user($user);
$password   = validate_password($password);
validate_thresholds(1, 1, { "simple" => "upper", "positive" => 1, "integer"  => 1 });

tls_options();

vlog2;
set_timeout();

$status = "OK";

curl_biginsights "/ClusterStatus/fs_summary.json", $user, $password;

my $label = get_field("label");
$label eq "HDFS" or quit "UNKNOWN", "label returned was '$label' instead of 'HDFS'";
my $repl_corrupt = get_field("blocksWithCorruptReplica");
my $repl_missing = get_field("blocksWithoutGoodReplica");
my $repl_under   = get_field("blocksUnderReplicated");
isInt($repl_corrupt) or quit "UNKNOWN", "blocksWithCorruptReplica field was a non-integer! $nagios_plugins_support_msg";
isInt($repl_missing) or quit "UNKNOWN", "blocksWithoutGoodReplica field was a non-integer! $nagios_plugins_support_msg";
isInt($repl_under)   or quit "UNKNOWN", "blocksUnderReplicated field was a non-integer! $nagios_plugins_support_msg";
critical if($repl_corrupt or $repl_missing);
$msg .= sprintf("HDFS blocks corrupt=%d missing=%d under-replicated=%d", $repl_corrupt, $repl_missing, $repl_under);
check_thresholds($repl_under);
$msg .= sprintf(" | 'corrupt blocks'=%d 'missing blocks'=%d 'under blocks'=%d", $repl_corrupt, $repl_missing, $repl_under);
msg_perf_thresholds();

quit $status, $msg;
