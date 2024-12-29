#!/usr/bin/perl -w
use strict;
use File::Slurp qw/read_file/;
#use lib 'mod';
#use Ujsonin;
use JSON::XS qw/decode_json/;

# Manifests can be fetched from ghcr also, but it requires some stupid authentication
my $gitFormulaBase = "https://raw.githubusercontent.com/Homebrew/homebrew-core/master/Formula";

# use `brew info [pkg]` to determine the formula location
# use `brew fetch --force-bottle --verbose [pkg]` to determine ghcr paths
my $packages = [
#  {
#    name => "python-3.12",
#    formula => "p/python\@3.12.rb",
#    file => "python-3.12.rb",
#    ghcr => "python/3.12",
#  },
];

my $curlInfo = `curl --version`;
my @curlLines = split("\n",$curlInfo);
my $curlVersion = "8.4.0";
if( $curlLines[0] =~ m/curl ([0-9\.]+)/ ) {
  $curlVersion = $1;
}

my @basic = qw/
  xz
  libimobiledevice-glue
  libplist
  libusbmuxd
  libtasn1
  libtatsu
  sqlite
  openssl@3
  ideviceinstaller
  libimobiledevice
  readline
  ca-certificates
  zstd
  lz4
  libzip
/;
# berkeley-db@5


for my $item ( @basic ) {
  my $let = "";
  if( $item =~ m/^lib/ ) {
    $let = "lib";
  } else {
    $let = substr( $item, 0, 1 );
  }
  if( $item =~ m/(.+)\@([0-9\.]+)$/ ) {
    my $base = $1;
    my $version = $2;
    push( @$packages, {
      name => "$base-$version",
      formula => "$let/$item.rb",
      file => "$base-$version.rb",
      ghcr => "$base/$version",
      depname => $item,
    } );
  }
  else {
    push( @$packages, {
      name => $item,
      formula => "$let/$item.rb",
      file => "$item.rb",
    } );
  }
}

my %deps;
for my $pkg ( @$packages ) {
  my $name = $pkg->{name};
  my $depname = $pkg->{depname} || $name;
  $deps{ $depname } = 1;
}

open( my $fh, ">dlinfo.json" );
print $fh "{\n  pkgs:[\n";

my $missing = "";
for my $pkg ( @$packages ) {
  my $name = $pkg->{name};
  print "$name\n";
  my $formula = $pkg->{formula};
  $formula =~ s/\@/\%40/g;
  my $metaFile = $pkg->{file};
  my $metaUrl = "$gitFormulaBase/$formula";
  my $ghcr = $pkg->{ghcr} || $name;
  my $dlBase = "https://ghcr.io/v2/homebrew/core/$ghcr/blobs/sha256:";
  
  print "  url: $dlBase\n";
  print $fh "  {\n    name:\"$name\"\n    url:\"$dlBase\"\n";
  if( ! -e "rb/$metaFile" ) {
    `curl "$metaUrl" -o "rb/$metaFile"`;
  }
  
  my $depName = $pkg->{depname} || $name;
  my $jsonFile = "$depName.json";
  if( ! -e "json/$jsonFile" ) {
    `curl "https://formulae.brew.sh/api/formula/$jsonFile" -o "json/$jsonFile"`;
  }
  
  #my $root = Ujsonin::parse_file( "json/$jsonFile" );
  my $jsonText = read_file( "json/$jsonFile" );
  my $root = decode_json( $jsonText );
  my $v = $root->{versions}{stable};
  print $fh "    v:\"$v\"\n";
  
  print $fh "    platforms:{\n";
  
  my $meta = read_file( "rb/$metaFile" );
  my @lines = split("\n",$meta);
  my $inBottle = 0;
  my $inLinux = 0;
  for my $line ( @lines ) {
    if( $inLinux ) {
      if( $line =~ m/^\s*end$/ ) {
        $inLinux = 0;
        next;
      }
    }
    elsif( $inBottle ) {
      if( $line =~ m/^\s*end$/ ) {
        $inBottle = 0;
        next;
      }
      #print "  $line\n";
      if( $line =~ m/^\s*sha256.+?([a-z0-9_]+):\s*"([a-z0-9]+)"\s*$/ && $line !~ m/linux/ && $line !~ m/big_sur/ ) {
        my $platform = $1;
        my $hash = $2;
        print "  $platform: $hash\n";
        print $fh "      $platform: \"$hash\"\n";
        if( $platform eq 'ventura' || $platform eq 'all' ) {
          my $full = "$dlBase$hash";
          my $save = "bottle/$name.tar.gz";
          if( ! -e $save ) {
            ghcr_dl( $full, $save );
          }
        }
      }
    } else {
      if( $line =~ m/^\s*on_linux do$/ ) {
        $inLinux = 1;
      }
      if( $line =~ m/^\s*bottle do$/ ) {
        $inBottle = 1;
      }
      if( $line =~ m/^\s*depends_on "([^"]+)"/ && $line !~ m/build/ ) {
        my $dep = $1;
        print "  dep: $dep\n";
        $missing .= "missing dep: $dep\n" if( !$deps{ $dep } );
      }
    }
    
  }
  print $fh "    }\n  }\n";
}
print $fh "  ]\n}\n";
close( $fh );

sub ghcr_dl {
  my ( $url, $out ) = @_;
  my $ua = '--user-agent "Homebrew/4.2.20 (Macintosh; Intel Mac OS X 13.6.4) curl/'.$curlVersion.'"';
  my $lang = '--header Accept-Language:\\ en';
  my $auth = '--header "Authorization: Bearer QQ=="';
  my $fixed = "--disable --cookie /dev/null --globoff --show-error $ua $lang --fail --retry 3 $auth --remote-time";
  
  #`curl $fixed --location $url -o $out`;
  print "curl $fixed --location $url -o $out\n";
}

print $missing;