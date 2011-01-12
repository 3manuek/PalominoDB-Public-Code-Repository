use strict;
use warnings FATAL => 'all';
use DateTime;
use DateTime::Format::Strptime;
use Test::More tests => 10;

BEGIN {
  use_ok('Timespec');
}

# Ranges to be tested
my $jan_1st_2009 = DateTime->new(year => 2009,
                            month => 1,
                            day => 1,
                            hour => 0,
                            minute => 0,
                            second => 0,
                            time_zone => 'local'
                          );
my $oct_1st_2009 = DateTime->new(year => 2009,
                            month => 10,
                            day => 1,
                            hour => 0,
                            minute => 0,
                            second => 0,
                            time_zone => 'local'
                          );

my $jan_1st_2010 = DateTime->new(year => 2010,
                            month => 1,
                            day => 1,
                            hour => 0,
                            minute => 0,
                            second => 0,
                            time_zone => 'local'
                          );

my $mar_1st_2010 = DateTime->new(year => 2010,
                            month => 3,
                            day => 1,
                            hour => 0,
                            minute => 0,
                            second => 0,
                            time_zone => 'local'
                          );

my $may_1st_2010 = DateTime->new(year => 2010,
                            month => 5,
                            day => 1,
                            hour => 0,
                            minute => 0,
                            second => 0,
                            time_zone => 'local'
                          );

my $jun_1st_2010 = DateTime->new(year => 2010,
                            month => 6,
                            day => 1,
                            hour => 0,
                            minute => 0,
                            second => 0,
                            time_zone => 'local'
                          );

my $jul_1st_2010 = DateTime->new(year => 2010,
                            month => 7,
                            day => 1,
                            hour => 0,
                            minute => 0,
                            second => 0,
                            time_zone => 'local'
                          );

my $sep_1st_2010 = DateTime->new(year => 2010,
                            month => 9,
                            day => 1,
                            hour => 0,
                            minute => 0,
                            second => 0,
                            time_zone => 'local'
                          );

my $sep_23rd_2010 = DateTime->new(year => 2010,
                            month => 9,
                            day => 23,
                            hour => 0,
                            minute => 0,
                            second => 0,
                            time_zone => 'local'
                          );

my $oct_1st_2010 = DateTime->new(year => 2010,
                            month => 10,
                            day => 1,
                            hour => 0,
                            minute => 0,
                            second => 0,
                            time_zone => 'local'
                          );

my $oct_23rd_2010 = DateTime->new(year => 2010,
                            month => 10,
                            day => 23,
                            hour => 0,
                            minute => 0,
                            second => 0,
                            time_zone => 'local'
                          );

my $r = Timespec->parse('-1q startof', $mar_1st_2010);
is($r, $oct_1st_2009, 'march 2010 quarter');

$r = Timespec->parse('-1q startof', $may_1st_2010);
is($r, $jan_1st_2010, 'march-may 2010 quarter');

$r = Timespec->parse('-1q startof', $oct_1st_2010);
is($r, $jul_1st_2010, 'june 2010 quarter');

$r = Timespec->parse('1q startof', $may_1st_2010);
is($r, $jul_1st_2010, 'add one quarter from the middle');

$r = Timespec->parse('-1y', $oct_1st_2010);
is($r, $oct_1st_2009, 'subtract one year');

$r = Timespec->parse('-1y startof', $oct_1st_2010);
is($r, $jan_1st_2009, 'subtract one year startof');

$r = Timespec->parse('-1m startof', $oct_23rd_2010);
is($r, $sep_1st_2010, 'subtract one month startof');

$r = Timespec->parse('1m startof', $sep_23rd_2010);
is($r, $oct_1st_2010, 'subtract one month startof');

$r = Timespec->parse('1m.startof', $sep_23rd_2010);
is($r, $oct_1st_2010, 'subtract one month.startof');
