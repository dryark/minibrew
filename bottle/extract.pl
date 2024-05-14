#!/usr/bin/perl -w
use strict;
use Cwd qw/getcwd/;

opendir( my $dh, "." );
my @files = readdir( $dh );
closedir( $dh );

my $totSize = 0;
my $totXSize = 0;
for my $file ( @files ) {
    next if( $file =~ m/^\.+$/ );
    next if( $file !~ m/\.tar\.gz$/ );
    $totSize += -s $file;
    my @lines = `gzip -l $file`;
    my $line = $lines[1];
    $line =~ s/^ +//;
    my @parts = split(/ +/,$line);
    $totXSize += $parts[1];
}

my $hrSize = bytesToHR( $totXSize );

print "Total extracted size: $hrSize\n";
#exit(0);

print "Extracting packages...\n";
my $doneSize = 0;
print_progress( 0 );
my $cwd = getcwd();
for my $file ( @files ) {
    next if( $file =~ m/^\.+$/ );
    next if( $file !~ m/\.tar\.gz$/ );
    my $folder = $file;
    $folder =~ s/\.tar\.gz$//;
    if( $folder =~ m/^(.+)\-([0-9\.]+)$/ ) {
        $folder = "$1\@$2";
    }
    
    #print "../tarball_incremental \"$file\" \"$cwd/minibrew/pkgs\"\n";
    #exit(0);
    open( my $pipe, "../tarball_incremental \"$file\" \"$cwd/minibrew/pkgs\" |" );
    my $prev = '';
    while( my $line = <$pipe> ) {
        $doneSize += $line;
        print_progress( int( ($doneSize/$totXSize)*100 ) );
    }
    close( $pipe );
}
print_progress( 100 );
print "\n";
my $hrDone = bytesToHR( $doneSize );
print "Done extracted size: $hrDone\n";

sub bytesToHR {
    my $bytes = shift;
    if( $bytes > ( 1024 * 1024 ) ) {
        my $num = int( $bytes / ( 1024 * 1024 ) * 100 ) / 100;
        return "${num} mb";
    }
    if( $bytes > 1024 ) {
        my $num = int( $bytes / ( 1024 ) * 100 ) / 100;
        return "${num} kb";
    }
    return "${bytes} b";
}

sub print_progress {
    my ($percent) = @_;
    $percent *= 1.08;
    $percent = 100 if( $percent > 100 );
    my $num_blocks = int($percent / 2);
    my $bar = '[' . '=' x $num_blocks . ' ' x (50 - $num_blocks) . ']';
    printf("\r%s %3d%%", $bar, $percent);
    STDOUT->flush(); # Flush the output buffer to update the display immediately
}