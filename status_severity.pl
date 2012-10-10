#!/usr/bin/perl

use Modern::Perl;
use WWW::Mechanize;
use Text::CSV_XS;
use Data::Dumper;
use File::Slurp;
use YAML qw( DumpFile LoadFile );
use Template;

my $url = 'http://bugs.koha-community.org/bugzilla3/report.cgi?bug_status=UNCONFIRMED&bug_status=NEW&bug_status=REOPENED&bug_status=ASSIGNED&bug_status=In%20Discussion&bug_status=Needs%20Signoff&bug_status=Signed%20Off&bug_status=Passed%20QA&bug_status=Pushed%20for%20QA&bug_status=Failed%20QA&bug_status=Patch%20doesn%27t%20apply&bug_status=Pushed%20to%20Master&bug_status=Pushed%20to%20Stable&bug_status=RESOLVED&bug_status=VERIFIED&bug_status=CLOSED&x_axis_field=bug_status&y_axis_field=bug_severity&width=600&height=350&action=wrap&ctype=csv&format=table';
my $tempfile  = 'rawdata.csv';
my $savedfile = 'saved.yaml';
my %newdata;
my %olddata = LoadFile( $savedfile );
my %outdata;

my $mech = WWW::Mechanize->new();
$mech->get( $url );
my $table = $mech->content();
$table =~ s|"Severity" / "Status"|"Severity"|;
write_file( $tempfile, $table );

my $csv = Text::CSV_XS->new ();
open my $io, "<:encoding(utf8)", $tempfile or die "$tempfile: $!";
$csv->column_names( $csv->getline( $io ) );

while ( my $row = $csv->getline_hr ( $io ) ) {
  my $severity = $row->{'Severity'};
  delete $row->{'Severity'};
  foreach my $key ( keys $row ){
    my $slug = lc("$severity $key");
    $slug =~ s/'//g;
    $slug =~ s/ /_/g;
    my $new  = $row->{$key};
    my $old  = $olddata{$slug};
    my $diff = $new - $old;
    #say "$slug $old -> $new \t\t$diff";
    $outdata{$slug} = { 'new' => $new, 'old' => $old, 'diff' => $diff };
    $newdata{$slug} = $new;
  }
}

DumpFile( $savedfile, %newdata );

my $tt = Template->new({
    INCLUDE_PATH => '.',
}) || die $Template::ERROR, "\n";

$tt->process( 'table.tt', \%outdata ) || die $tt->error(), "\n";
