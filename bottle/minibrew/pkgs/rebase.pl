#!/usr/bin/perl -w
use strict;

my $mach_o_magic = "\xCF\xFA\xED\xFE";
my %skip = (
  ChangeLog => 1,
  Makefile => 1,
  PkgInfo => 1,
  );
my %skipExt = (
  so => 1,
  pc => 1,
  md => 1,
  rb => 1,
  h => 1,
  nib => 1,
  a => 1,
  py => 1,
  png => 1,
  txt => 1,
  o => 1,
  cmake => 1,
  pl => 1,
  gif => 1,
  c => 1,
  plist => 1,
  icns => 1,
  dist => 1,
  cnf => 1,
  def => 1,
  local => 1,
  ico => 1,
  html => 1,
  css => 1,
  rtf => 1,
  );
#my $dylib_magic = "\xCF\xFA\xED\xFE";

opendir( my $dh, "." );
my @files = readdir( $dh );
closedir( $dh );

for my $file ( @files ) {
    next if( $file =~ m/^\.+$/ );
    next if( $file =~ m/~$/ );
    next if( $file eq 'lib' );
    next if( ! -d $file );
    handle_dir( $file );
}

sub handle_dir {
    my $dir = shift;
    #return if( $dir !~ m/python/ );
    print "$dir\n";
    my @files;
    getbins( $dir, \@files );
    for my $filei ( @files ) {
        my ( $full, $file ) = @$filei;
        #print "$full - $file\n";
        next if( $file =~ m/^[A-Z]+$/ );
        next if( $skip{ $file } );
        #next if( -l $full );
        
        my $yn = "N";
        my $hex = "";
        my $magic = "";
        
        if( $file =~ m/\.dylib$/ ) {
            $yn = "Y";
        }
        else {
            open(my $fh, '<:raw', $full);
            read($fh, $magic, 4);
            close($fh);
            if( $magic eq $mach_o_magic ) {
                $yn = "Y";
            } else {
                $hex = unpack('H*', $magic);
            }
        }
        
        if( $hex && $magic =~ m/^#!/ ) {
            $hex = "#!";
        }
        
        #print "  $yn $hex $full\n";
        if( $yn eq 'Y' ) {
            
            #my @lines = `otool -L \"$full\"`;
            my @lines = `otool -l \"$full\"`;
            #for my $line ( @lines ) {
            
            my $out = "";
            for( my $i=0; $i< $#lines; $i++ ) {
                my $line = $lines[$i];
                if( $line =~ m/LC_LOAD_DYLIB/ ) {
                    my $line2 = $lines[$i+2];
                    
                    my $line3 = $line2;
                    $line3 =~ s/\n//;
                    #print "  $line3\n";
                    
                    if( $line2 =~ m/(\@\@[A-Z_]+\@\@.+) *\(/ ) {
                        my $dest = $1;
                        $dest =~ s/ $//;
                        print "  $dest\n";
                        #$line2 =~ s/^ +//g;
                        #$line2 =~ s/\n//;
                        
                        my $rep = $dest;
                        #$rep =~ s|\@\@HOMEBREW_CELLAR\@\@/|./pkgs/|;
                        #if( $rep =~ m|\@\@HOMEBREW_PREFIX\@\@/opt/([^/]+)/| ) {
                        #    my $pkg = $1;
                        #    $rep =~ s|\@\@HOMEBREW_PREFIX\@\@/opt/$pkg/|./pkgs/opt/$pkg/|;
                        #}
                        my $pkgsdir = "/Users/user/git2/minibrew/bottle/minibrew/pkgs";
                        $rep =~ s|\@\@HOMEBREW_[A-Z]+\@\@.+/([^/]+\.dylib)|$pkgsdir/lib/$1|;
                        $rep =~ s|\@\@HOMEBREW_CELLAR\@\@/|$pkgsdir/|;
                        $out .= "    $dest -> $rep\n";
                        
                        #my $cmd = qq|install_name_tool -change \"$dest\" \"$rep\" \"$full\"|;
                        #print "  $cmd\n";
                        `install_name_tool -change \"$dest\" \"$rep\" \"$full\"`;
                    } elsif( $line2 =~ m/HOMEBREW/ ) {
                        print "  ??? $line2\n";
                    }
                }
            }
            if( $out ) {
                print "  $yn $hex $full\n";
                print $out;
            }
        }
    }
}

sub getbins {
    my ( $abs, $res ) = @_;
    opendir( my $dh, $abs );
    my @files = readdir( $dh );
    closedir( $dh );
    
    for my $file ( @files ) {
        next if( $file =~ m/^\.+$/ );
        my $full = "$abs/$file";
        if( $file =~ m/\.([^\.]+)$/ ) {
            my $ext = $1;
            next if( $skipExt{ $ext } );
        }
        
        #my $full = "$abs/$file";
        if( -d $full ) {
            next if( $file =~ m/^(share|test|venv)$/ );
            next if( $file =~ m/^config/ );
            getbins( $full, $res );
            next;
        }
        next if( -l $full );
        #elsif( $file =~ m/\.dylib$/  ) {
            push( @$res, [ $full, $file ] );
        #}
    }
}