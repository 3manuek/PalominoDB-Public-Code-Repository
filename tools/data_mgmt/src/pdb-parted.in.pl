#!/usr/bin/env perl
# Copyright (c) 2009-2010, PalominoDB, Inc.
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
#   * Redistributions of source code must retain the above copyright notice,
#     this list of conditions and the following disclaimer.
# 
#   * Redistributions in binary form must reproduce the above copyright notice,
#     this list of conditions and the following disclaimer in the documentation
#     and/or other materials provided with the distribution.
# 
#   * Neither the name of PalominoDB, Inc. nor the names of its contributors
#     may be used to endorse or promote products derived from this software
#     without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
use strict;
use warnings FATAL => 'all';

# ###########################################################################
# ProcessLog package FSL_VERSION
# ###########################################################################
# ###########################################################################
# End ProcessLog package
# ###########################################################################

# ###########################################################################
# DSN package FSL_VERSION
# ###########################################################################
# ###########################################################################
# End DSN package
# ###########################################################################

# ###########################################################################
# TablePartitions package FSL_VERSION
# ###########################################################################
# ###########################################################################
# End TablePartitions package
# ###########################################################################

# ###########################################################################
# Timespec package FSL_VERSION
# ###########################################################################
# ###########################################################################
# End Timespec package
# ###########################################################################

# ###########################################################################
# IniFile package FSL_VERSION
# ###########################################################################
# ###########################################################################
# End IniFile package
# ###########################################################################

package pdb_parted;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use ProcessLog;
use IniFile;
use TablePartitions;
use DSN;
use Timespec;

use DBI;
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use DateTime;
use DateTime::Duration;
use DateTime::Format::Strptime;

use Data::Dumper;
$Data::Dumper::Indent = 0;
$Data::Dumper::Sortkeys = 1;

my $pretend = 0;
my $uneven = 0;

my $pl = 0;

sub main {
  my @ARGV = @_;
  my (
    $dsn,
    $dbh,
    $parts,
    # options
    $logfile,
    $email_to,
    $db_host,
    $db_schema,
    $db_table,
    $db_user,
    $db_pass,
    $db_file,
    $prefix,
    $range,
    $add,
    $drop,
    $i_am_sure,
    $do_archive,
    $older_than,
    $email_activity,
  );

  GetOptions(
    "help" => sub { pod2usage(); },
    "pretend" => \$pretend,
    "logfile|L=s" => \$logfile,
    "email-to|E=s" => \$email_to,
    "email-activity" => \$email_activity,
    "host|h=s" => \$db_host,
    "database|d=s" => \$db_schema,
    "table|t=s" => \$db_table,
    "user|u=s" => \$db_user,
    "password|p=s" => \$db_pass,
    "defaults-file|F=s" => \$db_file,
    "prefix|P=s" => \$prefix,
    "range|r=s" => \$range,
    "older-than=s" => \$older_than,
    "add=i" => \$add,
    "drop=i" => \$drop,
    "archive" => \$do_archive,
    "i-am-sure" => \$i_am_sure,
    "uneven" => \$uneven
  );

  unless($db_schema and $db_table and $prefix and $range) {
    pod2usage(-message => "--table, --database, --prefix and --range are mandatory.");
  }

  unless($range eq 'months' or $range eq 'days' or $range eq 'weeks') {
    pod2usage(-message => "--range must be one of: months, days, or weeks.");
  }

  $range=lc($range);

  unless($prefix =~ /^[A-Za-z][A-Za-z0-9_-]*$/) {
    pod2usage(-message => "--prefix ($prefix) must not include non alpha-numeric characters.");
  }

  unless($add or $drop) {
    pod2usage(-message => "--add or --drop required.");
  }

  if($db_file and ! -f $db_file) {
    pod2usage(-message => "--defaults-file $db_file doesn't exist, or is a directory.");
  }

  if(!$db_user and $db_file) {
    my $inf = IniFile->read_config($db_file);
    $db_host ||= $inf->{client}->{host};
    $db_user ||= $inf->{client}->{user};
    $db_pass ||= $inf->{client}->{password};
  }

  # Pretty safe to assume localhost if not set.
  # Most MySQL tools do.
  $db_host ||= 'localhost';

  if($add and $drop) {
    pod2usage(-message => "only one of --add or --drop may be specified");
  }
  if($range and $older_than) {
    pod2usage(-message => "only one of --range or --older-than may be specified.");
  }

  if($older_than) {
    unless(($older_than = to_date($older_than))) {
      pod2usage(-message => "--older-than must be in the form YYYY-MM-DD.");
    }
  }

  if($email_activity and !$email_to) {
    pod2usage(-message => "--email-activity can only be used with --email-to.");
  }

  $dsn = "DBI:mysql:$db_schema";
  if($db_host) {
    $dsn .= ";host=$db_host";
  }
  if($db_file) {
    $dsn .= ";mysql_read_default_file=$db_file;mysql_read_default_group=client";
  }

  $dbh = DBI->connect($dsn, $db_user, $db_pass,
    { RaiseError => 1, PrintError => 0, AutoCommit => 0, ShowErrorStatement => 1 });

  $pl = ProcessLog->new($0, $logfile, $email_to);

  $pl->start;

  $parts = TablePartitions->new($pl,$dbh, $db_schema, $db_table);

  my $r = 0;
  if($add) {
    $r = add_partitions($add, $dbh, $parts, $prefix, $range, $db_host,
                        $db_schema, $db_table, $i_am_sure, $email_activity);
  }
  elsif($drop) {
    $r = drop_partitions($drop, $dbh, $parts, $range, $older_than,
    $db_host, $db_schema, $db_table, $db_user, $db_pass,
    $db_file, $i_am_sure, $do_archive, $email_activity);
  }

  $dbh->disconnect;
  $pl->failure_email() unless($r);
  $pl->end;
  return 0;
}

sub add_partitions {
  my ($add, $dbh, $parts, $prefix, $range, $db_host,
      $db_schema, $db_table, $i_am_sure, $email_activity) = @_;

  my $email_log = "Adding partitions to $db_host.$db_schema.$db_table:\n";
  my $ret = 1;
  my $last_p = $parts->last_partition;
  my $next_pN = undef;
  my ($dur, $reqdur) = (undef, undef);
  my $today = DateTime->today(time_zone => 'local');
  my $reorganize = uc($last_p->{description}) eq 'MAXVALUE';
  if($reorganize) {
    $last_p = $parts->partitions()->[-2];
    if($parts->has_maxvalue_data and !$i_am_sure) {
      $pl->e("Refusing to modify partitioning when data in a MAXVALUE partition exists.\n", "Re-run this tool with --i-am-sure if you are sure you want to do this.");
      return undef;
    }
  }

  $last_p->{name} =~ /^$prefix(\d+)$/;
  $next_pN = $1;
  $pl->e("Aborting --add since most recent partition didn't match /^$prefix(\\d+)\$/.")
    and return undef
    if(not defined($next_pN));
  $next_pN++;

  $last_p->{date} = to_date($parts->desc_from_datelike($last_p->{name}));
  $reqdur = DateTime::Duration->new( $range => $add );

  $pl->d('Today:', $today->ymd, 'Last:', $last_p->{date}->ymd);
  $dur = $today->delta_days($last_p->{date});
  $dur = $dur->inverse if($today > $last_p->{date});
  $pl->d("Today - Last:", $dur->in_units('days'), 'days');

  my $r = DateTime::Duration->compare($dur, $reqdur, $today);
  if($r >= 0) {
    $pl->m("At least the requested partitions exist already.\n",
      'Requested out to:', ($today + $reqdur)->ymd(), "\n",
      'Partitions out to:', $last_p->{date}->ymd(), 'exist.');
    $ret = 1;
  }
  else {
    my @part_dates = ();
    my $end_date = $today + $reqdur;
    my $curs_date = $last_p->{date};

    $pl->d('End date:', $end_date->ymd);

    ###########################################################################
    # Handle the case where we aren't run on the same day of the week or month.
    # This is/was part of the requirements for the pdb-parted tool.
    # It used to be that this code would try to add an extra partition in to 
    # compenstate for the offset. The new code just fiddles with the start date
    # to get it to land on a multiple of $today*$range.
    ###########################################################################
    $pl->d('Checking for uneven partitioning.');
    if($range eq 'months') {
      my $uneven_dur = $today->delta_md($last_p->{date});
      $pl->d(Dumper($uneven_dur));
      if($uneven_dur->delta_days) {
        $pl->i('Found uneven partitioning.', $uneven_dur->delta_days, 'days. Are you running on the same day of the month?');
        unless($uneven) {
          $curs_date->add('days' => $uneven_dur->delta_days) unless($uneven);
        }
      }
    }
    elsif($range eq 'weeks') {
      my $uneven_dur = $today->delta_days($last_p->{date});
      $pl->d(Dumper($uneven_dur));
      if($uneven_dur->delta_days % 7) {
        $pl->i('Found uneven partitioning.', 7 - $uneven_dur->delta_days % 7, 'days. Are you running on the same day of the week?');
        unless($uneven) {
          $curs_date->subtract('days' => 7 -  $uneven_dur->delta_days % 7);
        }
      }
    }

    $pl->d('cur date:', $curs_date->ymd);

    ###########################################################################
    # Just loop until $curs_date (date cursor) is greater than
    # where we want to be. We advance the cursor by $range increments.
    ###########################################################################
    while($curs_date < $end_date) {
      push @part_dates, $curs_date->add($range => 1)->clone();
    }

    $pl->d(Dumper([ map { $_->ymd } @part_dates]));

    if($reorganize) {
      $parts->start_reorganization($parts->last_partition()->{name});
      push @part_dates, 'MAXVALUE';
    }

    $pl->i("Will add", scalar @part_dates, "partitions to satisfy", $add, $range, 'requirement.');

    my $i=0;
    ###########################################################################
    # Loop over the calculated dates and add partitions for each one
    ###########################################################################
    foreach my $date (@part_dates) {
      $email_log .= "- $prefix". ($next_pN+$i) . " [older than: $date]\n";
      if($reorganize) {
        if($date eq 'MAXVALUE') {
          $parts->add_reorganized_part($prefix . ($next_pN+$i), $date);
        }
        else {
          $parts->add_reorganized_part($prefix . ($next_pN+$i), $date->ymd);
        }
      }
      else {
        $ret = $parts->add_range_partition($prefix . ($next_pN+$i), $date->ymd, $pretend);
      }
      $i++;
    }

    if($reorganize) {
      $ret = $parts->end_reorganization($pretend);
    }
    if(@part_dates) {
      $pl->send_email("Partitions added on $db_host.$db_schema.$db_table", $email_log);
    }
  }
  return $ret;
}

sub drop_partitions {
  my ($drop, $dbh, $parts, $range, $older_than, $host, $schema,
     $table, $user, $pw, $dfile, $i_am_sure, $do_archive, $email_activity) = @_;

  my $email_log = "Dropped partitions from $host.$schema.$table:\n";
  my $today = DateTime->today(time_zone => 'local');
  $pl->e("Refusing to drop more than 1 partition unless --i-am-sure is passed.")
    and return undef
    if($drop > 1 and !$i_am_sure);

  # Return value of this subroutine.
  my $r = 1;
  my $j = 0; # counts the number of dropped partitions
  $pl->m("Dropping $drop partitions.");
  for(my $i=0; $i < $drop ; $i++) {
    my $p = $parts->first_partition;
    my $p_date = to_date($parts->desc_from_datelike($p->{name}));
    ## Determine if the partition is within $range or $older_than
    if($range) {
      if($p_date > $today->clone()->subtract($range => $drop)) {
        $pl->d("Skipping $p->{name} @ $p_date");
        next;
      }
    }
    elsif($older_than) {
      if($p_date > $older_than) {
        $pl->d("Skipping $p->{name} @ $p_date");
        next;
      }
    }
    $email_log .= "- $p->{name} [older than: $p_date]";
    if($do_archive) {
      archive_partition($parts, $p, $host, $schema, $table, $user, $pw, $dfile);
      $email_log .= " (archived)";
    }
    $pl->i("Dropping data older than:", $p_date);
    $r = $parts->drop_partition($p->{name}, $pretend);
    $email_log .= "\n";
    last unless($r);
    $j++;
  }
  if($j > 0) {
    $pl->send_email("Partitions dropped on $host.$schema.$table", $email_log);
  }
  return $r;
}

sub archive_partition {
  my ($parts, $part, $host, $schema, $table, $user, $pw, $dfile) = @_;
  my ($desc, $fn, $cfn) = $parts->expr_datelike();
  if($cfn) {
    $desc = "$cfn(". $part->{description} . ")";
  }
  else {
    $desc = $part->{description};
  }
  my @dump_EXEC = ("mysqldump",
      ( $dfile ? ("--defaults-file=$dfile") : () ),
      "--no-create-info",
      "--result-file=". "$host.$schema.$table.". $part->{name} . ".sql",
      ($host ? ("-h$host") : () ),
      ($user ? ("-u$user") : () ),
      ($pw ? ("-p$pw") : () ),
      "-w ". $parts->expression_column() . "<$desc",
      $schema,
      $table);
  $pl->i("Archiving:", $part->{name}, "to", "$host.$schema.$table". $part->{name} . ".sql");
  $pl->d("Executing:", @dump_EXEC);
  unless($pretend) {
    system(@dump_EXEC);
  }
  else {
    $? = 0;
  }
  if(($? << 8) != 0) {
    $pl->e("Failed to archive $schema.$table.". $part->{name}, "got:", ($? << 8), "from mysqldump");
    die("Failed to archive $schema.$table.". $part->{name})
  }
}

sub to_date {
  my ($dstr) = @_;
  #############################################################################
  # MySQL can return two different kinds of dates to us.
  # For DATE columns we just get the date. Obviously.
  # For virtually all other time related columns, we also get a time.
  # This method first tries parsing with just dates and then tries with time.
  #############################################################################
  my $fmt1 = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d', time_zone => 'local');
  my $fmt2 = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d %T', time_zone => 'local');
  return ($fmt1->parse_datetime($dstr) || $fmt2->parse_datetime($dstr))->truncate( to => 'day' );
}

exit main(@ARGV);

=pod

=head1 NAME

pdb-parted - MySQL partition management script

=head1 SYNOPSIS

pdb-parted [options] ACTION TIMESPEC DSN

options:

  --help,          -h   This help. See C<perldoc pdb-parted> for full docs.
  --dryrun,        -n   Report on actions without taking them.
  --logfile,       -L   Direct output to given logfile. Default: none.
  --email-activity      Send a brief email report of actions taken.
                        The email is sent to --email-to.
  --email-to       -E   Where to send activity and failure emails.
                        Default: none.

  --prefix         -P   Partition prefix. Defaults to 'p'.
  
  --archive             Archive partitions before dropping them.

ACTION:

  --add   Add N partitions.
  --drop  Remove N partitions.

TIMESPEC:

A timespec is a "natural" string to specify how far in advance to create
partitions. A sampling of possible timespecs:

  1w (create partitions one week in advance)
  1m (one month)
  2q (two quarters)
  5h (five hours)

See the full documentation for a complete description of timespecs.

=head1 TIMESPEC

A timespec is one of:

  A modifier to current local time
  or, an absolute time in 'YYYY-MM-DD HH:MM:SS' format.

Since the latter isn't very complicated, this section describes
what the modifiers are.

A modifer is, an optional plus or minus sign followed by a number,
and then one of:

  y = year, q = quarter , m = month, w = week, d = day, h = hour

Followed optionally by a space or a period and 'startof'.
Which is described in the next section.

Some examples (the time is assumed to be 00:00:00):

  -1y         (2010-11-01 -> 2009-11-01)
   5d         (2010-12-10 -> 2010-12-15)
  -1w         (2010-12-13 -> 2010-12-07)
  -1q startof (2010-05-01 -> 2010-01-01)
   1q.startof (2010-05-01 -> 2010-07-01)

=head2 startof

The 'startof' modifier for timespecs is a little confusing,
but, is the only sane way to achieve latching like behavior.
It adjusts the reference time so that it starts at the beginning
of the requested type of interval. So, if you specify C<-1h startof>,
and the current time is: C<2010-12-03 04:33:56>, first the calculation
throws away C<33:56> to get: C<2010-12-03 04:00:00>, and then subtracts
one hour to yield: C<2010-12-03 03:00:00>.

Diagram of the 'startof' operator for timespec C<-1q startof>,
given the date C<2010-05-01 00:00>.

          R P   C
          v v   v
   ---.---.---.---.---.--- Dec 2010
   ^   ^   ^   ^   ^   ^
   Jul Oct Jan Apr Jul Oct
  2009    2010

  . = quarter separator 
  C = current quarter
  P = previous quarter
  R = Resultant time (2010-01-01 00:00:00)

=head1 OPTIONS

=over 8

=item --help

This help.

=item --pretend

type: boolean

Report on actions that would be taken. Works best with the C<Pdb_DEBUG> environment variable set to true.

See also: L<ENVIRONMENT>

=item --logfile, -L

type: string

Path to a file for logging, or, C<< syslog:<facility> >>
Where C<< <facility> >> is a pre-defined logging facility for this machine.

See also: L<syslog(3)>, L<syslogd(8)>, L<syslog.conf(5)>

=item --email-to, -E

type: email-address

Where to send emails.

This tool can send emails on failure, and whenever it adds, drops, or archive partitions.
Ordinarily, it will only send emails on failure.

=item --email-activity

If this flag is present, then this will make the tool also email
whenver it adds, drops, or archives a partition.

=item --host, -h

type: string

Database host to operate on.

=item --user, -u

type: string

User to connect as.

=item --password, -p

type: string

Password to connect with.

=item --defaults-file, -F

type: path

Path to a my.cnf style config file with user, password, and/or host information.

=item --database, -d

type: string; mandatory

Database schema (database) to operate on.

=item --table, -t

type: string; mandatory

Database table.

=item --prefix, -P

type: string, mandatory

Prefix for partition names. Partitions are always named like: <prefix>N.
Where N is a number.

=item --range, -r

type: string one of: months, weeks, days ; mandatory

This is the interval in which partitions operate. Or, the size of the buckets
that the partitions describe.

When adding paritions, it specifies what timeframe the partitions describe.

When dropping partitions, it specifies the multiplier for the N in C<--drop=N>.
So, if you have: C<--range weeks --drop 3>, you're asking to drop data older than
three weeks.

B<Note that you'll also have to pass C<--i-am-sure> in order to drop
more than one partition.>

=item --i-am-sure

type: boolean

Disables safety for L<"--drop"> and allows dropping more than one partition at a time.

=item --uneven

type: boolean

Allow the tool to possibly add non-whole weeks or months. Has no effect when adding days, as those are the smallest unit this tool supports.

=item --archive

type: boolean

mysqldump partitions to files B<in the current directory> named like <host>.<schema>.<table>.<partition_name>.sql

There is not currently a way to archive without dropping a partition.

=item --older-than

type: date

For dropping data, this is an alternate to L<--range>. It specifies
an absolute date for which partitions older than it should be dropped.
The date B<MUST> be in the format: C<YYYY-MM-DD>. 

=back

=head1 ACTIONS

=over 8

=item --add

type: integer

Adds partitions till there are at least N L<--range> sized future buckets.

The adding of partitions is not done blindly. This will only add new partitions
if there are fewer than N future partitions. For example, if N is 2 (e.g., C<--add 2> is used),
8 partitions already exist, and today falls in partition 6, then C<--add> will do nothing.

Diagram 1:

  |-----+-|
  0     6 8

Conversely, if N is 3 and the rest of the conditions are as above, then C<--add> will add 1 partition.

Diagram 2:

  |-----+--|
  0     6  9

You can think of C<--add> as specifying a required minimum safety zone.

If L<--uneven> is passed, then this tool will ignore fractional parts of weeks and months.
This can be useful to convert from one size partition to another.
Otherwise, this tool will round up to the largest whole week or month. This means, that if you
are adding monthly partitions, it makes sense to run the tool on the same day of the month.
And, if you are adding weekly partitions, it would behoove you to run this on the same day of the week each time.

=item --drop

type: integer

Drops the N oldest partitions.

B<NOTE:> Unless L<"--i-am-sure"> is passed,
this tool refuses to drop more than 1 at a time.

You'll note from the below diagram that this tool does NOT renumber partitions to start at 0.

Diagram 3:

  Before: |-----+--|
          0     6  9
  After : x-----+--|
           1    6  9

=back

=head1 ENVIRONMENT

Almost all of the PDB (PalominoDB) tools created respond to the environment variable C<Pdb_DEBUG>.
This variable, when set to true, enables additional (very verbose) output from the tools.

=cut

1;
