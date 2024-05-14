#!/usr/bin/perl -w
use strict;
use Data::Dumper;
use JSON::XS qw/decode_json/;
use File::Slurp qw/read_file write_file/;

my $curlInfo = `curl --version`;
my @curlLines = split("\n",$curlInfo);
my $curlVersion = "8.4.0";
if( $curlLines[0] =~ m/curl ([0-9\.]+)/ ) {
  $curlVersion = $1;
}

opendir( my $dh, "." );
my @files = readdir( $dh );
closedir( $dh );

for my $file ( @files ) {
    next if( $file =~ m/^\.+$/ );
    next if( $file !~ m/.+\.json$/ );
    print "$file\n";
    my $name = $file;
    $name =~ s/\.json//;
    
    my $jsonText = read_file( $file );
    my $ob = decode_json( $jsonText );
    #print Dumper( $ob->{versions} );
    #print "\n";
    my $version = $ob->{versions}{stable};
    print "  version: $version\n";
    
    my $manName = $name;
    my $path;
    if( $manName =~ m/(.+)\@(.+)$/ ) {
       $manName = $1;
       my $majorV = $2;
       $path = "$manName/$majorV";
    }
    else {
      $path = $manName;
    }
    
    my $rebuild = $ob->{bottle}{stable}{rebuild};
    my $trail = "";
    if( $rebuild > 0 ) {
      $trail = "-$rebuild";
    }
    #  https://ghcr.io/v2/homebrew/core/openssl/3/manifests/3.3.0-1  WTF
    #  https://ghcr.io/v2/homebrew/core/krb5/manifests/1.21.2
    my $manifestUrl = "$path/manifests/$version$trail";
    my $manifestFile = "../manifests/$name.manifest";
    if( ! -e $manifestFile ) {
        ghcr_dl( "https://ghcr.io/v2/homebrew/core/$manifestUrl", $manifestFile );
    }
    
    my $manJsonText = read_file( $manifestFile );
    my $manOb = decode_json( $manJsonText );
    my $mans = $manOb->{manifests};
    for my $man ( @$mans ) {
        my $anns = $man->{annotations};
        next if( !$anns );
        my $digest = $anns->{"sh.brew.bottle.digest"};
        my $size = $anns->{"sh.brew.bottle.size"} || 'unknown';
        
        if( $size eq 'unknown' ) {
            my $dl = "https://ghcr.io/v2/homebrew/core/$path/blobs/sha256:$digest";
            #my $auth = '--header "Authorization: Bearer QQ=="';
            #my $lang = '--header Accept-Language:\\ en';
            #print qq|curl -sI $lang $auth "$dl"|;
            my ( $headSize, $type ) = ghcr_dlsize( $digest, $dl );
            $size = $headSize;
            #print $info;
            #exit(0);
        }
        
        print "  dgsize: $size $digest\n";
    }
}

sub ghcr_dlsize {
  my ( $sha, $url ) = @_;
  my $ua = '--user-agent "Homebrew/4.2.20 (Macintosh; Intel Mac OS X 13.6.4) curl/'.$curlVersion.'"';
  my $lang = '--header Accept-Language:\\ en';
  my $auth = '--header "Authorization: Bearer QQ=="';
  my $fixed = "--disable --cookie /dev/null --globoff --show-error $ua $lang --fail --retry 3 $auth --remote-time";
  
  my @lines;
  if( -e "../bottlehead/$sha" ) {
    my $data = read_file( "../bottlehead/$sha" );
    @lines = split("\n", $data);
  }
  else {
    my $data = `curl $fixed -I --location $url`;
    write_file( "../bottlehead/$sha", $data );
    @lines = split("\n", $data);
  }
  my $size = 0;
  my $type = "unknown";
  for my $line ( @lines ) {
    if( $line =~ m/^content-length: ([0-9]+)/ ) {
      $size = $1;
    }
    if( $line =~ m/^content-type: (.+)$/ ) {
      $type = $1;
      if( $type =~ m|application/vnd.oci.image.layer.v1.(.+)| ) {
        $type = $1;
      }
    }
  }
  return ( $size, $type );
  #print "curl $fixed $url -o $out\n";
}

sub ghcr_dl {
  my ( $url, $out ) = @_;
  my $ua = '--user-agent "Homebrew/4.2.20 (Macintosh; Intel Mac OS X 13.6.4) curl/'.$curlVersion.'"';
  my $lang = '--header Accept-Language:\\ en';
  my $type = '--header "Accept: application/vnd.oci.image.index.v1+json"';
  my $auth = '--header "Authorization: Bearer QQ=="';
  my $fixed = "--disable --cookie /dev/null --globoff --show-error $ua $lang --fail --retry 3 $type $auth --remote-time";
  
  `curl $fixed --location $url -o $out`;
  #print "curl $fixed $url -o $out\n";
}